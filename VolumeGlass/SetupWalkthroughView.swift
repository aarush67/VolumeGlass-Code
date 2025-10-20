import SwiftUI

struct SetupWalkthroughView: View {
    @ObservedObject var setupState: SetupState
    @State private var currentStep = 0
    @Environment(\.colorScheme) var colorScheme
    
    let steps = [
        "Welcome to VolumeGlass",
        "Choose Position",
        "Choose Size",
        "Audio Device Selection",
        "All Set!"
    ]
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Step indicator
                HStack {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? Color.accentColor : Color.primary.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
                
                // Current step content
                Group {
                    switch currentStep {
                    case 0: WelcomeStepView()
                    case 1: PositionSelectionStepView(setupState: setupState)
                    case 2: SizeStepView(setupState: setupState)
                    case 3: AudioDeviceStepView(setupState: setupState)
                    case 4: CompletionStepView(setupState: setupState)
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation(.smooth) {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Spacer()
                    
                    Button(currentStep == steps.count - 1 ? "Finish" : "Next") {
                        if currentStep == steps.count - 1 {
                            setupState.completeSetup()
                        } else {
                            withAnimation(.smooth) {
                                currentStep += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom)
            }
            .padding(40)
        }
        .frame(width: 800, height: 700)
    }
}

struct WelcomeStepView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "speaker.wave.3")
                .font(.system(size: 80))
                .foregroundStyle(Color.primary.opacity(0.9))
            
            Text("Welcome to VolumeGlass")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color.primary)
            
            Text("An iOS-style volume indicator for your Mac with liquid glass design")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(Color.primary.opacity(0.8))
        }
    }
}

struct PositionSelectionStepView: View {
    @ObservedObject var setupState: SetupState
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Choose Volume Bar Position")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(Color.primary)
            
            Text("Select where you want the volume bar to appear")
                .foregroundColor(Color.primary.opacity(0.8))
            
            VStack(spacing: 15) {
                ForEach(VolumeBarPosition.allCases, id: \.self) { position in
                    Button(action: {
                        setupState.selectedPosition = position
                    }) {
                        HStack {
                            Image(systemName: iconForPosition(position))
                                .frame(width: 20)
                            Text(position.displayName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if setupState.selectedPosition == position {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            setupState.selectedPosition == position ?
                                Color.primary.opacity(0.2) : Color.primary.opacity(0.1)
                        )
                        .cornerRadius(10)
                        .foregroundColor(Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 400)
            
            PresetPositionPreview(
                position: setupState.selectedPosition,
                size: setupState.barSize
            )
        }
    }
    
    private func iconForPosition(_ position: VolumeBarPosition) -> String {
        switch position {
        case .leftMiddleVertical: return "sidebar.left"
        case .bottomVertical: return "rectangle.portrait.bottomhalf.filled"
        case .rightVertical: return "sidebar.right"
        case .topHorizontal: return "rectangle.topthird.inset.filled"
        case .bottomHorizontal: return "rectangle.bottomthird.inset.filled"
        }
    }
}

struct SizeStepView: View {
    @ObservedObject var setupState: SetupState
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Customize Size")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(Color.primary)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Size: \(Int(setupState.barSize * 100))%")
                    .font(.headline)
                    .foregroundColor(Color.primary)
                
                Slider(value: $setupState.barSize, in: 0.5...2.0)
                    .accentColor(.accentColor)
            }
            .frame(maxWidth: 300)
            
            PresetPositionPreview(
                position: setupState.selectedPosition,
                size: setupState.barSize
            )
        }
    }
}

struct AudioDeviceStepView: View {
    @ObservedObject var setupState: SetupState
    @StateObject private var audioManager = AudioDeviceManager()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Audio Device Selection")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(Color.primary)
            
            Text("Click and hold the volume bar to see available audio devices")
                .foregroundColor(Color.primary.opacity(0.8))
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(audioManager.outputDevices, id: \.deviceID) { device in
                        AudioDeviceRow(
                            device: device,
                            isSelected: device.deviceID == audioManager.currentOutputDevice?.deviceID
                        )
                        .onTapGesture {
                            audioManager.setOutputDevice(device)
                        }
                    }
                }
            }
            .frame(height: 200)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .onAppear {
            audioManager.loadDevices()
        }
    }
}

struct CompletionStepView: View {
    @ObservedObject var setupState: SetupState
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("✓ Position: \(setupState.selectedPosition.displayName)")
                Text("✓ Size: \(Int(setupState.barSize * 100))%")
                Text("✓ Audio device selection enabled")
            }
            .font(.title3)
            .foregroundColor(Color.primary.opacity(0.8))
            
            Text("The volume bar will appear when you adjust system volume")
                .font(.caption)
                .foregroundColor(Color.primary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
}

struct PresetPositionPreview: View {
    let position: VolumeBarPosition
    let size: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                .frame(width: 400, height: 250)
            
            VolumeBarPreview(
                size: size,
                isVertical: position.isVertical,
                volume: 0.6
            )
            .position(previewPositionForPosition(position))
        }
        .frame(width: 400, height: 250)
    }
    
    private func previewPositionForPosition(_ position: VolumeBarPosition) -> CGPoint {
        switch position {
        case .leftMiddleVertical:
            return CGPoint(x: 40, y: 125)
        case .bottomVertical:
            return CGPoint(x: 200, y: 210)
        case .rightVertical:
            return CGPoint(x: 360, y: 125)
        case .topHorizontal:
            return CGPoint(x: 200, y: 40)
        case .bottomHorizontal:
            return CGPoint(x: 200, y: 210)
        }
    }
}

struct VolumeBarPreview: View {
    let size: CGFloat
    let isVertical: Bool
    let volume: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    var barWidth: CGFloat { 10 * size }
    var barHeight: CGFloat { 60 * size }
    
    var barColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.2, green: 0.25, blue: 0.3)
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 6 * size, style: .continuous)
            .fill(Color.primary.opacity(0.3))
            .frame(
                width: isVertical ? barWidth : barHeight,
                height: isVertical ? barHeight : barWidth
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6 * size, style: .continuous)
                    .fill(barColor)
                    .frame(
                        width: isVertical ? barWidth : barHeight * volume,
                        height: isVertical ? barHeight * volume : barWidth
                    ),
                alignment: isVertical ? .bottom : .leading
            )
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

