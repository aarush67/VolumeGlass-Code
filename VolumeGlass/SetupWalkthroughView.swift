import SwiftUI
import ApplicationServices

struct SetupWalkthroughView: View {
    @ObservedObject var setupState: SetupState
    @State private var currentStep = 0
    @State private var animateIn = false
    @Environment(\.colorScheme) var colorScheme
    
    let steps = [
        "Welcome",
        "Permissions",
        "Position",
        "Size",
        "Shortcuts",
        "Audio",
        "Done"
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: colorScheme == .dark 
                    ? [Color(white: 0.08), Color(white: 0.12)]
                    : [Color(white: 0.96), Color(white: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentStep 
                                ? Color.accentColor 
                                : Color.primary.opacity(0.1))
                            .frame(width: index == currentStep ? 28 : 6, height: 6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                    }
                }
                .padding(.top, 36)
                .padding(.bottom, 24)
                
                // Step label
                Text(steps[currentStep])
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .padding(.bottom, 10)
                
                // Content area
                Group {
                    switch currentStep {
                    case 0: WelcomeStepView()
                    case 1: AccessibilityPermissionStepView()
                    case 2: PositionSelectionStepView(setupState: setupState)
                    case 3: SizeStepView(setupState: setupState)
                    case 4: KeyboardShortcutsStepView()
                    case 5: AudioDeviceStepView(setupState: setupState)
                    case 6: CompletionStepView(setupState: setupState)
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                animateIn = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                currentStep -= 1
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    animateIn = true
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if currentStep == steps.count - 1 {
                            setupState.completeSetup()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                animateIn = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                currentStep += 1
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    animateIn = true
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text(currentStep == steps.count - 1 ? "Get Started" : "Continue")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: currentStep == steps.count - 1 ? "checkmark" : "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.accentColor)
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 36)
            }
        }
        .frame(minWidth: 800, minHeight: 720)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                animateIn = true
            }
        }
    }
}

struct WelcomeStepView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App icon with animation
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.accentColor.opacity(0.2),
                                Color.accentColor.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    iconScale = 1.0
                    iconOpacity = 1.0
                }
            }
            
            VStack(spacing: 12) {
                Text("VolumeGlass")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("A beautiful volume indicator for your Mac")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Feature highlights
            VStack(spacing: 16) {
                FeatureRow(icon: "wand.and.stars", title: "Liquid Glass Design", description: "Sleek, modern appearance")
                FeatureRow(icon: "hand.draw", title: "Drag to Adjust", description: "Interactive volume control")
                FeatureRow(icon: "keyboard", title: "Keyboard Shortcuts", description: "Quick volume adjustments")
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .padding(.horizontal, 60)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

struct AccessibilityPermissionStepView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isAccessibilityGranted: Bool = false
    @State private var isChecking = false
    @State private var permissionTimer: Timer?
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon with status indicator
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isAccessibilityGranted ? Color.green : Color.orange).opacity(0.2),
                                (isAccessibilityGranted ? Color.green : Color.orange).opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulseAnimation && !isAccessibilityGranted ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                
                Image(systemName: isAccessibilityGranted ? "checkmark.shield.fill" : "hand.raised.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isAccessibilityGranted
                                ? [Color.green, Color.green.opacity(0.7)]
                                : [Color.orange, Color.orange.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .onAppear {
                pulseAnimation = true
            }
            
            VStack(spacing: 12) {
                Text(isAccessibilityGranted ? "Permission Granted!" : "Accessibility Permission")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(isAccessibilityGranted
                    ? "VolumeGlass can now intercept volume keys and hide the system HUD."
                    : "VolumeGlass needs accessibility access to intercept volume keys and hide the default macOS volume popup.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 450)
            }
            
            if !isAccessibilityGranted {
                // Why we need permission
                VStack(alignment: .leading, spacing: 12) {
                    PermissionReasonRow(
                        icon: "speaker.wave.3.fill",
                        title: "Intercept Volume Keys",
                        description: "Capture F11/F12 and media key presses"
                    )
                    PermissionReasonRow(
                        icon: "eye.slash.fill",
                        title: "Hide System HUD",
                        description: "Replace Apple's volume popup with VolumeGlass"
                    )
                    PermissionReasonRow(
                        icon: "hand.tap.fill",
                        title: "Global Shortcuts",
                        description: "Enable keyboard shortcuts from any app"
                    )
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .frame(maxWidth: 420)
                
                // Grant permission button
                Button(action: requestPermission) {
                    HStack(spacing: 10) {
                        if isChecking {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Image(systemName: "gear")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Open System Settings")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                
                // Instructions
                VStack(spacing: 8) {
                    Text("After clicking, toggle VolumeGlass ON in the list")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                        Text("This page will update automatically when granted")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.top, 4)
                
            } else {
                // Success state
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("You're all set! Click Continue to proceed.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .onAppear {
            checkPermission()
            startPermissionMonitoring()
        }
        .onDisappear {
            stopPermissionMonitoring()
        }
    }
    
    private func checkPermission() {
        isAccessibilityGranted = PermissionManager.shared.isAccessibilityGranted
    }
    
    private func requestPermission() {
        isChecking = true
        
        // Request permission (this opens System Settings)
        PermissionManager.shared.requestAccessibilityPermission(prompt: true)
        
        // Also try to open the specific pane
        PermissionManager.shared.openAccessibilitySettings()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isChecking = false
            checkPermission()
        }
    }
    
    private func startPermissionMonitoring() {
        // Check every second for permission grant
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let granted = PermissionManager.shared.isAccessibilityGranted
            if granted != isAccessibilityGranted {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isAccessibilityGranted = granted
                }
            }
        }
    }
    
    private func stopPermissionMonitoring() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }
}

struct PermissionReasonRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct PositionSelectionStepView: View {
    @ObservedObject var setupState: SetupState
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Where should it appear?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Choose where the volume bar shows up on your screen")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                // Position options
                VStack(spacing: 10) {
                    ForEach(VolumeBarPosition.allCases, id: \.self) { position in
                        PositionOptionButton(
                            position: position,
                            isSelected: setupState.selectedPosition == position
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                setupState.selectedPosition = position
                            }
                        }
                    }
                }
                .frame(maxWidth: 260)
                
                // Preview
                PresetPositionPreview(
                    position: setupState.selectedPosition,
                    size: setupState.barSize
                )
                .frame(width: 320, height: 200)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 40)
    }
}

