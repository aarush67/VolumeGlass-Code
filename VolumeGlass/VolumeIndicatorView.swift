import SwiftUI

struct VolumeIndicatorView: View {
    @ObservedObject var volumeMonitor: VolumeMonitor
    
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var showVolumeBar = false
    @State private var hoverTimer: Timer?
    @State private var pulseAnimation = false
    @Environment(\.colorScheme) var colorScheme
    
    private var setupState: SetupState? { volumeMonitor.setupState }
    private var barSize: CGFloat { setupState?.barSize ?? 1.0 }
    private var isVertical: Bool { setupState?.isVertical ?? true }
    
    private var barHeight: CGFloat { 220 * barSize }
    private var normalWidth: CGFloat { 12 * barSize }
    private var expandedWidth: CGFloat { 18 * barSize }
    private var cornerRadius: CGFloat { 9 * barSize }
    
    // HUGE hover zone
    private var hoverZoneWidth: CGFloat { isVertical ? 100 : barHeight + 80 }
    private var hoverZoneHeight: CGFloat { isVertical ? barHeight + 80 : 100 }
    
    var effectiveWidth: CGFloat {
        (isHovering || isDragging || volumeMonitor.isVolumeChanging) ? expandedWidth : normalWidth
    }
    
    var body: some View {
        ZStack {
            // ALWAYS VISIBLE HOVER DETECTION AREA
            Rectangle()
                .fill(Color.white.opacity(0.001)) // Nearly invisible but still detectable
                .frame(width: hoverZoneWidth, height: hoverZoneHeight)
                .onHover { hovering in
                    print("🖱️ HOVER: \(hovering)")
                    handleHover(hovering)
                }
            
            // VOLUME BAR (can be hidden)
            Group {
                if isVertical {
                    verticalVolumeBar
                } else {
                    horizontalVolumeBar
                }
            }
            .opacity(showVolumeBar ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.25), value: showVolumeBar)
        }
        .frame(width: hoverZoneWidth, height: hoverZoneHeight)
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.4), value: effectiveWidth)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: volumeMonitor.currentVolume)
        .onReceive(volumeMonitor.$isVolumeChanging) { isChanging in
            handleVolumeChanging(isChanging)
        }
        .accessibilityLabel("Volume: \(Int(volumeMonitor.currentVolume * 100))%")
        .accessibilityValue("\(Int(volumeMonitor.currentVolume * 100)) percent")
    }
    
    // MARK: - Vertical Volume Bar
    
    private var verticalVolumeBar: some View {
        VStack(spacing: 0) {
            Spacer()
            
            ZStack(alignment: .bottom) {
                backgroundTrack
                    .frame(width: effectiveWidth, height: barHeight)
                
                volumeFill
                    .frame(
                        width: effectiveWidth,
                        height: calculateFillHeight()
                    )
                
                if volumeMonitor.isMuted {
                    muteOverlay
                }
            }
            .frame(width: effectiveWidth, height: barHeight)
            .scaleEffect(isDragging ? 1.02 : 1.0)
            .gesture(verticalDragGesture)
            
            Spacer()
        }
    }
    
    // MARK: - Horizontal Volume Bar
    
    private var horizontalVolumeBar: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                backgroundTrack
                    .frame(width: barHeight, height: effectiveWidth)
                
                volumeFill
                    .frame(
                        width: calculateFillWidth(),
                        height: effectiveWidth
                    )
                
                if volumeMonitor.isMuted {
                    muteOverlay
                }
            }
            .frame(width: barHeight, height: effectiveWidth)
            .scaleEffect(isDragging ? 1.02 : 1.0)
            .gesture(horizontalDragGesture)
            
            Spacer()
        }
    }
    
    // MARK: - Component Views
    
    private var backgroundTrack: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.clear)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    private var volumeFill: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: volumeMonitor.isMuted ? [
                        Color.gray.opacity(0.6),
                        Color.gray.opacity(0.4)
                    ] : adaptiveGradientColors,
                    startPoint: isVertical ? .top : .leading,
                    endPoint: isVertical ? .bottom : .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: .white.opacity(0.2), radius: 2, x: 0, y: isVertical ? -1 : 0)
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: isVertical ? 2 : 0)
    }
    
    private var adaptiveGradientColors: [Color] {
        colorScheme == .dark ? [
            Color.white.opacity(0.95),
            Color.white.opacity(0.85),
            Color.white.opacity(0.75)
        ] : [
            Color.black.opacity(0.85),
            Color.black.opacity(0.75),
            Color.black.opacity(0.65)
        ]
    }
    
    private var muteOverlay: some View {
        Image(systemName: "speaker.slash.fill")
            .font(.system(size: 12 * barSize, weight: .semibold))
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .opacity(0.9)
            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseAnimation)
            .onAppear {
                pulseAnimation = true
            }
    }
    
    // MARK: - Helper Functions
    
    private func calculateFillHeight() -> CGFloat {
        if volumeMonitor.isMuted {
            return cornerRadius * 2
        }
        return max(cornerRadius * 2, barHeight * CGFloat(volumeMonitor.currentVolume))
    }
    
    private func calculateFillWidth() -> CGFloat {
        if volumeMonitor.isMuted {
            return cornerRadius * 2
        }
        return max(cornerRadius * 2, barHeight * CGFloat(volumeMonitor.currentVolume))
    }
    
    private func handleVolumeChanging(_ isChanging: Bool) {
        print("📢 Volume changing: \(isChanging)")
        if isChanging {
            withAnimation(.easeInOut(duration: 0.2)) {
                showVolumeBar = true
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if !self.isHovering && !self.isDragging {
                    withAnimation(.easeOut(duration: 0.4)) {
                        self.showVolumeBar = false
                    }
                }
            }
        }
    }
    
    private func handleHover(_ hovering: Bool) {
        print("👆 HANDLING HOVER: \(hovering)")
        hoverTimer?.invalidate()
        
        if hovering {
            print("✅ SHOWING BAR!")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = true
                showVolumeBar = true
            }
        } else {
            print("⏳ Will hide soon")
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.isHovering = false
                }
                
                if !self.volumeMonitor.isVolumeChanging && !self.isDragging {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if !self.isHovering && !self.isDragging && !self.volumeMonitor.isVolumeChanging {
                            print("🚫 HIDING BAR")
                            withAnimation(.easeOut(duration: 0.4)) {
                                self.showVolumeBar = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func triggerHapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .now
        )
    }
    
    // MARK: - Gestures
    
    private var verticalDragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.9)) {
                    isDragging = true
                    showVolumeBar = true
                }
                
                let dragY = value.location.y
                let newVolume = max(0, min(1, 1 - (dragY / barHeight)))
                
                let volumePercent = Int(newVolume * 100)
                if volumePercent % 50 == 0 {
                    triggerHapticFeedback()
                }
                
                volumeMonitor.setSystemVolume(Float(newVolume))
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isDragging = false
                }
                
                if !isHovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if !self.isHovering && !self.isDragging {
                            withAnimation(.easeOut(duration: 0.4)) {
                                self.showVolumeBar = false
                            }
                        }
                    }
                }
            }
    }
    
    private var horizontalDragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.9)) {
                    isDragging = true
                    showVolumeBar = true
                }
                
                let dragX = value.location.x
                let newVolume = max(0, min(1, dragX / barHeight))
                
                let volumePercent = Int(newVolume * 100)
                if volumePercent % 50 == 0 {
                    triggerHapticFeedback()
                }
                
                volumeMonitor.setSystemVolume(Float(newVolume))
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isDragging = false
                }
                
                if !isHovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if !self.isHovering && !self.isDragging {
                            withAnimation(.easeOut(duration: 0.4)) {
                                self.showVolumeBar = false
                            }
                        }
                    }
                }
            }
    }
}

