import SwiftUI
import AppKit

/// A window that sits directly under the MacBook notch, overlapping slightly
/// into the notch area so the expanding bar appears to emerge seamlessly
/// from inside the notch itself.
class NotchAttachedWindow: NSWindow {
    private let volumeMonitor: VolumeMonitor
    private let targetScreen: NSScreen

    /// Wide enough for the expanded bar plus shadow bleed.
    static let windowWidth: CGFloat = 420
    /// Tall enough for the expanded bar plus shadow bleed below.
    /// Increased so the indicator can expand further down without being clipped.
    static let windowHeight: CGFloat = 140

    init(volumeMonitor: VolumeMonitor, screen: NSScreen) {
        self.volumeMonitor = volumeMonitor
        self.targetScreen = screen

        let frame = Self.windowFrame(for: screen)

        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setupWindowProperties()
        setupContentView()

        print("🖥️ NotchAttachedWindow created on: \(screen.localizedName)")
    }

    /// Compute the window frame so the top edge overlaps a few points into
    /// the notch/menu-bar area. Since both the notch and the collapsed bar
    /// are solid black, the overlap is invisible — creating a seamless
    /// connection when the bar expands outward.
    static func windowFrame(for screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let safeInsets = screen.safeAreaInsets

        // Place the window so its top edge aligns with the physical top
        // of the screen. This makes the collapsed sliver sit exactly at the
        // screen edge / notch area, so the expansion appears to come
        // directly out of the notch rather than starting below it.
        let x = screenFrame.midX - windowWidth / 2
        // Align top of the window with the screen's top edge
        let y = screenFrame.maxY - windowHeight

        // On some displays `safeAreaInsets.top` may represent the menu bar/notch
        // region — we intentionally align to the absolute top so the shape
        // visually emerges from the edge.
        return NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
    }

    /// Check whether a screen has a physical notch using safeAreaInsets.
    static func screenHasNotch(_ screen: NSScreen) -> Bool {
        return screen.safeAreaInsets.top > 0
    }

    private func setupWindowProperties() {
        self.isRestorable = false
        self.level = .statusBar
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
            rootView: NotchAttachedView(volumeMonitor: volumeMonitor)
                .background(.clear)
        )

        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        // Allow the hosting view to resize with the window so SwiftUI content
        // is never clipped when the shape expands.
        hostingView.autoresizingMask = [.width, .height]
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
        print("💀 NotchAttachedWindow deinit")
    }
}
