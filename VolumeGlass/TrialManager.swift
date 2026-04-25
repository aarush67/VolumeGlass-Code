// TrialManager.swift
// VolumeGlass
//
// Drop this file into your Xcode project.
// It handles all server-side trial communication.
//
// SETUP:
//   1. Set TRIAL_API_SECRET in your .env on Vercel
//   2. Replace the two constants below with your actual values
//   3. Call TrialManager.shared.checkAccess() on every app launch

import Foundation
import Combine
import CryptoKit
import IOKit

// ─── Configuration ────────────────────────────────────────────────────────────

private let kServerURL    = "https://volumeglass.app"
private let kTrialSecret  = "8db440f37433a3758e2d3fd2d023f530ced9d0055092cef78cb4b8e88e0e3fcd"
private let kLicenseKey   = "com.volumeglass.licenseKey"
private let kDeviceIdKey  = "com.volumeglass.deviceId"

// ─── Response Types ───────────────────────────────────────────────────────────

struct TrialResponse: Codable {
    let allowed:   Bool
    let status:    String       // "active" | "expired" | "converted"
    let expiresAt: String?
    let daysLeft:  Int
    let message:   String

    enum CodingKeys: String, CodingKey {
        case allowed, status, message
        case expiresAt  = "expires_at"
        case daysLeft   = "days_left"
    }
}

struct LicenseResponse: Codable {
    let valid:   Bool
    let status:  String
    let plan:    String
    let message: String
    let email:   String?
}

// ─── Access Result ────────────────────────────────────────────────────────────

enum AccessResult {
    case licensed                       // valid paid license
    case trialing(daysLeft: Int)        // active server-side trial
    case expired                        // trial ended
    case noAccess                       // no trial started, no license
}

// ─── TrialManager ─────────────────────────────────────────────────────────────

@MainActor
class TrialManager: ObservableObject {
    static let shared = TrialManager()

    @Published var accessResult: AccessResult = .noAccess
    @Published var isLoading = true
    @Published var daysRemaining: Int = 0
    @Published var trialExpiredWhileRunning = false
    @Published var licenseEmail: String? = nil
    @Published var licensePlan: String? = nil
    @Published var message: String = ""

    private var expirationTimer: Timer?

    private init() {}

    // ── Check access — call on every app launch ──────────────────────────
    // Only checks server state; does NOT start a new trial.

    func checkAccess() async {
        isLoading = true
        defer { isLoading = false }

        // 1. If user has a saved license key, validate it first
        if let savedKey = getSavedLicenseKey() {
            if let result = await validateLicense(key: savedKey), result.valid {
                licenseEmail = result.email
                licensePlan  = result.plan
                message      = result.message
                accessResult = .licensed

                let deviceId = getOrCreateDeviceId()
                await convertTrial(deviceId: deviceId, licenseKey: savedKey)
                return
            }
        }

        // 2. Check server-side trial status
        let deviceId = getOrCreateDeviceId()
        let trial    = await trialRequest(action: "check", deviceId: deviceId)

        guard let trial = trial else {
            if case .noAccess = accessResult {
                message = "Unable to reach server. Please check your connection."
            }
            return
        }

        message       = trial.message
        daysRemaining = trial.daysLeft

        if trial.allowed && trial.status == "active" {
            accessResult = .trialing(daysLeft: trial.daysLeft)
            startExpirationMonitor()
        } else if trial.expiresAt != nil {
            accessResult = .expired
        } else {
            accessResult = .noAccess
        }
    }

    // ── Start a new trial ─────────────────────────────────────────────────

    func startTrial(email: String? = nil) async -> Bool {
        let deviceId = getOrCreateDeviceId()
        let response = await trialRequest(
            action:       "start",
            deviceId:     deviceId,
            email:        email,
            appVersion:   Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            macosVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )

        guard let response = response, response.allowed else {
            message = response?.message ?? "Failed to start trial. Please try again."
            return false
        }

        daysRemaining = response.daysLeft
        message       = response.message
        accessResult  = .trialing(daysLeft: response.daysLeft)
        startExpirationMonitor()
        return true
    }

    // ── Activate a purchased license ──────────────────────────────────────

