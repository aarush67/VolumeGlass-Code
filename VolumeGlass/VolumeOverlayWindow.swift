import SwiftUI
import AppKit

class VolumeOverlayWindow: NSWindow {
    private let volumeMonitor: VolumeMonitor
    @StateObject private var audioDeviceManager = AudioDeviceManager()
    private var windowOrderTimer: Timer?
    
    init(volumeMonitor: VolumeMonitor) {
        self.volumeMonitor = volumeMonitor
        
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let setupState = volumeMonitor.setupState
        let selectedPosition = setupState?.selectedPosition ?? .leftMiddleVertical
        let barSize = setupState?.barSize ?? 1.0
        
        let baseWindowFrame = selectedPosition.getScreenPosition(screenFrame: screenFrame, barSize: barSize)
        let expandedWindowFrame = NSRect(
            x: baseWindowFrame.minX - 30,
            y: baseWindowFrame.minY - 30,
            width: baseWindowFrame.width + 400,
            height: baseWindowFrame.height + 60
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
        
        // Listen for when bar shows
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(barVisibilityChanged(_:)),
            name: NSNotification.Name("VolumeBarVisibilityChanged"),
            object: nil
        )
    }
    
    private func setupWindowProperties() {
        self.isRestorable = false
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        
        // Start ignoring mouse
        self.ignoresMouseEvents = true
        
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.orderFrontRegardless()
    }
    
    private func setupContentView() {
        let hostingView = NSHostingView(
            rootView: VolumeControlView(
                volumeMonitor: volumeMonitor,
                audioDeviceManager: audioDeviceManager
            )
            .background(.clear)
            .preferredColorScheme(.dark)
        )
        
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = hostingView
    }
    
    @objc private func barVisibilityChanged(_ notification: Notification) {
        if let isVisible = notification.userInfo?["isVisible"] as? Bool {
            print("🎯 Bar visibility: \(isVisible) - Setting ignoresMouseEvents to: \(!isVisible)")
            self.ignoresMouseEvents = !isVisible
        }
    }
    
    func showVolumeIndicator() {
        self.alphaValue = 1.0
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()
        
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
        NotificationCenter.default.removeObserver(self)
    }
}

