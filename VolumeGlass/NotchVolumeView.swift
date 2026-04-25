import SwiftUI

struct NotchVolumeView: View {
    @ObservedObject var volumeMonitor: VolumeMonitor
    @State private var showIndicator = false
    @Environment(\.colorScheme) var colorScheme

    // Pulse state for 100% feedback
    @State private var isPulseActive = false
    @State private var lastPulseTime: TimeInterval = 0
    private let minPulseInterval: TimeInterval = 0.06
    private let shrinkScale: CGFloat = 0.90

    // Notch pill dimensions
    private let pillWidth: CGFloat = 220
    private let pillHeight: CGFloat = 32
    private let cornerRadius: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            // The pill sits just below the notch
            notchPill
                .opacity(showIndicator ? 1.0 : 0.0)
                .offset(y: showIndicator ? 0 : -10)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showIndicator)
        }
        .frame(width: pillWidth + 40, height: pillHeight + 30)
        .onReceive(volumeMonitor.$isVolumeChanging) { isChanging in
            if isChanging {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showIndicator = true
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if !self.volumeMonitor.isVolumeChanging {
                        withAnimation(.easeOut(duration: 0.3)) {
                            self.showIndicator = false
                        }
                    }
                }
            }
        }
        .onChange(of: effectiveVolume) { _, newValue in
            if newValue >= 0.999 {
                // only pulse when visible
                if showIndicator {
                    pulse()
                }
            }
        }
    }

    private var notchPill: some View {
        HStack(spacing: 10) {
            // Volume icon
            Image(systemName: volumeIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(volumeMonitor.isMuted ? Color.secondary : Color.primary)
                .frame(width: 16)

            // Volume bar track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.08))
                        .frame(height: 6)

                    // Fill
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: volumeMonitor.isMuted
                                    ? [Color.gray.opacity(0.4), Color.gray.opacity(0.3)]
                                    : adaptiveGradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(effectiveVolume)), height: 6)
                        .scaleEffect(isPulseActive ? shrinkScale : 1.0, anchor: .leading)
                        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isPulseActive)
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: effectiveVolume)
                }
                .frame(height: 6)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .frame(height: 6)

            // Percentage text
            Text("\(Int(effectiveVolume * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .contentTransition(.numericText())
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: pillWidth, height: pillHeight)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(colorScheme == .dark ? 0.85 : 0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var effectiveVolume: Float {
        volumeMonitor.isMuted ? 0 : volumeMonitor.currentVolume
    }

    private func pulse() {
        let now = Date().timeIntervalSince1970
        if now - lastPulseTime < minPulseInterval {
            lastPulseTime = now
            isPulseActive = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { pulse() }
            return
        }
        lastPulseTime = now
        withAnimation(.easeIn(duration: 0.08)) { isPulseActive = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.interpolatingSpring(stiffness: 700, damping: 22)) { isPulseActive = false }
        }
        triggerHapticFeedback()
    }

    private var volumeIcon: String {
        if volumeMonitor.isMuted { return "speaker.slash.fill" }
        else if volumeMonitor.currentVolume > 0.66 { return "speaker.wave.3.fill" }
        else if volumeMonitor.currentVolume > 0.33 { return "speaker.wave.2.fill" }
        else if volumeMonitor.currentVolume > 0 { return "speaker.wave.1.fill" }
        else { return "speaker.fill" }
    }

    private var adaptiveGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.white.opacity(0.95),
                Color.white.opacity(0.80)
            ]
        } else {
            return [
                Color(white: 0.25).opacity(0.9),
                Color(white: 0.35).opacity(0.85)
            ]
        }
    }

    private func triggerHapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
