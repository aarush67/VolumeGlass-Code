import SwiftUI
import AppKit

class VolumeOverlayWindow: NSWindow {
    private let volumeMonitor: VolumeMonitor
    @StateObject private var audioDeviceManager = AudioDeviceManager()
    private var windowOrderTimer: Timer?
    
    init(volumeMonitor: VolumeMonitor) {
        self.volumeMonitor = volumeMonitor
        
        // Get screen dimensions
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // Use preset position from setup state
        let setupState = volumeMonitor.setupState
        let selectedPosition = setupState?.selectedPosition ?? .leftMiddleVertical
        let barSize = setupState?.barSize ?? 1.0
        
        // FIXED: Much larger window to accommodate expansion + device menu
        let baseWindowFrame = selectedPosition.getScreenPosition(screenFrame: screenFrame, barSize: barSize)
        let expandedWindowFrame = NSRect(
            x: baseWindowFrame.minX - 30, // Extra space on left
            y: baseWindowFrame.minY - 30, // Extra space on bottom
            width: baseWindowFrame.width + 400, // MUCH wider for device menu
            height: baseWindowFrame.height + 60 // Extra space for vertical expansion
        )
        
        super.init(
            contentRect: expandedWindowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindowProperties()
        setupContentView()
        audioDeviceManager.loadDevices()
    }
    
    private func setupWindowProperties() {
        // CRITICAL: Completely disable state restoration
        self.isRestorable = false
        
        // Use the highest possible window level to appear above most system overlays
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        
        // CRITICAL FIX: Allow mouse events so hover works!
        self.ignoresMouseEvents = false
        
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        
        // Prevent window from being hidden when app is not active
        self.hidesOnDeactivate = false
        
        // Accept mouse moved events for hover detection
        self.acceptsMouseMovedEvents = true
        
        // Ensure window stays on top
        self.orderFrontRegardless()
    }
    
    private func setupContentView() {
        let hostingView = NSHostingView(
            rootView: VolumeControlView(
                volumeMonitor: volumeMonitor,
                audioDeviceManager: audioDeviceManager
            )
            .background(.clear)
            .preferredColorScheme(.dark) // iOS-like dark appearance
        )
        
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = hostingView
    }
    
    func showVolumeIndicator() {
        self.alphaValue = 1.0
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()
        
        // Continuously maintain window order to stay above system overlays
        windowOrderTimer?.invalidate()
        windowOrderTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, self.isVisible else {
                timer.invalidate()
                return
            }
            self.orderFrontRegardless()
        }
    }
    
    deinit {
        windowOrderTimer?.invalidate()
    }
}