struct PositionOptionButton: View {
    let position: VolumeBarPosition
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    private var iconName: String {
        switch position {
        case .leftMiddleVertical: return "sidebar.left"
        case .bottomVertical: return "rectangle.portrait.bottomhalf.filled"
        case .rightVertical: return "sidebar.right"
        case .topHorizontal: return "rectangle.topthird.inset.filled"
        case .bottomHorizontal: return "rectangle.bottomthird.inset.filled"
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                    )
                
                Text(position.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct SizeStepView: View {
    @ObservedObject var setupState: SetupState
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            Text("How big should it be?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Adjust the size to match your preference")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            VStack(spacing: 20) {
                // Size display
                HStack {
                    Text("Size")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(setupState.barSize * 100))%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.accentColor)
                }
                
                // Slider
                HStack(spacing: 16) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    
                    Slider(value: $setupState.barSize, in: 0.5...2.0, step: 0.25)
                        .accentColor(.accentColor)
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                
                // Preset buttons
                HStack(spacing: 10) {
                    ForEach([0.5, 0.75, 1.0, 1.5, 2.0], id: \.self) { size in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                setupState.barSize = CGFloat(size)
                            }
                        }) {
                            Text("\(Int(size * 100))%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(abs(setupState.barSize - CGFloat(size)) < 0.01 ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(abs(setupState.barSize - CGFloat(size)) < 0.01 ? Color.accentColor : Color.primary.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .frame(maxWidth: 400)
            
            // Preview
            PresetPositionPreview(
                position: setupState.selectedPosition,
                size: setupState.barSize
            )
            .frame(width: 320, height: 200)
        }
        .padding(.horizontal, 40)
    }
}

struct KeyboardShortcutsStepView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.accentColor.opacity(0.15),
                                Color.accentColor.opacity(0.03),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Control with your keyboard")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Use these shortcuts to quickly adjust volume")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 2) {
                ShortcutRow(keys: ["⌘", "⇧", "↑"], action: "Volume Up")
                ShortcutRow(keys: ["⌘", "⇧", "↓"], action: "Volume Down")
                ShortcutRow(keys: ["⌘", "⇧", "M"], action: "Mute / Unmute")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 360)
            
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                Text("Hardware volume keys (F11/F12) also work!")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.secondary.opacity(0.7))
            .padding(.top, 4)
        }
        .padding(.horizontal, 40)
    }
}

struct ShortcutRow: View {
    let keys: [String]
    let action: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(colorScheme == .dark
                                    ? Color(white: 0.22)
                                    : Color.white)
                                .shadow(color: colorScheme == .dark
                                    ? Color.black.opacity(0.3)
                                    : Color.black.opacity(0.08),
                                    radius: 1, x: 0, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 0.5)
                        )
                }
            }
            
            Spacer()
            
            Text(action)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct AudioDeviceStepView: View {
    @ObservedObject var setupState: SetupState
    @StateObject private var audioManager = AudioDeviceManager()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hifispeaker.2.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.accentColor)
            
            Text("Switch audio devices")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Long-press the volume bar to quickly switch outputs")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Device list preview
            VStack(spacing: 8) {
                ForEach(audioManager.outputDevices.prefix(4), id: \.deviceID) { device in
                    DevicePreviewRow(
                        device: device,
                        isSelected: device.deviceID == audioManager.currentOutputDevice?.deviceID
                    )
                }
                
                if audioManager.outputDevices.isEmpty {
                    Text("Loading devices...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .frame(maxWidth: 360)
        }
        .padding(.horizontal, 40)
        .onAppear {
            audioManager.loadDevices()
        }
    }
}

