import SwiftUI

struct VolumeIndicatorView: View {
    @ObservedObject var volumeMonitor: VolumeMonitor
    
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var showVolumeBar = false
    @State private var hoverTimer: Timer?
    @State private var isDeviceMenuOpen = false
    @State private var isQuickActionsOpen = false
    @Environment(\.colorScheme) var colorScheme
    
    // Pulse state for 100% feedback
    @State private var isPulseActive = false
    @State private var lastPulseTime: TimeInterval = 0
    private let minPulseInterval: TimeInterval = 0.06
    private let shrinkScale: CGFloat = 0.90

    private var setupState: SetupState? { volumeMonitor.setupState }
    private var barSize: CGFloat { setupState?.barSize ?? 1.0 }
    private var isVertical: Bool { setupState?.selectedPosition.isVertical ?? true }

    private var barLength: CGFloat { 220 * barSize }
    private var normalThickness: CGFloat { 12 * barSize }
    private var expandedThickness: CGFloat { 18 * barSize }
    private var cornerRadius: CGFloat { 9 * barSize }
    
    private var hoverZoneWidth: CGFloat { isVertical ? 100 : min(barLength + 80, 350) }
    private var hoverZoneHeight: CGFloat { isVertical ? min(barLength + 80, 350) : 100 }
    
    private func pulse() {
        let now = Date().timeIntervalSince1970
        // prevent extremely rapid re-triggers; allow quick restart if needed
        if now - lastPulseTime < minPulseInterval {
            // restart pulse by briefly resetting
            lastPulseTime = now
            isPulseActive = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { pulse() }
            return
        }
        lastPulseTime = now
        // quick shrink
        withAnimation(.easeIn(duration: 0.08)) { isPulseActive = true }
        // spring back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.interpolatingSpring(stiffness: 700, damping: 22)) { isPulseActive = false }
        }
        // subtle haptic
        triggerHapticFeedback()
    }
    
    var effectiveThickness: CGFloat {
        (isHovering || isDragging || volumeMonitor.isVolumeChanging || isDeviceMenuOpen || isQuickActionsOpen) ? expandedThickness : normalThickness
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
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.4), value: effectiveThickness)
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
                } else {
                    // Device menu closed — fade out after a short pause
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        if !self.isHovering && !self.isDragging && !self.isDeviceMenuOpen && !self.isQuickActionsOpen && !self.volumeMonitor.isVolumeChanging {
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
                } else {
                    // Quick actions closed — fade out after a short pause
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !self.isHovering && !self.isDragging && !self.isDeviceMenuOpen && !self.isQuickActionsOpen && !self.volumeMonitor.isVolumeChanging {
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
        .onChange(of: volumeMonitor.currentVolume) { _, newValue in
            // trigger pulse when reaching (near) 100%
            if newValue >= 0.999 {
                // ensure visible and not hidden
                if showVolumeBar {
                    pulse()
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
                backgroundTrack.frame(width: effectiveThickness, height: barLength)
                volumeFill.frame(width: effectiveThickness, height: calculateFillLength())
                    .scaleEffect(isPulseActive ? shrinkScale : 1.0, anchor: isVertical ? .bottom : .leading)
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isPulseActive)
                if volumeMonitor.isMuted { muteOverlay }
            }
            .frame(width: effectiveThickness, height: barLength)
            .scaleEffect(isDragging ? 1.02 : 1.0)
            .gesture(verticalDragGesture)
            .onTapGesture {
                // Single tap opens quick settings
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenQuickActions"),
                    object: nil
                )
            }
            Spacer()
        }
    }
    
    private var horizontalVolumeBar: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                backgroundTrack.frame(width: barLength, height: effectiveThickness)
                volumeFill.frame(width: calculateFillLength(), height: effectiveThickness)
                    .scaleEffect(isPulseActive ? shrinkScale : 1.0, anchor: isVertical ? .bottom : .leading)
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isPulseActive)
                if volumeMonitor.isMuted { muteOverlay }
            }
            .frame(width: barLength, height: effectiveThickness)
            .scaleEffect(isDragging ? 1.02 : 1.0)
            .gesture(horizontalDragGesture)
            .onTapGesture {
                // Single tap opens quick settings
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenQuickActions"),
                    object: nil
                )
            }
            Spacer()
        }
    }
    
    private var backgroundTrack: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.clear)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(colorScheme == .dark ? 0.35 : 0.55)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.12),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    private var volumeFill: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: volumeMonitor.isMuted ? [
                        Color.gray.opacity(0.5),
                        Color.gray.opacity(0.35)
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
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.25),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
            )
            // Enhanced visibility stroke - visible on any background
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: isVertical ? -1 : 0)
    }
    
    private var adaptiveGradientColors: [Color] {
        // Check for custom color mode from setupState
        if let colorMode = setupState?.volumeBarColorMode {
            switch colorMode {
            case .white:
                return [
                    Color.white.opacity(0.95),
                    Color.white.opacity(0.80)
                ]
            case .black:
                return [
                    Color.black.opacity(0.9),
                    Color.black.opacity(0.75)
                ]
            case .accent:
                return [
                    Color.accentColor.opacity(0.95),
                    Color.accentColor.opacity(0.80)
                ]
            case .custom:
                if let customColor = setupState?.customBarColor {
                    return [
                        customColor.opacity(0.95),
                        customColor.opacity(0.80)
                    ]
                }
                fallthrough
            case .system:
                // Fall through to default adaptive behavior
                break
            }
        }

        // Default adaptive behavior based on color scheme
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
    
    private var muteOverlay: some View {
        Image(systemName: "speaker.slash.fill")
            .font(.system(size: 12 * barSize, weight: .semibold))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.8) : Color(white: 0.3))
    }
    
    private func calculateFillLength() -> CGFloat {
        if volumeMonitor.isMuted || volumeMonitor.currentVolume <= 0 {
            return cornerRadius * 2
        }
        return max(cornerRadius * 2, barLength * CGFloat(volumeMonitor.currentVolume))
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
                // For vertical bar: top = 100%, bottom = 0%
                let newVolume = Float(max(0, min(1, 1 - (dragY / barLength))))
                let volumePercent = Int(round(newVolume * 100))
                
                if volumePercent % 50 == 0 { triggerHapticFeedback() }
                volumeMonitor.setSystemVolume(newVolume)
                
                // If dragged to 0, also mute the system (like the mute button does)
                if volumePercent == 0 && !volumeMonitor.isMuted {
                    print("🔇 Dragged to 0%, auto-muting audio")
                    volumeMonitor.toggleMute()
                }
                // If dragged above 0 and currently muted, unmute
                else if volumePercent > 0 && volumeMonitor.isMuted {
                    print("🔊 Dragged above 0%, auto-unmuting audio")
                    volumeMonitor.toggleMute()
                }
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
                // For horizontal bar: left = 0%, right = 100%
                let newVolume = Float(max(0, min(1, dragX / barLength)))
                let volumePercent = Int(round(newVolume * 100))
                
                if volumePercent % 50 == 0 { triggerHapticFeedback() }
                volumeMonitor.setSystemVolume(newVolume)
                
                // If dragged to 0, also mute the system (like the mute button does)
                if volumePercent == 0 && !volumeMonitor.isMuted {
                    print("🔇 Dragged to 0%, auto-muting audio")
                    volumeMonitor.toggleMute()
                }
                // If dragged above 0 and currently muted, unmute
                else if volumePercent > 0 && volumeMonitor.isMuted {
                    print("🔊 Dragged above 0%, auto-unmuting audio")
                    volumeMonitor.toggleMute()
                }
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
