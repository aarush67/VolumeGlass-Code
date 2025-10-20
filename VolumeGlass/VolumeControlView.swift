import SwiftUI

struct VolumeControlView: View {
    @ObservedObject var volumeMonitor: VolumeMonitor
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @State private var showDeviceMenu = false
    @State private var showQuickActions = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.clear)
        .onChange(of: showQuickActions) { _ in updateMouseEnabled() }
        .onChange(of: showDeviceMenu) { _ in updateMouseEnabled() }
    }
    
    private var quickActionsToggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                showQuickActions.toggle()
            }
            triggerHapticFeedback()
            updateMouseEnabled()
        }) {
            Image(systemName: showQuickActions ? "xmark.circle.fill" : "ellipsis.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Color.primary.opacity(0.8))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var quickActionsMenu: some View {
        VStack(spacing: 10) {
            Spacer()
            
            VStack(spacing: 10) {
                VStack(spacing: 4) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color.primary.opacity(0.9))
                    
                    Text("\(Int(volumeMonitor.currentVolume * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primary)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
                
                QuickActionButton(
                    icon: volumeMonitor.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    label: volumeMonitor.isMuted ? "Unmute" : "Mute",
                    isDestructive: volumeMonitor.isMuted
                ) {
                    volumeMonitor.toggleMute()
                    triggerHapticFeedback()
                }
                
                QuickActionButton(
                    icon: "hifispeaker.2.fill",
                    label: "Audio Output"
                ) {
                    showDeviceMenuWithHaptic()
                }
                
                Divider()
                    .background(Color.primary.opacity(0.15))
                    .padding(.vertical, 4)
                
                VStack(spacing: 8) {
                    Text("Quick Volume")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.primary.opacity(0.5))
                        .textCase(.uppercase)
                    
                    HStack(spacing: 6) {
                        PresetButton(value: 25) {
                            volumeMonitor.setSystemVolume(0.25)
                            triggerHapticFeedback()
                        }
                        
                        PresetButton(value: 50) {
                            volumeMonitor.setSystemVolume(0.5)
                            triggerHapticFeedback()
                        }
                        
                        PresetButton(value: 75) {
                            volumeMonitor.setSystemVolume(0.75)
                            triggerHapticFeedback()
                        }
                        
                        PresetButton(value: 100) {
                            volumeMonitor.setSystemVolume(1.0)
                            triggerHapticFeedback()
                        }
                    }
                }
            }
            .padding(14)
            .frame(width: 140)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(0.2),
                                Color.primary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            
            Spacer()
        }
    }
    
    private var volumeIcon: String {
        if volumeMonitor.isMuted {
            return "speaker.slash.fill"
        } else if volumeMonitor.currentVolume > 0.66 {
            return "speaker.wave.3.fill"
        } else if volumeMonitor.currentVolume > 0.33 {
            return "speaker.wave.2.fill"
        } else if volumeMonitor.currentVolume > 0 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.fill"
        }
    }
    
    private func showDeviceMenuWithHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        audioDeviceManager.loadDevices()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showQuickActions = false
            showDeviceMenu = true
        }
        
        // Notify that device menu is now open - keeps volume bar visible
        NotificationCenter.default.post(
            name: NSNotification.Name("DeviceMenuStateChanged"),
            object: nil,
            userInfo: ["isOpen": true]
        )
        updateMouseEnabled()
    }
    
    private func hideDeviceMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showDeviceMenu = false
        }
        
        // Notify that device menu is now closed
        NotificationCenter.default.post(
            name: NSNotification.Name("DeviceMenuStateChanged"),
            object: nil,
            userInfo: ["isOpen": false]
        )
        updateMouseEnabled()
    }
    
    private func updateMouseEnabled() {
        let shouldEnable = showQuickActions || showDeviceMenu || volumeMonitor.isVolumeChanging
        NotificationCenter.default.post(
            name: NSNotification.Name("VolumeBarVisibilityChanged"),
            object: nil,
            userInfo: ["isVisible": shouldEnable]
        )
    }
    
    private func triggerHapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
            action()
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                Spacer()
            }
            .foregroundColor(isDestructive ? .red.opacity(0.95) : Color.primary.opacity(0.95))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isDestructive ? Color.red.opacity(0.2) : Color.primary.opacity(0.12))
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct PresetButton: View {
    let value: Int
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
            action()
        }) {
            Text("\(value)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color.primary.opacity(0.95))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.18))
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

