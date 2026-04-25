import Foundation
import Combine

/// Discovers AirPlay devices on the local network via Bonjour.
/// Browses both _airplay._tcp (AirPlay 2) and _raop._tcp (AirPlay 1/RAOP)
/// so all speakers — HomePods, Apple TVs, AirPort Express, third-party AirPlay
/// speakers — are surfaced even when not set as the system output.
class AirPlayDiscoveryManager: NSObject, ObservableObject {
    @Published var discoveredDeviceNames: Set<String> = []

    private var airplayBrowser: NetServiceBrowser?
    private var raopBrowser: NetServiceBrowser?

    override init() {
        super.init()
        startDiscovery()
    }

    deinit {
        stopDiscovery()
    }

    func startDiscovery() {
        discoveredDeviceNames = []

        // AirPlay 2 devices (HomePod, Apple TV, AirPlay 2 speakers)
        airplayBrowser = NetServiceBrowser()
        airplayBrowser?.delegate = self
        airplayBrowser?.searchForServices(ofType: "_airplay._tcp.", inDomain: "local.")

        // AirPlay 1 / RAOP devices (AirPort Express, older speakers)
        raopBrowser = NetServiceBrowser()
        raopBrowser?.delegate = self
        raopBrowser?.searchForServices(ofType: "_raop._tcp.", inDomain: "local.")
    }

    func stopDiscovery() {
        airplayBrowser?.stop()
        raopBrowser?.stop()
        airplayBrowser = nil
        raopBrowser = nil
    }

    /// RAOP service names are "AA:BB:CC:DD:EE:FF@Device Name" — strip the MAC prefix.
    private func parseName(from serviceName: String) -> String {
        if let atIndex = serviceName.firstIndex(of: "@") {
            return String(serviceName[serviceName.index(after: atIndex)...])
        }
        return serviceName
    }
}

extension AirPlayDiscoveryManager: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didFind service: NetService,
                           moreComing: Bool) {
        let name = parseName(from: service.name)
        DispatchQueue.main.async {
            self.discoveredDeviceNames.insert(name)
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didRemove service: NetService,
                           moreComing: Bool) {
        let name = parseName(from: service.name)
        DispatchQueue.main.async {
            self.discoveredDeviceNames.remove(name)
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didNotSearch errorDict: [String: NSNumber]) {
        print("⚠️ Bonjour browse error: \(errorDict)")
    }
}