struct DevicePreviewRow: View {
    let device: AudioDevice
    let isSelected: Bool
    
    private var iconName: String {
        let name = device.name.lowercased()
        if name.contains("airpods") || name.contains("headphones") || name.contains("bluetooth") {
            return "headphones"
        } else if name.contains("built-in") || name.contains("speakers") {
            return "speaker.wave.2.fill"
        } else if name.contains("hdmi") || name.contains("display") {
            return "tv"
        }
        return "speaker.fill"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                )
            
            Text(device.name)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
    }
}

struct CompletionStepView: View {
    @ObservedObject var setupState: SetupState
    @Environment(\.colorScheme) var colorScheme
    @State private var checkmarkScale: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success checkmark
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72, weight: .medium))
                    .foregroundColor(.green)
            }
            .scaleEffect(checkmarkScale)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                    checkmarkScale = 1.0
                }
            }
            
            VStack(spacing: 12) {
                Text("You're all set!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("VolumeGlass is ready to use")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
            }
            
            // Summary
            VStack(spacing: 12) {
                SummaryRow(icon: "mappin.circle.fill", label: "Position", value: setupState.selectedPosition.displayName)
                SummaryRow(icon: "arrow.up.left.and.arrow.down.right", label: "Size", value: "\(Int(setupState.barSize * 100))%")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .frame(maxWidth: 360)
            
            HStack(spacing: 8) {
                Image(systemName: "gear")
                    .font(.system(size: 13))
                Text("You can change settings anytime from the menu bar")
                    .font(.system(size: 13))
            }
            .foregroundColor(.secondary)
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 28)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct PresetPositionPreview: View {
    let position: VolumeBarPosition
    let size: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Screen representation
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
            
            // Menu bar
            VStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 8)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                Spacer()
            }
            
            // Volume bar preview
            VolumeBarMiniPreview(
                size: size,
                isVertical: position.isVertical,
                volume: 0.65
            )
            .position(previewPosition(for: position))
        }
    }
    
    private func previewPosition(for position: VolumeBarPosition) -> CGPoint {
        let containerWidth: CGFloat = 320
        let containerHeight: CGFloat = 200
        let padding: CGFloat = 24
        
        switch position {
        case .leftMiddleVertical:
            return CGPoint(x: padding, y: containerHeight / 2)
        case .bottomVertical:
            return CGPoint(x: containerWidth / 2, y: containerHeight - padding)
        case .rightVertical:
            return CGPoint(x: containerWidth - padding, y: containerHeight / 2)
        case .topHorizontal:
            return CGPoint(x: containerWidth / 2, y: padding + 10)
        case .bottomHorizontal:
            return CGPoint(x: containerWidth / 2, y: containerHeight - padding)
        }
    }
}

struct VolumeBarMiniPreview: View {
    let size: CGFloat
    let isVertical: Bool
    let volume: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    private var barWidth: CGFloat { isVertical ? 8 * size : 50 * size }
    private var barHeight: CGFloat { isVertical ? 50 * size : 8 * size }
    
    var body: some View {
        ZStack(alignment: isVertical ? .bottom : .leading) {
            // Track
            RoundedRectangle(cornerRadius: 4 * size, style: .continuous)
                .fill(Color.primary.opacity(0.15))
                .frame(width: barWidth, height: barHeight)
            
            // Fill
            RoundedRectangle(cornerRadius: 4 * size, style: .continuous)
                .fill(colorScheme == .dark ? Color.white : Color(white: 0.25))
                .frame(
                    width: isVertical ? barWidth : barWidth * volume,
                    height: isVertical ? barHeight * volume : barHeight
                )
        }
    }
}

struct AudioDeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: deviceIcon)
                .foregroundColor(Color.primary.opacity(0.7))
                .frame(width: 20)
            
            Text(device.name)
                .foregroundColor(Color.primary)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? Color.primary.opacity(0.1) : .clear)
        .cornerRadius(8)
    }
    
    private var deviceIcon: String {
        let deviceName = device.name.lowercased()
        if deviceName.contains("bluetooth") || deviceName.contains("airpods") {
            return "headphones"
        } else if deviceName.contains("built-in") || deviceName.contains("internal") {
            return "speaker.2"
        } else if deviceName.contains("usb") {
            return "cable.connector"
        } else if deviceName.contains("thunderbolt") || deviceName.contains("displayport") {
            return "tv"
        } else {
            return "speaker.3"
        }
    }
}