import SwiftUI

struct SetupWalkthroughView: View {
    @ObservedObject var setupState: SetupState
    @State private var currentStep = 0
    
    let steps = [
        "Welcome to VolumeGlass",
        "Choose Position",
        "Choose Size",
        "How to Use",
        "All Set!"
    ]
    
    var body: some View {
        ZStack {
            // Glass background
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Step indicator
                HStack {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }
                .padding(.top, 40)
                
                // Content for each step
                stepContent
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 40)
                
                Spacer()
                
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
                            print("🚀 Finish button clicked!")
                            print("📍 Selected position: \(setupState.selectedPosition.displayName)")
                            print("📏 Bar size: \(setupState.barSize)")
                            withAnimation(.smooth) {
                                setupState.completeSetup()
                            }
                        } else {
                            withAnimation(.smooth) {
                                currentStep += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .frame(width: 600, height: 500)
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            welcomeStep
        case 1:
            positionStep
        case 2:
            sizeStep
        case 3:
            howToUseStep
        case 4:
            finishStep
        default:
            EmptyView()
        }
    }
    
    // MARK: - Step Views
    
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            Text("Welcome to VolumeGlass")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("A beautiful, iOS-style volume control for your Mac")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
    
    private var positionStep: some View {
        VStack(spacing: 20) {
            Text("Choose Position")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text("Where would you like the volume bar to appear?")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                ForEach(VolumeBarPosition.allCases, id: \.self) { position in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            setupState.selectedPosition = position
                        }
                    }) {
                        HStack {
                            Image(systemName: position.isVertical ? "rectangle.portrait" : "rectangle")
                                .font(.system(size: 16))
                            Text(position.displayName)
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            if setupState.selectedPosition == position {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(setupState.selectedPosition == position ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var sizeStep: some View {
        VStack(spacing: 20) {
            Text("Choose Size")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text("Adjust the volume bar size to your preference")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            VStack(spacing: 15) {
                Text("Size: \(String(format: "%.0f%%", setupState.barSize * 100))")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Slider(value: $setupState.barSize, in: 0.7...1.3, step: 0.1)
                    .tint(.white)
                    .padding(.horizontal, 30)
            }
            .padding(.vertical, 20)
        }
    }
    
    private var howToUseStep: some View {
        VStack(spacing: 24) {
            Text("How to Use")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text("Master VolumeGlass with these gestures")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "hand.point.up",
                    title: "Hover to Show",
                    description: "Move your cursor near the bar area to make it appear"
                )
                
                FeatureRow(
                    icon: "hand.draw",
                    title: "Drag to Adjust",
                    description: "Click and drag the bar to change volume"
                )
                
                FeatureRow(
                    icon: "ellipsis.circle",
                    title: "Quick Actions",
                    description: "Click the ••• button for mute, presets, and audio output"
                )
                
                FeatureRow(
                    icon: "hand.tap",
                    title: "Double-Tap to Mute",
                    description: "Quickly mute/unmute by double-tapping the bar"
                )
                
                FeatureRow(
                    icon: "hand.point.down",
                    title: "Long Press for Devices",
                    description: "Hold for 0.8s to switch audio output devices"
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var finishStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("All Set!")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("VolumeGlass is ready to use.\nChange your volume to see it in action!")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