    func activate(licenseKey: String) async -> (success: Bool, message: String) {
        guard let result = await validateLicense(key: licenseKey) else {
            return (false, "Connection error. Please try again.")
        }

        guard result.valid else {
            return (false, result.message)
        }

        saveLicenseKey(licenseKey)
        licenseEmail = result.email
        licensePlan  = result.plan
        message      = result.message

        let deviceId = getOrCreateDeviceId()
        await convertTrial(deviceId: deviceId, licenseKey: licenseKey)

        accessResult = .licensed
        stopExpirationMonitor()
        return (true, result.message)
    }

    // ── Expiration monitor ────────────────────────────────────────────────
    // Polls server every 5 minutes to detect trial expiry while running.

    func startExpirationMonitor() {
        stopExpirationMonitor()

        expirationTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let deviceId = self.getOrCreateDeviceId()
                guard let trial = await self.trialRequest(action: "check", deviceId: deviceId) else { return }

                self.daysRemaining = trial.daysLeft

                if !trial.allowed && trial.status == "expired" {
                    self.accessResult            = .expired
                    self.trialExpiredWhileRunning = true
                    self.message                 = trial.message
                    self.stopExpirationMonitor()
                }
            }
        }
    }

    func stopExpirationMonitor() {
        expirationTimer?.invalidate()
        expirationTimer = nil
    }

    // ─── Private API calls ────────────────────────────────────────────────

    private func trialRequest(
        action:       String,
        deviceId:     String,
        email:        String?  = nil,
        appVersion:   String?  = nil,
        macosVersion: String?  = nil,
        licenseKey:   String?  = nil
    ) async -> TrialResponse? {
        guard let url = URL(string: "\(kServerURL)/api/trial") else { return nil }

        var body: [String: Any] = [
            "action":    action,
            "device_id": deviceId,
        ]
        if let e = email        { body["email"]         = e }
        if let v = appVersion   { body["app_version"]   = v }
        if let m = macosVersion { body["macos_version"] = m }
        if let k = licenseKey   { body["license_key"]   = k }

        var req            = URLRequest(url: url)
        req.httpMethod     = "POST"
        req.setValue("application/json",        forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(kTrialSecret)",  forHTTPHeaderField: "Authorization")
        req.httpBody       = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return try? JSONDecoder().decode(TrialResponse.self, from: data)
    }

    private func convertTrial(deviceId: String, licenseKey: String) async {
        _ = await trialRequest(action: "convert", deviceId: deviceId, licenseKey: licenseKey)
    }

    private func validateLicense(key: String) async -> LicenseResponse? {
        guard let url = URL(string: "\(kServerURL)/api/validate-license") else { return nil }

        var req            = URLRequest(url: url)
        req.httpMethod     = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody       = try? JSONSerialization.data(withJSONObject: ["license_key": key])
        req.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return try? JSONDecoder().decode(LicenseResponse.self, from: data)
    }

    // ─── Device ID ───────────────────────────────────────────────────────
    // SHA-256 hash of hardware serial number + hardware UUID.
    // Hash is stored in UserDefaults after first computation.
    // We never send raw hardware info to the server — only the hash.

    func getOrCreateDeviceId() -> String {
        if let saved = UserDefaults.standard.string(forKey: kDeviceIdKey) {
            return saved
        }
        let id = computeDeviceId()
        UserDefaults.standard.set(id, forKey: kDeviceIdKey)
        return id
    }

    private func computeDeviceId() -> String {
        let serial = getHardwareSerial() ?? "unknown-serial"
        let uuid   = getHardwareUUID()  ?? "unknown-uuid"
        let raw    = "volumeglass-\(serial)-\(uuid)"

        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func getHardwareSerial() -> String? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(service) }

        return IORegistryEntryCreateCFProperty(
            service,
            "IOPlatformSerialNumber" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String
    }

    private func getHardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(service) }

        return IORegistryEntryCreateCFProperty(
            service,
            "IOPlatformUUID" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String
    }

    // ─── License Key Storage ──────────────────────────────────────────────

    func saveLicenseKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: kLicenseKey)
    }

    func getSavedLicenseKey() -> String? {
        UserDefaults.standard.string(forKey: kLicenseKey)
    }

    func clearLicenseKey() {
        UserDefaults.standard.removeObject(forKey: kLicenseKey)
    }
}
