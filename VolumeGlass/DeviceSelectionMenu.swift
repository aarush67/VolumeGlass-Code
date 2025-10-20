import SwiftUI

struct DeviceSelectionMenu: View {
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    let onDeviceSelected: (AudioDevice) -> Void
    let onDismiss: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "speaker.wave.3")
                    .foregroundColor(Color.primary.opacity(0.8))
                
                Text("Audio Output")
                    .font(.headline)
                    .foregroundColor(Color.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.primary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            
            Divider()
                .background(Color.primary.opacity(0.2))
            
            // Device list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(audioDeviceManager.outputDevices, id: \.deviceID) { device in
                        DeviceMenuItem(
                            device: device,
                            isSelected: device.deviceID == audioDeviceManager.currentOutputDevice?.deviceID,
                            onSelected: {
                                onDeviceSelected(device)
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .frame(width: 280)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

struct DeviceMenuItem: View {
    let device: AudioDevice
    let isSelected: Bool
    let onSelected: () -> Void
    
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onSelected) {
            HStack(spacing: 12) {
                Image(systemName: deviceIcon)
                    .frame(width: 20)
                    .foregroundColor(iconColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.primary)
                        .lineLimit(1)
                    
                    if !device.manufacturer.isEmpty && device.manufacturer != "Unknown" {
                        Text(device.manufacturer)
                            .font(.system(size: 12))
                            .foregroundColor(Color.primary.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Rectangle()
                    .fill(backgroundColor)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.primary.opacity(0.15)
        } else if isHovered {
            return Color.primary.opacity(0.08)
        } else {
            return .clear
        }
    }
    
    private var iconColor: Color {
        if isSelected {
            return Color.primary
        } else {
            return Color.primary.opacity(0.7)
        }
    }
    
    private var deviceIcon: String {
        let deviceName = device.name.lowercased()
        if deviceName.contains("bluetooth") || deviceName.contains("airpods") {
            return "airpods"
        } else if deviceName.contains("built-in") || deviceName.contains("internal") {
            return "speaker.2"
        } else if deviceName.contains("usb") {
            return "cable.connector"
        } else if deviceName.contains("thunderbolt") || deviceName.contains("displayport") {
            return "tv"
        } else if deviceName.contains("headphone") {
            return "headphones"
        } else {
            return "speaker.3"
        }
    }
}

