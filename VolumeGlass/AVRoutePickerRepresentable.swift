import AVKit
import SwiftUI

/// Wraps AVRoutePickerView so it can live inside a SwiftUI view.
/// The view is invisible — its only purpose is to be triggered
/// programmatically when the user taps a Bonjour-discovered AirPlay device.
/// When triggered, it shows the same AirPlay picker as Control Center.
///
/// Posts notifications so VolumeControlView can pause its auto-dismiss timer
/// while the picker is open:
///   "AirPlayPickerOpened"  — picker just appeared
///   "AirPlayPickerClosed"  — picker was dismissed
struct AVRoutePickerRepresentable: NSViewRepresentable {
    @Binding var triggerClick: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.alphaValue = 0
        view.wantsLayer = true
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {
        guard triggerClick else { return }
        DispatchQueue.main.async {
            if let button = Self.findButton(in: nsView) {
                button.performClick(nil)
            }
            triggerClick = false
        }
    }

    private static func findButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton { return button }
        for subview in view.subviews {
            if let found = findButton(in: subview) { return found }
        }
        return nil
    }

    // MARK: - Delegate

    class Coordinator: NSObject, AVRoutePickerViewDelegate {
        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            NotificationCenter.default.post(name: .airPlayPickerOpened, object: nil)
        }

        func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            NotificationCenter.default.post(name: .airPlayPickerClosed, object: nil)
        }
    }
}

extension Notification.Name {
    static let airPlayPickerOpened = Notification.Name("AirPlayPickerOpened")
    static let airPlayPickerClosed = Notification.Name("AirPlayPickerClosed")
}
