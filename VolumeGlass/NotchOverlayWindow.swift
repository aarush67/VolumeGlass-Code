import SwiftUI
import AppKit

class NotchOverlayWindow: NSWindow {
    private let volumeMonitor: VolumeMonitor
    private let targetScreen: NSScreen

    init(volumeMonitor: VolumeMonitor, screen: NSScreen) {
        self.volumeMonitor = volumeMonitor
        self.targetScreen = screen

        // Position the window centered horizontally. If the notch-attached
        // bar is enabled we place the pill below that bar; otherwise keep
        // default position just under the notch/menu bar area.
        let windowWidth: CGFloat = 280
        let windowHeight: CGFloat = 62
        let windowX = screen.frame.midX - windowWidth / 2

        var windowY: CGFloat
        if volumeMonitor.setupState?.showNotchBar == true && NotchAttachedWindow.screenHasNotch(screen) {
            // Place pill below the attached notch window to avoid overlapping.
            let attachedFrame = NotchAttachedWindow.windowFrame(for: screen)
            let spacing: CGFloat = 8
            windowY = attachedFrame.minY - windowHeight - spacing
        } else {
            // Backwards-compatible fallback: just below the menu bar/notch area
            let notchBottomY = Self.notchBottomY(for: screen)
            windowY = notchBottomY - windowHeight
        }

        let frame = NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)

        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setupWindowProperties()
        setupContentView()

        print("🔲 NotchOverlayWindow created on: \(screen.localizedName)")
    }

    /// Returns the Y coordinate (in AppKit screen coords) of the bottom edge of the notch area.
    /// For notched screens the safe-area top inset is larger than the menu bar height;
    /// for non-notched screens we fall back to just below the menu bar.
    static func notchBottomY(for screen: NSScreen) -> CGFloat {
        // screen.frame is the full display; screen.visibleFrame excludes the menu bar (and Dock).
        // The gap between screen.frame.maxY and screen.visibleFrame.maxY is the menu-bar/notch area.
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        // On notched MacBooks the menu-bar region is taller (~38pt vs ~25pt on non-notch).
        // We place the pill 6pt below that region.
        return screen.frame.maxY - menuBarHeight - 6
    }

    /// Best-effort check for whether the given screen has a camera housing (notch).
    /// On macOS 12+ with notched hardware the safe area at the top is significantly taller
    /// than a standard menu bar (~24pt).  We treat anything ≥ 33pt as a notch screen.
    static func screenHasNotch(_ screen: NSScreen) -> Bool {
        let topInset = screen.frame.maxY - screen.visibleFrame.maxY
        // Standard menu bar is ~24-25pt; notch screens report ~37-38pt.
        return topInset >= 33
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
        self.isExcludedFromWindowsMenu = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.orderFrontRegardless()
        }
    }

    private func setupContentView() {
        let contentViewController = NSViewController()

        let hostingView = NSHostingView(
            rootView: NotchVolumeView(volumeMonitor: volumeMonitor)
                .background(.clear)
        )

        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = []
        hostingView.frame = self.contentView?.bounds ?? self.frame

        hostingView.setContentHuggingPriority(.required, for: .horizontal)
        hostingView.setContentHuggingPriority(.required, for: .vertical)

        contentViewController.view = hostingView
        self.contentViewController = contentViewController
    }

    func showIndicator() {
        self.alphaValue = 1.0
        self.orderFrontRegardless()
    }

    deinit {
        print("💀 NotchOverlayWindow deinit")
    }
}
