import SwiftUI
import AVKit

struct DeviceSelectionMenu: View {
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    var isLoading: Bool = false
    let onDeviceSelected: (AudioDevice) -> Void
    let onDismiss: () -> Void
    @State private var triggerRoutePicker = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "hifispeaker.2.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.secondary)
                
                Text("Output")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            // Divider
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 10)
            
            // Device list
            ScrollView {
                VStack(spacing: 2) {
                    if isLoading && audioDeviceManager.outputDevices.isEmpty {
                        // Only show loading if we have no devices yet
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading devices...")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else if audioDeviceManager.outputDevices.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "speaker.slash")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.secondary)
                            Text("No audio devices found")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(audioDeviceManager.outputDevices, id: \.id) { device in
                            DeviceMenuItem(
                                device: device,
                                isSelected: device.deviceID == audioDeviceManager.currentOutputDevice?.deviceID,
                                onSelected: {
                                    if device.isBonjourOnly {
                                        // Not yet a CoreAudio device — trigger the system
                                        // AirPlay picker so the user can select it there.
                                        triggerRoutePicker = true
                                    } else {
                                        onDeviceSelected(device)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
            }
            .frame(minHeight: 60, maxHeight: 220)
        }
        // Hidden AVRoutePickerView — triggered programmatically when a Bonjour-only
        // AirPlay device is tapped. Shows the same system AirPlay picker as Control Center.
        .background(
            AVRoutePickerRepresentable(triggerClick: $triggerRoutePicker)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        )
        .frame(width: 260)
        .fixedSize()
        .contentShape(Rectangle())  // Ensure all clicks are captured
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .onTapGesture {
            // Capture taps on the menu background to prevent click-through
        }
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
            HStack(spacing: 10) {
                Image(systemName: deviceIcon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 18)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name)
                        .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    if device.isBonjourOnly {
                        Text("Tap to open AirPlay picker")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary.opacity(0.8))
                            .lineLimit(1)
                    } else if !device.manufacturer.isEmpty && device.manufacturer != "Unknown" {
                        Text(device.manufacturer)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor)
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
    
    private var backgroundColor: Color {
        if isSelected && isHovered {
            return Color.accentColor.opacity(0.12)
        } else if isSelected {
            return Color.accentColor.opacity(0.08)
        } else if isHovered {
            return Color.primary.opacity(0.06)
        } else {
            return .clear
        }
    }
    
    private var deviceIcon: String {
        let deviceName = device.name.lowercased()

        // Check transport type first for accurate detection
        if device.isAirPlay {
            if deviceName.contains("homepod") {
                return "homepodmini"
            } else if deviceName.contains("apple tv") || deviceName.contains("appletv") {
                return "appletv"
            }
            return "airplayaudio"
        }

        // Bluetooth devices
        if device.transportType == AudioDevice.transportTypeBluetooth {
            if deviceName.contains("airpods") {
                return "airpodspro"
            }
            return "headphones"
        }

        // Built-in devices
        if device.transportType == AudioDevice.transportTypeBuiltIn {
            return "macbook.and.iphone"
        }

        // USB devices
        if device.transportType == AudioDevice.transportTypeUSB {
            return "cable.connector"
        }

        // Fallback to name-based detection
        if deviceName.contains("airpods") {
            return "airpodspro"
        } else if deviceName.contains("bluetooth") || deviceName.contains("headphone") {
            return "headphones"
        } else if deviceName.contains("built-in") || deviceName.contains("internal") || deviceName.contains("speakers") {
            return "macbook.and.iphone"
        } else if deviceName.contains("usb") {
            return "cable.connector"
        } else if deviceName.contains("hdmi") || deviceName.contains("thunderbolt") || deviceName.contains("displayport") || deviceName.contains("display") {
            return "tv"
        } else {
            return "hifispeaker"
        }
    }
}

