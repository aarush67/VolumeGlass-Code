import Foundation
import AVFoundation
import CoreAudio
import SwiftUI
import AppKit
import Combine

// MARK: - C Callback Functions (must be global or static)

private func volumeChangeCallback(
    inObjectID: AudioObjectID,
    inNumberAddresses: UInt32,
    inAddresses: UnsafePointer<AudioObjectPropertyAddress>,
    inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = inClientData else { return noErr }
    let monitor = Unmanaged<VolumeMonitor>.fromOpaque(clientData).takeUnretainedValue()
    
    monitor.getCurrentVolume()
    monitor.checkMuteStatus()
    monitor.startVolumeChangeIndicator()
    
    return noErr
}

private func deviceChangeCallback(
    inObjectID: AudioObjectID,
    inNumberAddresses: UInt32,
    inAddresses: UnsafePointer<AudioObjectPropertyAddress>,
    inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = inClientData else { return noErr }
    let monitor = Unmanaged<VolumeMonitor>.fromOpaque(clientData).takeUnretainedValue()
    
    monitor.cleanupListeners()
    monitor.audioDeviceID = monitor.getDefaultOutputDevice()
    monitor.setupVolumeMonitoring()
    monitor.getCurrentVolume()
    monitor.checkMuteStatus()
    
    return noErr
}

// MARK: - VolumeMonitor Class

class VolumeMonitor: ObservableObject {
    @Published var currentVolume: Float = 0.5
    @Published var isVolumeChanging = false
    @Published var isMuted = false
    /// The last volume level before the system was muted. Used so that
    /// pressing volume up/down after mute adjusts relative to the previous level.
    var lastVolumeBeforeMute: Float = 0.5
    
    fileprivate var audioDeviceID: AudioDeviceID = 0
    private var volumeChangeTimer: Timer?
    var overlayWindows: [VolumeOverlayWindow] = []
    var notchWindows: [NotchOverlayWindow] = []
    var notchAttachedWindows: [NotchAttachedWindow] = []
    private var cancellables = Set<AnyCancellable>()
    
    var setupState: SetupState?
    
    init() {
        print("🎵 VolumeMonitor initialized")
        setupVolumeMonitoring()
        setupDeviceChangeMonitoring()
        getCurrentVolume()
        checkMuteStatus()
    }
    
    deinit {
        print("💀 VolumeMonitor deinit called")
        cleanupListeners()
        destroyOverlays()
    }
    
    func destroyOverlays() {
        print("🗑️ Destroying \(overlayWindows.count) overlay windows and \(notchWindows.count) notch windows")
        let windowsToDestroy = overlayWindows
        overlayWindows.removeAll()
        
        for window in windowsToDestroy {
            print("   Closing window: \(window)")
            window.close()
        }

        let notchToDestroy = notchWindows
        notchWindows.removeAll()

        for window in notchToDestroy {
            window.close()
        }

        let notchAttachedToDestroy = notchAttachedWindows
        notchAttachedWindows.removeAll()

        for window in notchAttachedToDestroy {
            window.close()
        }
    }
    
    func createVolumeOverlay() {
        print("🪟 Creating volume overlays...")
        print("📍 Setup state position: \(setupState?.selectedPosition.displayName ?? "nil")")
        print("📏 Setup state size: \(setupState?.barSize ?? 0)")
        
        // Get all screens and log them
        let screens = NSScreen.screens
        print("📺 Found \(screens.count) screen(s):")
        for (index, screen) in screens.enumerated() {
            print("   Screen \(index): \(screen.localizedName)")
            print("      Frame: \(screen.frame)")
            print("      Visible Frame: \(screen.visibleFrame)")
        }
        
        // Create overlay for each unique screen
        var processedScreens = Set<String>()
        
        for screen in screens {
            // Use screen frame as unique identifier
            let screenID = "\(screen.frame.origin.x),\(screen.frame.origin.y),\(screen.frame.width),\(screen.frame.height)"
            
            // Skip if already processed
            if processedScreens.contains(screenID) {
                print("⚠️ Skipping duplicate screen: \(screen.localizedName)")
                continue
            }
            
            processedScreens.insert(screenID)
            
            let window = VolumeOverlayWindow(volumeMonitor: self, screen: screen)
            window.showVolumeIndicator()
            overlayWindows.append(window)
            
            print("✅ Created overlay on: \(screen.localizedName)")

            // Create notch overlay pill if enabled and screen has a notch
            if setupState?.showInNotch == true && NotchOverlayWindow.screenHasNotch(screen) {
                let notchWindow = NotchOverlayWindow(volumeMonitor: self, screen: screen)
                notchWindow.showIndicator()
                notchWindows.append(notchWindow)
                print("🔲 Created notch pill overlay on: \(screen.localizedName)")
            }

            // Create notch-attached bar if enabled and screen has a notch
            if setupState?.showNotchBar == true && NotchAttachedWindow.screenHasNotch(screen) {
                let attachedWindow = NotchAttachedWindow(volumeMonitor: self, screen: screen)
                attachedWindow.showIndicator()
                notchAttachedWindows.append(attachedWindow)
                print("🖥️ Created notch-attached bar on: \(screen.localizedName)")
            }
        }
        
        print("✅ Total overlays created: \(overlayWindows.count)")
    }
    
