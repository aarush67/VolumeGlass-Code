import SwiftUI
import AppKit

class VolumeOverlayWindow: NSWindow {
    private let volumeMonitor: VolumeMonitor
    private let audioDeviceManager = AudioDeviceManager()
    private var windowOrderTimer: Timer?
    private let targetScreen: NSScreen

    // Track menu states to ensure mouse events are enabled when ANY menu is open
    private var isDeviceMenuOpen = false
    private var isQuickActionsOpen = false
    private var isVolumeBarVisible = false
    
    init(volumeMonitor: VolumeMonitor, screen: NSScreen) {
        self.volumeMonitor = volumeMonitor
        self.targetScreen = screen
        
        let screenFrame = screen.visibleFrame
        let setupState = volumeMonitor.setupState
        let selectedPosition = setupState?.selectedPosition ?? .leftMiddleVertical
        let barSize = setupState?.barSize ?? 1.0
        let isVertical = selectedPosition.isVertical
        
        // Get the base position for the bar on THIS screen
        let baseWindowFrame = selectedPosition.getScreenPosition(screenFrame: screenFrame, barSize: barSize)
        
        // Calculate window expansion to accommodate menus
        // The window needs to be large enough to show the volume bar + menus without cutoff
        let expandedWindowFrame: NSRect
        if isVertical {
            // For vertical layouts, expand to the right and add padding on all sides
            // Scale expansion based on barSize to prevent cutoff when bar is larger
            let totalMenuWidth: CGFloat = 400 * max(barSize, 1.0)  // Space for largest menu + padding
            let extraPadding: CGFloat = 60 * max(barSize, 1.0)
            
            if selectedPosition == .leftMiddleVertical {
                let safeX = max(baseWindowFrame.minX, screenFrame.minX + 24)
                expandedWindowFrame = NSRect(
                    x: safeX,
                    y: baseWindowFrame.minY - extraPadding,
                    width: baseWindowFrame.width + totalMenuWidth + extraPadding,
                    height: baseWindowFrame.height + extraPadding * 2
                )
            } else if selectedPosition == .rightVertical {
                // Right vertical opens menus to the left; reserve most expansion on the left side.
                expandedWindowFrame = NSRect(
                    x: baseWindowFrame.minX - totalMenuWidth - extraPadding,
                    y: baseWindowFrame.minY - extraPadding,
                    width: baseWindowFrame.width + totalMenuWidth + extraPadding,
                    height: baseWindowFrame.height + extraPadding * 2
                )
            } else {
                expandedWindowFrame = NSRect(
                    x: baseWindowFrame.minX - extraPadding,
                    y: baseWindowFrame.minY - extraPadding,
                    width: baseWindowFrame.width + totalMenuWidth + extraPadding,
                    height: baseWindowFrame.height + extraPadding * 2
                )
            }
        } else {
            // For horizontal layouts, expand in the same direction as the menu placement.
            let totalMenuHeight: CGFloat = 400 * max(barSize, 1.0)  // Space for menu + padding
            let extraPadding: CGFloat = 60 * max(barSize, 1.0)

            if selectedPosition == .bottomHorizontal {
                // Bottom horizontal opens upward: keep bar near bottom and grow window upward.
                expandedWindowFrame = NSRect(
                    x: baseWindowFrame.minX - extraPadding,
                    y: baseWindowFrame.minY - extraPadding,
                    width: baseWindowFrame.width + extraPadding * 2,
                    height: baseWindowFrame.height + totalMenuHeight + extraPadding
                )
            } else {
                // Top horizontal opens downward: keep bar near top and grow window downward.
                expandedWindowFrame = NSRect(
                    x: baseWindowFrame.minX - extraPadding,
                    y: baseWindowFrame.minY - totalMenuHeight - extraPadding,
                    width: baseWindowFrame.width + extraPadding * 2,
                    height: baseWindowFrame.height + totalMenuHeight + extraPadding
                )
            }
        }
        
        super.init(
            contentRect: expandedWindowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindowProperties()
        
        do {
            try setupContentView()
        } catch {
            print("❌ Error setting up content view: \(error)")
        }
        
        audioDeviceManager.loadDevices()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(barVisibilityChanged(_:)),
            name: NSNotification.Name("VolumeBarVisibilityChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceMenuStateChanged(_:)),
            name: NSNotification.Name("DeviceMenuStateChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(quickActionsStateChanged(_:)),
            name: NSNotification.Name("QuickActionsStateChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged(_:)),
            name: NSNotification.Name("SettingsChanged"),
            object: nil
        )
        
        print("📺 Window created on screen: \(screen.localizedName)")
        print("   Screen frame: \(screenFrame)")
        print("   Window frame: \(expandedWindowFrame)")
        print("   Orientation: \(isVertical ? "Vertical" : "Horizontal")")
    }
    
    private func setupWindowProperties() {
        self.isRestorable = false
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        
        // Prevent window frame from being saved
        self.isExcludedFromWindowsMenu = true
        
        // CRITICAL: Ensure window appears on the correct screen
        if let screen = NSScreen.screens.first(where: { $0.frame == targetScreen.frame }) {
            self.setFrameOrigin(self.frame.origin)
        }
        
        // Delay ordering to allow proper initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.orderFrontRegardless()
        }
    }
    
    private func setupContentView() throws {
        let contentViewController = NSViewController()
        
        let hostingView = NSHostingView(
            rootView: VolumeControlView(
                volumeMonitor: volumeMonitor,
                audioDeviceManager: audioDeviceManager
            )
            .background(.clear)
        )
        
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // CRITICAL: Prevent SwiftUI from driving window sizing
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = []  // No auto-resize - window size is fixed
        hostingView.frame = self.contentView?.bounds ?? self.frame
        
        // CRITICAL: Set high priority to prevent size changes
        hostingView.setContentHuggingPriority(.required, for: .horizontal)
        hostingView.setContentHuggingPriority(.required, for: .vertical)
        
        contentViewController.view = hostingView
        self.contentViewController = contentViewController
    }
    
    @objc private func barVisibilityChanged(_ notification: Notification) {
        if let isVisible = notification.userInfo?["isVisible"] as? Bool {
            isVolumeBarVisible = isVisible
            updateMouseEvents()
            print("🖱️ Volume bar visible: \(isVisible)")
        }
    }

    @objc private func deviceMenuStateChanged(_ notification: Notification) {
        if let isOpen = notification.userInfo?["isOpen"] as? Bool {
            isDeviceMenuOpen = isOpen
            updateMouseEvents()
            print("🎵 Device menu \(isOpen ? "OPENED" : "closed")")
        }
    }

    @objc private func quickActionsStateChanged(_ notification: Notification) {
        if let isOpen = notification.userInfo?["isOpen"] as? Bool {
            isQuickActionsOpen = isOpen
            updateMouseEvents()
            print("⚡ Quick actions \(isOpen ? "OPENED" : "closed")")
        }
    }

    private func updateMouseEvents() {
        // Enable mouse events if ANY menu is open OR volume bar is visible
        let shouldEnableMouseEvents = isDeviceMenuOpen || isQuickActionsOpen || isVolumeBarVisible
        self.ignoresMouseEvents = !shouldEnableMouseEvents
        print("🖱️ Mouse events: \(shouldEnableMouseEvents ? "✅ ENABLED" : "❌ DISABLED") (DeviceMenu:\(isDeviceMenuOpen) QuickActions:\(isQuickActionsOpen) VolumeBar:\(isVolumeBarVisible))")
    }
    
    @objc private func settingsChanged(_ notification: Notification) {
        print("⚙️ Settings changed notification received")
        // Ensure the window is properly displayed with new settings
        self.showVolumeIndicator()
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
        print("💀 VolumeOverlayWindow deinit called")
        windowOrderTimer?.invalidate()
        windowOrderTimer = nil
        // Remove all notifications observed by this window to avoid callbacks into deallocated instances.
        NotificationCenter.default.removeObserver(self)
    }
}