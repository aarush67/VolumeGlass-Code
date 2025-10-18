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
    }
    
    private func setupWindowProperties() {
        self.isRestorable = false
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        
        // CRITICAL FIX: Let clicks pass through by default!
        self.ignoresMouseEvents = true
        
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.acceptsMouseMovedEvents = true
        self.orderFrontRegardless()
    }
    
    private func setupContentView() {
        let hostingView = NSHostingView(
            rootView: VolumeControlView(
                volumeMonitor: volumeMonitor,
                audioDeviceManager: audioDeviceManager
            )
            .background(
                MouseEventHandler(overlayWindow: self, volumeMonitor: volumeMonitor)
            )
            .preferredColorScheme(.dark)
        )
        
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = hostingView
    }
    
    // Method to enable/disable mouse events
    func setMouseEnabled(_ enabled: Bool) {
        self.ignoresMouseEvents = !enabled
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
    }
}

// Helper view to track mouse position and enable window when needed
struct MouseEventHandler: NSViewRepresentable {
    let overlayWindow: VolumeOverlayWindow
    let volumeMonitor: VolumeMonitor
    
    func makeNSView(context: Context) -> NSView {
        let view = MouseTrackingView(overlayWindow: overlayWindow, volumeMonitor: volumeMonitor)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class MouseTrackingView: NSView {
    weak var overlayWindow: VolumeOverlayWindow?
    weak var volumeMonitor: VolumeMonitor?
    private var trackingArea: NSTrackingArea?
    
    init(overlayWindow: VolumeOverlayWindow, volumeMonitor: VolumeMonitor) {
        self.overlayWindow = overlayWindow
        self.volumeMonitor = volumeMonitor
        super.init(frame: .zero)
        setupTracking()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTracking() {
        let options: NSTrackingArea.Options = [
            .mouseMoved,
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect
        ]
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        setupTracking()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // Only enable mouse events in the volume bar area (left 200px)
        let location = event.locationInWindow
        if location.x < 200 {
            overlayWindow?.setMouseEnabled(true)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        // Disable after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.volumeMonitor?.isVolumeChanging == false {
                self.overlayWindow?.setMouseEnabled(false)
            }
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let location = event.locationInWindow
        
        // Enable mouse only in the volume bar area
        if location.x < 200 {
            overlayWindow?.setMouseEnabled(true)
        } else {
            overlayWindow?.setMouseEnabled(false)
        }
    }
}
