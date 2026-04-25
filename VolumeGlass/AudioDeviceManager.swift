import Foundation
import CoreAudio
import Combine
import AVFoundation

struct AudioDevice {
    let deviceID: AudioDeviceID
    let name: String
    let manufacturer: String
    let isOutput: Bool
    let isInput: Bool
    let transportType: UInt32
    let isAirPlay: Bool
    /// True when found via Bonjour but not yet registered as a CoreAudio system device.
    /// Tapping this device in the UI triggers the system AirPlay picker instead of
    /// calling CoreAudio's setOutputDevice directly.
    let isBonjourOnly: Bool

    /// A stable unique identifier for use with SwiftUI ForEach.
    var id: String {
        isBonjourOnly ? "bonjour_\(name)" : String(deviceID)
    }

    /// Transport type constants
    static let transportTypeBuiltIn: UInt32 = 0x626C746E    // 'bltn'
    static let transportTypeUSB: UInt32 = 0x75736220       // 'usb '
    static let transportTypeBluetooth: UInt32 = 0x626C7565 // 'blue'
    static let transportTypeAirPlay: UInt32 = 0x61697270   // 'airp'
    static let transportTypeVirtual: UInt32 = 0x76697274   // 'virt'
    static let transportTypeAggregate: UInt32 = 0x61677270 // 'agrp'
}

// Global callback for device list changes
private func deviceListChangeCallback(
    inObjectID: AudioObjectID,
    inNumberAddresses: UInt32,
    inAddresses: UnsafePointer<AudioObjectPropertyAddress>,
    inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = inClientData else { return noErr }
    let manager = Unmanaged<AudioDeviceManager>.fromOpaque(clientData).takeUnretainedValue()

    // Invalidate cache and reload devices
    DispatchQueue.main.async {
        manager.invalidateCache()
        manager.loadDevices()
    }

    return noErr
}

class AudioDeviceManager: ObservableObject {
    @Published var outputDevices: [AudioDevice] = []
    @Published var inputDevices: [AudioDevice] = []
    @Published var currentOutputDevice: AudioDevice?
    @Published var isLoading = false

    // Caching for reliable device list
    private var cachedDevices: [AudioDevice]?
    private var lastRefreshTime: Date?
    private let cacheValidDuration: TimeInterval = 2.0

    // Device change listener
    private var deviceListenerRegistered = false

    // AVRouteDetector for AirPlay awareness
    private var routeDetector: AVRouteDetector?
    private var routeObservation: NSKeyValueObservation?

    // Bonjour-based AirPlay discovery
    private let airPlayDiscovery = AirPlayDiscoveryManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupDeviceChangeListener()
        setupRouteDetector()
        loadDevices()

        // Re-merge device list whenever Bonjour discovers or loses an AirPlay device
        airPlayDiscovery.$discoveredDeviceNames
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.invalidateCache()
                self?.loadDevices()
            }
            .store(in: &cancellables)
    }

    deinit {
        cleanupListeners()
        routeObservation?.invalidate()
    }

    func invalidateCache() {
        cachedDevices = nil
        lastRefreshTime = nil
    }

    func loadDevices() {
        let devices = mergedDevices()

        DispatchQueue.main.async {
            self.cachedDevices = devices
            self.lastRefreshTime = Date()
            self.outputDevices = devices.filter { $0.isOutput }
            self.inputDevices = devices.filter { $0.isInput }
            self.currentOutputDevice = self.getCurrentOutputDevice()
        }
    }

    /// Async loading - ALWAYS loads fresh devices for reliability
    func loadDevicesAsync() async {
        await MainActor.run { isLoading = true }

        // Always load fresh - no caching for user-triggered loads to ensure reliability
        let devices = mergedDevices()

        await MainActor.run {
            self.cachedDevices = devices
            self.lastRefreshTime = Date()
            self.outputDevices = devices.filter { $0.isOutput }
            self.inputDevices = devices.filter { $0.isInput }
            self.currentOutputDevice = self.getCurrentOutputDevice()
            self.isLoading = false
            print("🔊 Loaded \(self.outputDevices.count) output devices (\(self.airPlayDiscovery.discoveredDeviceNames.count) via Bonjour)")
        }
    }

    /// Returns CoreAudio devices merged with Bonjour-discovered AirPlay devices.
    /// Bonjour devices that are already registered in CoreAudio are not duplicated.
    private func mergedDevices() -> [AudioDevice] {
        let coreAudioDevices = getAllAudioDevices()
        let coreAudioNames = Set(coreAudioDevices.map { $0.name.lowercased() })

        let bonjourOnlyDevices = airPlayDiscovery.discoveredDeviceNames
            .filter { !coreAudioNames.contains($0.lowercased()) }
            .map { name in
                AudioDevice(
                    deviceID: 0,
                    name: name,
                    manufacturer: "AirPlay",
                    isOutput: true,
                    isInput: false,
                    transportType: AudioDevice.transportTypeAirPlay,
                    isAirPlay: true,
                    isBonjourOnly: true
                )
            }
            .sorted { $0.name < $1.name }

        return coreAudioDevices + bonjourOnlyDevices
    }

    // MARK: - Route Detection Setup

    private func setupRouteDetector() {
        routeDetector = AVRouteDetector()
        routeDetector?.isRouteDetectionEnabled = true

        // Use KVO to observe when multiple AirPlay routes become available
        routeObservation = routeDetector?.observe(\.multipleRoutesDetected, options: [.new]) { [weak self] _, change in
            if change.newValue == true {
                print("🎵 AirPlay routes changed - refreshing device list")
                DispatchQueue.main.async {
                    self?.invalidateCache()
                    self?.loadDevices()
                }
            }
        }
    }

    // MARK: - Device Change Listener

    private func setupDeviceChangeListener() {
        guard !deviceListenerRegistered else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let result = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            deviceListChangeCallback,
            selfPtr
        )

        if result == noErr {
            deviceListenerRegistered = true
            print("🔊 Device change listener registered")
        }
    }

    private func cleanupListeners() {
        guard deviceListenerRegistered else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            deviceListChangeCallback,
            selfPtr
        )
        deviceListenerRegistered = false
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
        let sizeResult = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
        guard sizeResult == noErr, dataSize >= UInt32(MemoryLayout<AudioDeviceID>.size) else {
            return []
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array<AudioDeviceID>(repeating: 0, count: deviceCount)
        
        let listResult = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs)
        guard listResult == noErr else {
            return []
        }
        
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

        let transportType = getTransportType(deviceID: deviceID)
        let isAirPlay = transportType == AudioDevice.transportTypeAirPlay

        // AirPlay devices are always output-capable but may have no active streams when
        // they are on the network but not the current system output. Force isOutput = true
        // for them so they appear in the device list.
        let hasOutput = isAirPlay ? true : hasScope(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput)
        let hasInput = hasScope(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput)

        return AudioDevice(
            deviceID: deviceID,
            name: name,
            manufacturer: manufacturer,
            isOutput: hasOutput,
            isInput: hasInput,
            transportType: transportType,
            isAirPlay: isAirPlay,
            isBonjourOnly: false
        )
    }

    private func getTransportType(deviceID: AudioDeviceID) -> UInt32 {
        var transportType: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let result = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transportType)
        guard result == noErr else { return 0 }
        return transportType
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

        let valueResult = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, stringPtr)
        guard valueResult == noErr else { return nil }
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

