import SwiftUI

struct VolumeIndicatorView: View {
    @ObservedObject var volumeMonitor: VolumeMonitor
    
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var showVolumeBar = false
    @State private var hoverTimer: Timer?
    @State private var pulseAnimation = false
    @State private var isDeviceMenuOpen = false
    @State private var isQuickActionsOpen = false
    @Environment(\.colorScheme) var colorScheme
    
    private var setupState: SetupState? { volumeMonitor.setupState }
    private var barSize: CGFloat { setupState?.barSize ?? 1.0 }
    private var isVertical: Bool { setupState?.isVertical ?? true }
    
    private var barHeight: CGFloat { 220 * barSize }
    private var normalWidth: CGFloat { 12 * barSize }
    private var expandedWidth: CGFloat { 18 * barSize }
    private var cornerRadius: CGFloat { 9 * barSize }
    
    private var hoverZoneWidth: CGFloat { isVertical ? 100 : barHeight + 80 }
    private var hoverZoneHeight: CGFloat { isVertical ? barHeight + 80 : 100 }
    
    var effectiveWidth: CGFloat {
        (isHovering || isDragging || volumeMonitor.isVolumeChanging || isDeviceMenuOpen || isQuickActionsOpen) ? expandedWidth : normalWidth
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(width: hoverZoneWidth, height: hoverZoneHeight)
                .onHover { hovering in
                    handleHover(hovering)
                }
            
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeviceMenuStateChanged"))) { notification in
            if let isOpen = notification.userInfo?["isOpen"] as? Bool {
                isDeviceMenuOpen = isOpen
                if isOpen {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showVolumeBar = true
                    }
                    NotificationCenter.default.post(
                        name: NSNotification.Name("VolumeBarVisibilityChanged"),
                        object: nil,
                        userInfo: ["isVisible": true]
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("QuickActionsStateChanged"))) { notification in
            if let isOpen = notification.userInfo?["isOpen"] as? Bool {
                isQuickActionsOpen = isOpen
                if isOpen {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showVolumeBar = true
                    }
                    NotificationCenter.default.post(
                        name: NSNotification.Name("VolumeBarVisibilityChanged"),
                        object: nil,
                        userInfo: ["isVisible": true]
                    )
                }
            }
        }
        .accessibilityLabel("Volume: \(Int(volumeMonitor.currentVolume * 100))%")
        .accessibilityValue("\(Int(volumeMonitor.currentVolume * 100)) percent")
    }
    
    private var verticalVolumeBar: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .bottom) {
                backgroundTrack.frame(width: effectiveWidth, height: barHeight)
                volumeFill.frame(width: effectiveWidth, height: calculateFillHeight())
                if volumeMonitor.isMuted { muteOverlay }
            }
            .frame(width: effectiveWidth, height: barHeight)
            .scaleEffect(isDragging ? 1.02 : 1.0)
            .gesture(verticalDragGesture)
            Spacer()
        }
    }
    
    private var horizontalVolumeBar: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                backgroundTrack.frame(width: barHeight, height: effectiveWidth)
                volumeFill.frame(width: calculateFillWidth(), height: effectiveWidth)
                if volumeMonitor.isMuted { muteOverlay }
            }
            .frame(width: barHeight, height: effectiveWidth)
            .scaleEffect(isDragging ? 1.02 : 1.0)
            .gesture(horizontalDragGesture)
            Spacer()
        }
    }
    
    private var backgroundTrack: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.clear)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(colorScheme == .dark ? 0.3 : 0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.25),
                                Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.1 : 0.2), radius: 3, x: 0, y: 2)
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
                                (colorScheme == .dark ? Color.white : Color.black).opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: (colorScheme == .dark ? Color.white : Color.black).opacity(0.2), radius: 2, x: 0, y: isVertical ? -1 : 0)
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: isVertical ? 2 : 0)
    }
    
    private var adaptiveGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.white.opacity(0.95),
                Color.white.opacity(0.85),
                Color.white.opacity(0.75)
            ]
        } else {
            return [
                Color(red: 0.2, green: 0.25, blue: 0.3).opacity(0.95),
                Color(red: 0.15, green: 0.2, blue: 0.25).opacity(0.9),
                Color(red: 0.1, green: 0.15, blue: 0.2).opacity(0.85)
            ]
        }
    }
    
    private var muteOverlay: some View {
        Image(systemName: "speaker.slash.fill")
            .font(.system(size: 12 * barSize, weight: .semibold))
            .foregroundColor(colorScheme == .dark ? .white : Color(red: 0.2, green: 0.2, blue: 0.2))
            .opacity(0.9)
            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseAnimation)
            .onAppear { pulseAnimation = true }
    }
    
    private func calculateFillHeight() -> CGFloat {
        if volumeMonitor.isMuted { return cornerRadius * 2 }
        return max(cornerRadius * 2, barHeight * CGFloat(volumeMonitor.currentVolume))
    }
    
    private func calculateFillWidth() -> CGFloat {
        if volumeMonitor.isMuted { return cornerRadius * 2 }
        return max(cornerRadius * 2, barHeight * CGFloat(volumeMonitor.currentVolume))
    }
    
    private func handleVolumeChanging(_ isChanging: Bool) {
        if isChanging {
            withAnimation(.easeInOut(duration: 0.2)) {
                showVolumeBar = true
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("VolumeBarVisibilityChanged"),
                object: nil,
                userInfo: ["isVisible": true]
            )
        } else {
            if !isDeviceMenuOpen && !isQuickActionsOpen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if !self.isHovering && !self.isDragging && !self.isDeviceMenuOpen && !self.isQuickActionsOpen {
                        withAnimation(.easeOut(duration: 0.4)) {
                            self.showVolumeBar = false
                        }
                        NotificationCenter.default.post(
                            name: NSNotification.Name("VolumeBarVisibilityChanged"),
                            object: nil,
                            userInfo: ["isVisible": false]
                        )
                    }
                }
            }
        }
    }
    
    private func handleHover(_ hovering: Bool) {
        hoverTimer?.invalidate()
        
        if hovering {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = true
                showVolumeBar = true
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("VolumeBarVisibilityChanged"),
                object: nil,
                userInfo: ["isVisible": true]
            )
        } else {
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.isHovering = false
                }
                
                if !self.volumeMonitor.isVolumeChanging && !self.isDragging && !self.isDeviceMenuOpen && !self.isQuickActionsOpen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if !self.isHovering && !self.isDragging && !self.volumeMonitor.isVolumeChanging && !self.isDeviceMenuOpen && !self.isQuickActionsOpen {
                            withAnimation(.easeOut(duration: 0.4)) {
                                self.showVolumeBar = false
                            }
                            NotificationCenter.default.post(
                                name: NSNotification.Name("VolumeBarVisibilityChanged"),
                                object: nil,
                                userInfo: ["isVisible": false]
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func triggerHapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
    
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
                if volumePercent % 50 == 0 { triggerHapticFeedback() }
                volumeMonitor.setSystemVolume(Float(newVolume))
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isDragging = false
                }
                if !isHovering && !isDeviceMenuOpen && !isQuickActionsOpen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if !self.isHovering && !self.isDragging && !self.isDeviceMenuOpen && !self.isQuickActionsOpen {
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
                if volumePercent % 50 == 0 { triggerHapticFeedback() }
                volumeMonitor.setSystemVolume(Float(newVolume))
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isDragging = false
                }
                if !isHovering && !isDeviceMenuOpen && !isQuickActionsOpen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if !self.isHovering && !self.isDragging && !self.isDeviceMenuOpen && !self.isQuickActionsOpen {
                            withAnimation(.easeOut(duration: 0.4)) {
                                self.showVolumeBar = false
                            }
                        }
                    }
                }
            }
    }
}

