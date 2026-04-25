import SwiftUI

/// A volume indicator that fluidly emerges from inside the MacBook's physical notch,
/// expanding outward with a Dynamic Island-style spring animation.
/// The shape starts as a tiny sliver hidden behind the notch and expands in both
/// width and height, with content fading in after the shape begins opening.
struct NotchAttachedView: View {
    @ObservedObject var volumeMonitor: VolumeMonitor
    @State private var expanded = false
    @State private var contentVisible = false

    // Pulse state for 100% feedback
    @State private var isPulseActive = false
    @State private var lastPulseTime: TimeInterval = 0
    private let minPulseInterval: TimeInterval = 0.06
    private let shrinkScale: CGFloat = 0.90

    // Collapsed: narrow sliver hidden behind notch (both are black, so invisible)
    private let collapsedWidth: CGFloat = 200
    private let collapsedHeight: CGFloat = 6
    // Expanded: wider than the notch for a satisfying pop — increased height
    // so content doesn't get cut off by the hardware notch.
    private let expandedWidth: CGFloat = 320
    private let expandedHeight: CGFloat = 92

    private var effectiveVolume: Float {
        volumeMonitor.isMuted ? 0 : volumeMonitor.currentVolume
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Black shape that morphs from a thin notch-matching sliver
                // to the full expanded bar. Top corners stay square to blend
                // seamlessly with the notch; bottom corners round out as it opens.
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: expanded ? 20 : 8,
                    bottomTrailingRadius: expanded ? 20 : 8,
                    topTrailingRadius: 0
                )
                .fill(Color.black)
                .shadow(
                    color: .black.opacity(expanded ? 0.5 : 0),
                    radius: expanded ? 20 : 0,
                    y: expanded ? 8 : 0
                )

                // Content reveals with a staggered delay after the shape opens
                if contentVisible {
                    notchContent
                        .transition(.asymmetric(
                            insertion: .opacity
                                .combined(with: .offset(y: -4))
                                .combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                }
            }
            .frame(
                width: expanded ? expandedWidth : collapsedWidth,
                height: expanded ? expandedHeight : collapsedHeight
            )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onReceive(volumeMonitor.$isVolumeChanging) { isChanging in
            if isChanging {
                // 1. Shape expands with a bouncy spring
                withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                    expanded = true
                }
                // 2. Content fades in slightly after the shape starts opening
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        contentVisible = true
                    }
                }
            } else {
                // Auto-retract after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    guard !self.volumeMonitor.isVolumeChanging else { return }
                    // 1. Fade content first
                    withAnimation(.easeOut(duration: 0.12)) {
                        contentVisible = false
                    }
                    // 2. Retract shape back into the notch
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        guard !self.volumeMonitor.isVolumeChanging else { return }
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            expanded = false
                        }
                    }
                }
            }
        }
        .onChange(of: effectiveVolume) { _, newValue in
            if newValue >= 0.999 {
                // only pulse if content is visible
                if contentVisible {
                    pulse()
                }
            }
        }
    }

    private var notchContent: some View {
        HStack(spacing: 10) {
            Image(systemName: volumeIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(volumeMonitor.isMuted ? .gray : .white)
                .frame(width: 18)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 5)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: volumeMonitor.isMuted
                                    ? [Color.gray.opacity(0.5), Color.gray.opacity(0.35)]
                                    : [Color.white.opacity(0.95), Color.white.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(5, geo.size.width * CGFloat(effectiveVolume)), height: 5)
                        .scaleEffect(isPulseActive ? shrinkScale : 1.0, anchor: .leading)
                        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isPulseActive)
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: effectiveVolume)
                }
                .frame(height: 5)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .frame(height: 5)

            Text("\(Int(effectiveVolume * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .contentTransition(.numericText())
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
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

    private func triggerHapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
