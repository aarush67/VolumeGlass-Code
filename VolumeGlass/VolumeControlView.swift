import SwiftUI

struct VolumeControlView: View {
    @ObservedObject var volumeMonitor: VolumeMonitor
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @State private var showDeviceMenu = false
    @State private var showQuickActions = false
    @State private var isLoadingDevices = false
    @State private var idleDismissTimer: Timer? = nil
    @State private var airPlayPickerIsOpen = false
    private let idleDismissInterval: TimeInterval = 8
    @Environment(\.colorScheme) var colorScheme
    
    private var isVertical: Bool {
        volumeMonitor.setupState?.selectedPosition.isVertical ?? true
    }
    
    var body: some View {
        Group {
            if isVertical {
                verticalLayout
            } else {
                horizontalLayout
            }
        }
        .background(.clear)
        .onChange(of: showQuickActions) { _ in updateMouseEnabled() }
        .onChange(of: showDeviceMenu) { _ in updateMouseEnabled() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SettingsChanged"))) { _ in
            // When settings change, ensure visibility is properly updated
            print("📡 SettingsChanged received in VolumeControlView, resetting menus")
            showQuickActions = false
            showDeviceMenu = false
            updateMouseEnabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: .airPlayPickerOpened)) { _ in
            // Pause auto-dismiss while the AirPlay picker is showing
            airPlayPickerIsOpen = true
            cancelIdleDismissTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .airPlayPickerClosed)) { _ in
            // Resume auto-dismiss a moment after the picker closes
            airPlayPickerIsOpen = false
            startIdleDismissTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenQuickActions"))) { _ in
            // Open quick actions when tapping on the volume bar
            if !showQuickActions && !showDeviceMenu {
                if isVertical {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        showQuickActions = true
                    }
                } else {
                    showQuickActions = true
                }
                NotificationCenter.default.post(
                    name: NSNotification.Name("QuickActionsStateChanged"),
                    object: nil,
                    userInfo: ["isOpen": true]
                )
                triggerHapticFeedback()
                updateMouseEnabled()
                startIdleDismissTimer()
            }
        }
    }
    
    private var verticalLayout: some View {
        let menuOnLeft = volumeMonitor.setupState?.selectedPosition == .rightVertical

        if menuOnLeft {
            let barStack = VStack {
                Spacer()
                HStack(spacing: 10) {
                    if volumeMonitor.isVolumeChanging || showQuickActions || showDeviceMenu {
                        quickActionsToggleButton
                            .transition(.scale.combined(with: .opacity))
                    }

                    VolumeIndicatorView(volumeMonitor: volumeMonitor)
                        .frame(width: 60, height: 280)
                        .onLongPressGesture(minimumDuration: 0.8) {
                            showDeviceMenuWithHaptic()
                        }
                        .onTapGesture(count: 2) {
                            volumeMonitor.toggleMute()
                            triggerHapticFeedback()
                        }
                }
                Spacer()
            }

            return AnyView(
                ZStack(alignment: .trailing) {
                    barStack

                    if showQuickActions && !showDeviceMenu {
                        quickActionsMenu
                            .offset(x: -170)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }

                    if showDeviceMenu {
                        DeviceSelectionMenu(
                            audioDeviceManager: audioDeviceManager,
                            isLoading: isLoadingDevices,
                            onDeviceSelected: { device in
                                audioDeviceManager.setOutputDevice(device)
                                hideDeviceMenu()
                            },
                            onDismiss: {
                                hideDeviceMenu()
                            }
                        )
                        .offset(x: -245)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            )
        }

        return AnyView(HStack(spacing: 12) {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    VolumeIndicatorView(volumeMonitor: volumeMonitor)
                        .frame(width: 60, height: 280)
                        .onLongPressGesture(minimumDuration: 0.8) {
                            showDeviceMenuWithHaptic()
                        }
                        .onTapGesture(count: 2) {
                            volumeMonitor.toggleMute()
                            triggerHapticFeedback()
                        }
                    
                    if volumeMonitor.isVolumeChanging || showQuickActions || showDeviceMenu {
                        quickActionsToggleButton
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Spacer()
            }

            if showQuickActions && !showDeviceMenu {
                quickActionsMenu
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }

            if showDeviceMenu {
                DeviceSelectionMenu(
                    audioDeviceManager: audioDeviceManager,
                    isLoading: isLoadingDevices,
                    onDeviceSelected: { device in
                        audioDeviceManager.setOutputDevice(device)
                        hideDeviceMenu()
                    },
                    onDismiss: {
                        hideDeviceMenu()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        })
    }
    
    private var horizontalLayout: some View {
        let menuAboveBar = volumeMonitor.setupState?.selectedPosition == .bottomHorizontal
        let contentStack = VStack(spacing: 12) {
            if menuAboveBar {
                if showQuickActions && !showDeviceMenu {
                    quickActionsMenu
                        .transition(horizontalMenuTransition)
                }

                if showDeviceMenu {
                    DeviceSelectionMenu(
                        audioDeviceManager: audioDeviceManager,
                        isLoading: isLoadingDevices,
                        onDeviceSelected: { device in
                            audioDeviceManager.setOutputDevice(device)
                            hideDeviceMenu()
                        },
                        onDismiss: {
                            hideDeviceMenu()
                        }
                    )
                    .transition(horizontalMenuTransition)
                }
            }

            HStack {
                Spacer()
                VStack(spacing: 10) {
                    VolumeIndicatorView(volumeMonitor: volumeMonitor)
                        .frame(width: 300, height: 60)
                        .onLongPressGesture(minimumDuration: 0.8) {
                            showDeviceMenuWithHaptic()
                        }
                        .onTapGesture(count: 2) {
                            volumeMonitor.toggleMute()
                            triggerHapticFeedback()
                        }

                    if volumeMonitor.isVolumeChanging || showQuickActions || showDeviceMenu {
                        quickActionsToggleButton
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Spacer()
            }

            if !menuAboveBar {
                if showQuickActions && !showDeviceMenu {
                    quickActionsMenu
                        .transition(horizontalMenuTransition)
                }

                if showDeviceMenu {
                    DeviceSelectionMenu(
                        audioDeviceManager: audioDeviceManager,
                        isLoading: isLoadingDevices,
                        onDeviceSelected: { device in
                            audioDeviceManager.setOutputDevice(device)
                            hideDeviceMenu()
                        },
                        onDismiss: {
                            hideDeviceMenu()
                        }
                    )
                    .transition(horizontalMenuTransition)
                }
            }
        }
        .padding(.bottom, menuAboveBar ? 22 : 0)

        return VStack(spacing: 0) {
            if menuAboveBar {
                Spacer(minLength: 0)
                contentStack
            } else {
                contentStack
                Spacer(minLength: 0)
            }
        }
    }

    private var horizontalMenuTransition: AnyTransition {
        // Avoid positional transitions in horizontal mode to prevent AppKit exceptions.
        .opacity
    }
    
    private var quickActionsToggleButton: some View {
        Button(action: {
            if isVertical {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    showQuickActions.toggle()
                }
            } else {
                showQuickActions.toggle()
            }

            NotificationCenter.default.post(
                name: NSNotification.Name("QuickActionsStateChanged"),
                object: nil,
                userInfo: ["isOpen": showQuickActions]
            )

            triggerHapticFeedback()
            updateMouseEnabled()
            if showQuickActions {
                startIdleDismissTimer()
            } else {
                cancelIdleDismissTimer()
            }
        }) {
            Image(systemName: showQuickActions ? "xmark" : "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.primary.opacity(0.7))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var quickActionsMenu: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                // Volume readout
                HStack(spacing: 10) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(volumeMonitor.isMuted ? Color.secondary : Color.primary)
                        .frame(width: 24)
                    
                    Text("\(Int(volumeMonitor.currentVolume * 100))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primary)
                        .contentTransition(.numericText())
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
                
                // Divider
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
                
                // Actions
                VStack(spacing: 4) {
                    QuickActionButton(
                        icon: volumeMonitor.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        label: volumeMonitor.isMuted ? "Unmute" : "Mute",
                        isActive: volumeMonitor.isMuted
                    ) {
                        volumeMonitor.toggleMute()
                        triggerHapticFeedback()
                    }
                    
                    QuickActionButton(
                        icon: "hifispeaker.2.fill",
                        label: "Audio Output",
                        showChevron: true
                    ) {
                        showDeviceMenuWithHaptic()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                
                // Divider
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                
                // Quick presets
                VStack(spacing: 8) {
                    Text("Quick Set")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    
                    HStack(spacing: 5) {
                        PresetButton(value: 25, currentVolume: volumeMonitor.currentVolume) {
                            volumeMonitor.setSystemVolume(0.25); triggerHapticFeedback()
                        }
                        PresetButton(value: 50, currentVolume: volumeMonitor.currentVolume) {
                            volumeMonitor.setSystemVolume(0.5); triggerHapticFeedback()
                        }
                        PresetButton(value: 75, currentVolume: volumeMonitor.currentVolume) {
                            volumeMonitor.setSystemVolume(0.75); triggerHapticFeedback()
                        }
                        PresetButton(value: 100, currentVolume: volumeMonitor.currentVolume) {
                            volumeMonitor.setSystemVolume(1.0); triggerHapticFeedback()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 14)
            }
            .frame(width: 180)
            .contentShape(Rectangle())  // Ensure all clicks are captured
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            .onTapGesture {
                // Capture taps on the menu background to prevent click-through
            }
            Spacer()
        }
    }
    
    private var volumeIcon: String {
        if volumeMonitor.isMuted { return "speaker.slash.fill" }
        else if volumeMonitor.currentVolume > 0.66 { return "speaker.wave.3.fill" }
        else if volumeMonitor.currentVolume > 0.33 { return "speaker.wave.2.fill" }
        else if volumeMonitor.currentVolume > 0 { return "speaker.wave.1.fill" }
        else { return "speaker.fill" }
    }
    
    private func startIdleDismissTimer() {
        idleDismissTimer?.invalidate()
        idleDismissTimer = Timer.scheduledTimer(withTimeInterval: idleDismissInterval, repeats: false) { _ in
            DispatchQueue.main.async {
                // Don't dismiss while the AirPlay picker is open — user may be scrolling through it
                guard !airPlayPickerIsOpen else { return }
                if isVertical {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showQuickActions = false
                        showDeviceMenu = false
                    }
                } else {
                    showQuickActions = false
                    showDeviceMenu = false
                }
                NotificationCenter.default.post(name: NSNotification.Name("QuickActionsStateChanged"), object: nil, userInfo: ["isOpen": false])
                NotificationCenter.default.post(name: NSNotification.Name("DeviceMenuStateChanged"), object: nil, userInfo: ["isOpen": false])
                updateMouseEnabled()
            }
        }
    }

    private func cancelIdleDismissTimer() {
        idleDismissTimer?.invalidate()
        idleDismissTimer = nil
    }

    private func showDeviceMenuWithHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        isLoadingDevices = true

        // Show the menu immediately with loading state
        if isVertical {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showQuickActions = false
                showDeviceMenu = true
            }
        } else {
            showQuickActions = false
            showDeviceMenu = true
        }
        NotificationCenter.default.post(name: NSNotification.Name("QuickActionsStateChanged"), object: nil, userInfo: ["isOpen": false])
        NotificationCenter.default.post(name: NSNotification.Name("DeviceMenuStateChanged"), object: nil, userInfo: ["isOpen": true])
        updateMouseEnabled()
        startIdleDismissTimer()

        // Load devices asynchronously
        Task {
            await audioDeviceManager.loadDevicesAsync()
            await MainActor.run {
                isLoadingDevices = false
            }
        }
    }

    private func hideDeviceMenu() {
        cancelIdleDismissTimer()
        if isVertical {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showDeviceMenu = false
            }
        } else {
            showDeviceMenu = false
        }
        NotificationCenter.default.post(name: NSNotification.Name("DeviceMenuStateChanged"), object: nil, userInfo: ["isOpen": false])
        updateMouseEnabled()
    }
    
    private func updateMouseEnabled() {
        let shouldEnable = showQuickActions || showDeviceMenu || volumeMonitor.isVolumeChanging
        NotificationCenter.default.post(name: NSNotification.Name("VolumeBarVisibilityChanged"), object: nil, userInfo: ["isVisible": shouldEnable])
    }
    
    private func triggerHapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    var showChevron: Bool = false
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isActive ? Color.accentColor : Color.primary.opacity(0.85))
                    .frame(width: 20)
                
                Text(label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.primary.opacity(0.85))
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

struct PresetButton: View {
    let value: Int
    let currentVolume: Float
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    private var isCurrentValue: Bool {
        abs(Int(currentVolume * 100) - value) < 3
    }
    
    var body: some View {
        Button(action: action) {
            Text("\(value)%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(isCurrentValue ? Color.accentColor : Color.primary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isCurrentValue
                            ? Color.accentColor.opacity(0.15)
                            : (isHovered ? Color.primary.opacity(0.1) : Color.primary.opacity(0.06))
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}