    // MARK: - Volume Monitoring Setup
    
    fileprivate func setupVolumeMonitoring() {
        audioDeviceID = getDefaultOutputDevice()
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListener(
            audioDeviceID,
            &address,
            volumeChangeCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        address.mSelector = kAudioDevicePropertyMute
        AudioObjectAddPropertyListener(
            audioDeviceID,
            &address,
            volumeChangeCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        print("🔊 Volume monitoring setup complete")
    }
    
    private func setupDeviceChangeMonitoring() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            deviceChangeCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
    
    fileprivate func getDefaultOutputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        
        return deviceID
    }
    
    // MARK: - Volume Control
    
    func getCurrentVolume() {
        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let result = AudioObjectGetPropertyData(
            audioDeviceID,
            &address,
            0,
            nil,
            &size,
            &volume
        )
        
        if result == noErr {
            DispatchQueue.main.async { [weak self] in
                self?.currentVolume = volume
            }
        }
    }
    
    func checkMuteStatus() {
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let result = AudioObjectGetPropertyData(
            audioDeviceID,
            &address,
            0,
            nil,
            &size,
            &muted
        )
        
        if result == noErr {
            DispatchQueue.main.async { [weak self] in
                let nowMuted = muted != 0
                // If we've just become muted, remember the last volume level
                if nowMuted && self?.isMuted == false {
                    if let current = self?.currentVolume {
                        self?.lastVolumeBeforeMute = current
                    }
                }
                self?.isMuted = nowMuted
            }
        }
    }
    
    func setSystemVolume(_ volume: Float) {
        var newVolume = Float32(max(0, min(1, volume)))
        let size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        print("🔊 [setSystemVolume] Setting volume to: \(newVolume) (0.0 = mute, 1.0 = max)")
        
        let result = AudioObjectSetPropertyData(
            audioDeviceID,
            &address,
            0,
            nil,
            size,
            &newVolume
        )
        
        if result == noErr {
            print("✅ [setSystemVolume] Volume set successfully")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // If currently muted, unmute before applying the new volume so
                // key-based adjustments behave as users expect.
                if self.isMuted {
                    var mutedFlag: UInt32 = 0
                    var muteAddr = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyMute,
                        mScope: kAudioDevicePropertyScopeOutput,
                        mElement: kAudioObjectPropertyElementMain
                    )
                    let muteResult = AudioObjectSetPropertyData(
                        self.audioDeviceID,
                        &muteAddr,
                        0,
                        nil,
                        UInt32(MemoryLayout<UInt32>.size),
                        &mutedFlag
                    )
                    if muteResult == noErr {
                        self.isMuted = false
                        print("🔊 [setSystemVolume] Unmuted due to volume change")
                    }
                }

                self.currentVolume = volume
                self.startVolumeChangeIndicator()
            }
        } else {
            print("❌ [setSystemVolume] Failed to set volume. Result: \(result)")
        }
    }
    
    func toggleMute() {
        var muted: UInt32 = isMuted ? 0 : 1
        let size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        print("🔇 [toggleMute] Mute state changing from \(isMuted) to \(!isMuted)")
        // If we're muting, remember the last audible volume so we can adjust
        // relative to it when the user presses volume keys while muted.
        if !isMuted {
            lastVolumeBeforeMute = currentVolume
        }
        
        let result = AudioObjectSetPropertyData(
            audioDeviceID,
            &address,
            0,
            nil,
            size,
            &muted
        )
        
        if result == noErr {
            print("✅ [toggleMute] Mute toggled successfully")
            checkMuteStatus()
        } else {
            print("❌ [toggleMute] Failed to toggle mute. Result: \(result)")
        }
    }
    
    func startVolumeChangeIndicator() {
        DispatchQueue.main.async { [weak self] in
            self?.isVolumeChanging = true
            self?.volumeChangeTimer?.invalidate()
            
            // Use the dismiss time from settings if available, otherwise fall back to 2.0s
            let timeout = Double(self?.setupState?.volumeDismissTime ?? 2.0)
            self?.volumeChangeTimer = Timer.scheduledTimer(
                withTimeInterval: timeout,
                repeats: false
            ) { [weak self] _ in
                guard let self = self else { return }
                self.isVolumeChanging = false
                // Ensure UI consumers retract the main volume bar when volume
                // has stopped changing (covers edge-cases with multiple overlays).
                NotificationCenter.default.post(
                    name: NSNotification.Name("VolumeBarVisibilityChanged"),
                    object: nil,
                    userInfo: ["isVisible": false]
                )
            }
        }
    }
    
    // MARK: - Cleanup
    
    fileprivate func cleanupListeners() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectRemovePropertyListener(
            audioDeviceID,
            &address,
            volumeChangeCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        address.mSelector = kAudioDevicePropertyMute
        AudioObjectRemovePropertyListener(
            audioDeviceID,
            &address,
            volumeChangeCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )

        var deviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &deviceAddress,
            deviceChangeCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}

