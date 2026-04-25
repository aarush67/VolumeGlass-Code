import Foundation
import Combine

// MARK: - License State

enum LicenseStatus: String, Codable {
    case unlicensed   // No license or trial started
    case trial        // Trial is active
    case active       // Paid license is active
    case expired      // Trial or license expired
}

// MARK: - License Manager
// Delegates trial operations to TrialManager (server-side).
// Keeps the same public API for UI compatibility.

class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    // UserDefaults keys for offline caching
    private let cachedStatusKey  = "VG_LicenseStatus"
    private let licenseEmailKey  = "VG_LicenseEmail"
    private let hasUsedTrialKey  = "VG_TrialHasBeenUsed"
    private let licenseKeyUDKey  = "com.volumeglass.licenseKey"

    @Published var licenseStatus: LicenseStatus = .unlicensed
    @Published var licenseMessage: String = ""
    @Published var isValidating: Bool = false
    @Published var licenseEmail: String? = nil
    @Published var licensePlan: String? = nil
    @Published var trialExpiredWhileRunning: Bool = false
    @Published var hasUsedTrial: Bool = false
    @Published var trialDaysRemaining: Int = 0

    private var cancellables = Set<AnyCancellable>()

    var storedLicenseKey: String? {
        UserDefaults.standard.string(forKey: licenseKeyUDKey)
    }

    var isTrialExpired: Bool {
        licenseStatus == .expired
    }

    private init() {
        loadCachedStatus()
        observeTrialManager()
    }
    
    // MARK: - Cached Status (offline tolerance)

    private func loadCachedStatus() {
        if let raw = UserDefaults.standard.string(forKey: cachedStatusKey),
           let status = LicenseStatus(rawValue: raw) {
            licenseStatus = status
        }
        licenseEmail = UserDefaults.standard.string(forKey: licenseEmailKey)
        hasUsedTrial = UserDefaults.standard.bool(forKey: hasUsedTrialKey)
        if hasUsedTrial && licenseStatus != .active && licenseStatus != .trial {
            licenseStatus = .expired
        }
    }

    private func cacheStatus(_ status: LicenseStatus) {
        licenseStatus = status
        UserDefaults.standard.set(status.rawValue, forKey: cachedStatusKey)
        if let email = licenseEmail {
            UserDefaults.standard.set(email, forKey: licenseEmailKey)
        }
        UserDefaults.standard.set(hasUsedTrial, forKey: hasUsedTrialKey)
    }

    // MARK: - TrialManager Observation

    private func observeTrialManager() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let tm = TrialManager.shared

            tm.$accessResult
                .receive(on: DispatchQueue.main)
                .sink { [weak self] result in self?.syncAccessResult(result) }
                .store(in: &self.cancellables)

            tm.$trialExpiredWhileRunning
                .receive(on: DispatchQueue.main)
                .sink { [weak self] expired in
                    if expired { self?.trialExpiredWhileRunning = true }
                }
                .store(in: &self.cancellables)

            tm.$daysRemaining
                .receive(on: DispatchQueue.main)
                .sink { [weak self] days in self?.trialDaysRemaining = days }
                .store(in: &self.cancellables)

            tm.$message
                .receive(on: DispatchQueue.main)
                .sink { [weak self] msg in if !msg.isEmpty { self?.licenseMessage = msg } }
                .store(in: &self.cancellables)

            tm.$licenseEmail
                .receive(on: DispatchQueue.main)
                .sink { [weak self] email in self?.licenseEmail = email }
                .store(in: &self.cancellables)

            tm.$licensePlan
                .receive(on: DispatchQueue.main)
                .sink { [weak self] plan in self?.licensePlan = plan }
                .store(in: &self.cancellables)
        }
    }

    private func syncAccessResult(_ result: AccessResult) {
        switch result {
        case .licensed:
            hasUsedTrial = true
            cacheStatus(.active)
        case .trialing(let daysLeft):
            hasUsedTrial = true
            trialDaysRemaining = daysLeft
            cacheStatus(.trial)
        case .expired:
            hasUsedTrial = true
            trialDaysRemaining = 0
            cacheStatus(.expired)
        case .noAccess:
            cacheStatus(.unlicensed)
        }
    }

    // MARK: - Trial (Server-Side)

    /// Start a server-side trial. Completion returns success.
    func startTrial(completion: @escaping (Bool) -> Void) {
        isValidating = true
        Task { @MainActor in
            let success = await TrialManager.shared.startTrial()
            self.isValidating = false
            if success {
                print("🎫 Server trial started")
            } else {
                print("❌ Failed to start server trial")
            }
            completion(success)
        }
    }

    func startTrialExpirationMonitor() {
        Task { @MainActor in
            TrialManager.shared.startExpirationMonitor()
        }
    }

    func stopTrialExpirationMonitor() {
        Task { @MainActor in
            TrialManager.shared.stopExpirationMonitor()
        }
    }
    
    // MARK: - License Key Storage

    func storeLicenseKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        UserDefaults.standard.set(trimmed, forKey: licenseKeyUDKey)
    }

    func clearLicenseKey() {
        UserDefaults.standard.removeObject(forKey: licenseKeyUDKey)
    }

    // MARK: - License Check (Server-Side)

    func checkLicenseOnLaunch(completion: @escaping (Bool) -> Void) {
        let previousCachedStatus = UserDefaults.standard.string(forKey: cachedStatusKey)
            .flatMap { LicenseStatus(rawValue: $0) } ?? .unlicensed

        Task { @MainActor in
            let tm = TrialManager.shared
            await tm.checkAccess()

            self.licenseEmail       = tm.licenseEmail
            self.licensePlan        = tm.licensePlan
            self.licenseMessage     = tm.message
            self.trialDaysRemaining = tm.daysRemaining

            switch tm.accessResult {
            case .licensed:
                self.syncAccessResult(tm.accessResult)
                completion(true)
            case .trialing:
                self.syncAccessResult(tm.accessResult)
                completion(true)
            case .expired:
                self.syncAccessResult(tm.accessResult)
                completion(false)
            case .noAccess:
                // Offline tolerance: if previously cached as active/trial, allow access
                if previousCachedStatus == .active || previousCachedStatus == .trial {
                    self.licenseStatus = previousCachedStatus
                    completion(true)
                } else {
                    self.syncAccessResult(tm.accessResult)
                    completion(false)
                }
            }
        }
    }

    // MARK: - License Activation

    func activateLicense(key: String, completion: @escaping (Bool, String) -> Void) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            completion(false, "Please enter a license key.")
            return
        }

        isValidating = true

        Task { @MainActor in
            let (success, msg) = await TrialManager.shared.activate(licenseKey: trimmed)
            self.isValidating = false
            if success {
                self.syncAccessResult(TrialManager.shared.accessResult)
                self.licenseEmail   = TrialManager.shared.licenseEmail
                self.licensePlan    = TrialManager.shared.licensePlan
                self.licenseMessage = msg
            }
            completion(success, msg)
        }
    }

    // MARK: - Reset

    func resetAll() {
        UserDefaults.standard.removeObject(forKey: licenseKeyUDKey)
        UserDefaults.standard.removeObject(forKey: cachedStatusKey)
        UserDefaults.standard.removeObject(forKey: licenseEmailKey)
        UserDefaults.standard.removeObject(forKey: hasUsedTrialKey)
        licenseStatus            = .unlicensed
        licenseMessage           = ""
        licenseEmail             = nil
        licensePlan              = nil
        hasUsedTrial             = false
        trialExpiredWhileRunning = false
        trialDaysRemaining       = 0
        Task { @MainActor in
            TrialManager.shared.clearLicenseKey()
            TrialManager.shared.stopExpirationMonitor()
        }
    }

    // MARK: - Debug
    #if DEBUG

    var debugInfo: String {
        let status     = licenseStatus.rawValue
        let hasUsed    = hasUsedTrial
        let days       = trialDaysRemaining
        let expired    = isTrialExpired
        let savedKey   = storedLicenseKey ?? "nil"
        let serverMsg  = licenseMessage

        return """
        Status: \(status)
        Has Used Trial: \(hasUsed)
        Days Remaining: \(days)
        Is Expired: \(expired)
        License Key: \(savedKey)
        Server Message: \(serverMsg)
        Trial: server-controlled (3 days)
        """
    }

    func debugForceExpireTrial() {
        cacheStatus(.expired)
        hasUsedTrial = true
        trialExpiredWhileRunning = true
        licenseMessage = "VolumeGlass trial has expired. Please purchase a license to continue."
        print("⚠️ [DEBUG] Trial force-expired (local cache only)")
    }

    func debugStartShortTrial(seconds: TimeInterval = 60) {
        print("⚠️ [DEBUG] Short trials not available — trial is server-controlled")
    }

    func debugResetTrialOnly() {
        UserDefaults.standard.removeObject(forKey: cachedStatusKey)
        UserDefaults.standard.removeObject(forKey: hasUsedTrialKey)
        licenseStatus = .unlicensed
        hasUsedTrial = false
        licenseMessage = ""
        trialExpiredWhileRunning = false
        trialDaysRemaining = 0
        Task { @MainActor in
            TrialManager.shared.stopExpirationMonitor()
        }
        print("⚠️ [DEBUG] Local trial cache reset (server state unchanged)")
    }

    #endif
}
