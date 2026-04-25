//
//  UpdateAlertWindow.swift
//  VolumeGlass
//

import AppKit
import SwiftUI

// MARK: - Controller

class UpdateAlertWindowController: NSObject {
    static let shared = UpdateAlertWindowController()
    private var window: NSPanel?

    /// Show update-available popup
    func show() {
        DispatchQueue.main.async {
            if let w = self.window, w.isVisible {
                w.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            self.makeWindow(mode: .updateAvailable)
        }
    }

    /// Show "up to date" confirmation popup
    func showUpToDate() {
        DispatchQueue.main.async {
            if let w = self.window, w.isVisible {
                w.close()
            }
            self.makeWindow(mode: .upToDate)
        }
    }

    /// Show "checking" spinner popup
    func showChecking() {
        DispatchQueue.main.async {
            if let w = self.window, w.isVisible {
                w.close()
            }
            self.makeWindow(mode: .checking)
        }
    }

    func dismiss() {
        DispatchQueue.main.async {
            self.window?.close()
            self.window = nil
        }
    }

    enum AlertMode {
        case updateAvailable
        case upToDate
        case checking
    }

    private func makeWindow(mode: AlertMode) {
        let view = UpdateAlertView(mode: mode) { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 340, height: 1)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 200),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting

        // Fit to content then center
        let size = hosting.fittingSize
        panel.setContentSize(size)
        panel.center()

        self.window = panel

        // Activate the app and show the panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        // Auto-dismiss "up to date" after 3 seconds
        if mode == .upToDate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self, let w = self.window, w.isVisible else { return }
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.3
                    w.animator().alphaValue = 0
                }) {
                    w.close()
                    self.window = nil
                }
            }
        }
    }
}

// MARK: - Update Alert View (matches Settings design language)

private struct UpdateAlertView: View {
    @ObservedObject private var checker = UpdateChecker.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var installHover = false
    @State private var remindHover = false
    @State private var animateIn = false

    let mode: UpdateAlertWindowController.AlertMode
    let onDismiss: () -> Void

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.7)
    }

    private var cardStroke: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06)
    }

    var body: some View {
        Group {
            switch mode {
            case .updateAvailable:
                updateAvailableContent
            case .upToDate:
                upToDateContent
            case .checking:
                checkingContent
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardStroke, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 24, y: 8)
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .scaleEffect(animateIn ? 1.0 : 0.92)
        .opacity(animateIn ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }

    // MARK: - Section Header (matches Settings style)

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
        }
    }

    // MARK: - Update Available Content

    private var updateAvailableContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top bar with dismiss
            HStack {
                sectionHeader("Update Available", icon: "arrow.down.app")
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }

            // Info card
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.down.app.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("VolumeGlass \(checker.latestVersion ?? "")")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)

                        if let notes = checker.releaseNotes, !notes.isEmpty {
                            Text(notes)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        } else {
                            Text("A new version is available.")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if let v = checker.latestVersion {
                        Text("v\(v)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(cardStroke, lineWidth: 0.5)
            )

            // Action buttons
            VStack(spacing: 8) {
                Button {
                    onDismiss()
                    if let url = UpdateChecker.shared.downloadURL {
                        AutoUpdater.shared.installUpdate(from: url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 13, weight: .medium))
                        Text("Install Update")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(installHover ? 1.0 : 0.88))
                    )
                }
                .buttonStyle(.plain)
                .onHover { installHover = $0 }

                Button {
                    UpdateChecker.shared.remindLater()
                    onDismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text("Remind in 3 Days")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(remindHover ? 0.06 : 0.03))
                    )
                }
                .buttonStyle(.plain)
                .onHover { remindHover = $0 }
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    // MARK: - Up To Date Content

    private var upToDateContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("App Version", icon: "info.circle")

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("You're up to date")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("VolumeGlass \(checker.currentVersion) is the latest version.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("UP TO DATE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.12))
                        )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(cardStroke, lineWidth: 0.5)
            )
        }
        .padding(20)
        .frame(width: 340)
    }

    // MARK: - Checking Content

    private var checkingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Updates", icon: "arrow.clockwise")

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.regular)
                        .scaleEffect(0.8)
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Checking for updates")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Please wait…")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(cardStroke, lineWidth: 0.5)
            )
        }
        .padding(20)
        .padding(.vertical, 22)
        .frame(width: 240)
    }
}
