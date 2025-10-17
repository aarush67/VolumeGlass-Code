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
    
    // Clean up old device listeners
    monitor.cleanupListeners()
    
    // Setup new device
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
    
    fileprivate var audioDeviceID: AudioDeviceID = 0
    private var volumeChangeTimer: Timer?
    private var overlayWindow: VolumeOverlayWindow?
    private var cancellables = Set<AnyCancellable>()
    private var keyEventMonitor: Any?
    
    var setupState: SetupState?
    
    init() {
        print("🎵 VolumeMonitor initialized")
        setupVolumeMonitoring()
        setupDeviceChangeMonitoring()
        setupKeyboardMonitoring()
        getCurrentVolume()
        checkMuteStatus()
    }
    
    deinit {
        cleanupListeners()
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func createVolumeOverlay() {
        print("🪟 Creating volume overlay...")
        print("📍 Setup state position: \(setupState?.selectedPosition.displayName ?? "nil")")
        print("📏 Setup state size: \(setupState?.barSize ?? 0)")
        overlayWindow = VolumeOverlayWindow(volumeMonitor: self)
        overlayWindow?.showVolumeIndicator()
        print("✅ Volume overlay created and shown")
    }
    
    // MARK: - Volume Monitoring Setup
    
    fileprivate func setupVolumeMonitoring() {
        audioDeviceID = getDefaultOutputDevice()
        
        // Add volume change listener
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
        
        // Add mute listener
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
    
    private func setupKeyboardMonitoring() {
        // Monitor volume key presses (F11, F12) to show overlay
        keyEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // F11 = 0x67 (Volume Down), F12 = 0x6F (Volume Up)
            if event.keyCode == 0x67 || event.keyCode == 0x6F {
                self?.startVolumeChangeIndicator()
            }
        }
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
                self?.isMuted = muted != 0
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
        
        let result = AudioObjectSetPropertyData(
            audioDeviceID,
            &address,
            0,
            nil,
            size,
            &newVolume
        )
        
        if result == noErr {
            DispatchQueue.main.async { [weak self] in
                self?.currentVolume = volume
                self?.startVolumeChangeIndicator()
            }
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
        
        AudioObjectSetPropertyData(
            audioDeviceID,
            &address,
            0,
            nil,
            size,
            &muted
        )
    }
    
    func startVolumeChangeIndicator() {
        DispatchQueue.main.async { [weak self] in
            self?.isVolumeChanging = true
            self?.volumeChangeTimer?.invalidate()
            
            self?.volumeChangeTimer = Timer.scheduledTimer(
                withTimeInterval: 2.0,
                repeats: false
            ) { [weak self] _ in
                self?.isVolumeChanging = false
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
    }
}

