import Foundation
import CoreAudio
import Combine

struct AudioDevice {
    let deviceID: AudioDeviceID
    let name: String
    let manufacturer: String
    let isOutput: Bool
    let isInput: Bool
}

class AudioDeviceManager: ObservableObject {
    @Published var outputDevices: [AudioDevice] = []
    @Published var inputDevices: [AudioDevice] = []
    @Published var currentOutputDevice: AudioDevice?
    
    func loadDevices() {
        let devices = getAllAudioDevices()
        
        DispatchQueue.main.async {
            self.outputDevices = devices.filter { $0.isOutput }
            self.inputDevices = devices.filter { $0.isInput }
            self.currentOutputDevice = self.getCurrentOutputDevice()
        }
    }
    
    private func getAllAudioDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []
        
        // Get device IDs
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array<AudioDeviceID>(repeating: 0, count: deviceCount)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs)
        
        // Get device info for each ID
        for deviceID in deviceIDs {
            if let device = getDeviceInfo(deviceID: deviceID) {
                devices.append(device)
            }
        }
        
        return devices
    }
    
    private func getDeviceInfo(deviceID: AudioDeviceID) -> AudioDevice? {
        let name = getDeviceString(deviceID: deviceID, selector: kAudioDevicePropertyDeviceNameCFString) ?? "Unknown"
        let manufacturer = getDeviceString(deviceID: deviceID, selector: kAudioDevicePropertyDeviceManufacturerCFString) ?? "Unknown"
        
        let hasOutput = hasScope(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput)
        let hasInput = hasScope(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput)
        
        return AudioDevice(
            deviceID: deviceID,
            name: name,
            manufacturer: manufacturer,
            isOutput: hasOutput,
            isInput: hasInput
        )
    }
    
    private func getDeviceString(deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let result = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        guard result == noErr else { return nil }
        
        let stringPtr = UnsafeMutablePointer<CFString>.allocate(capacity: 1)
        defer { stringPtr.deallocate() }
        
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, stringPtr)
        return stringPtr.pointee as String
    }
    
    private func hasScope(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let result = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        return result == noErr && dataSize > 0
    }
    
    private func getCurrentOutputDevice() -> AudioDevice? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard result == noErr else { return nil }
        
        return getDeviceInfo(deviceID: deviceID)
    }
    
    func setOutputDevice(_ device: AudioDevice) {
        var deviceID = device.deviceID
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let result = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &deviceID)
        
        if result == noErr {
            DispatchQueue.main.async {
                self.currentOutputDevice = device
            }
        }
    }
}

