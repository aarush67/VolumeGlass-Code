//
//  UpdateChecker.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import Foundation
import AppKit
import Combine

/// Lightweight update checker that uses GitHub releases API
@MainActor
class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    
    /// GitHub repository info
    private let owner = "aarush67"
    private let repo = "volumeglass-download"
    
    /// Background update check interval: 24 hours (industry standard)
    private let checkInterval: TimeInterval = 86400
    
    /// Timer fires hourly to evaluate if a daily check is needed
    private var backgroundTimer: Timer?
    
    /// UserDefaults key for last auto-check timestamp
    private let lastCheckKey = "lastAutoUpdateCheck"
    
    /// UserDefaults key for "remind me later" snooze date
    private let remindLaterKey = "updateRemindLaterDate"
    
    /// Current app version
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Published properties for UI binding
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var downloadURL: URL?
    @Published var releaseNotes: String?
    @Published var isChecking = false
    
    private init() {}
    
    // MARK: - Background Update Scheduling
    
    /// Start the background update scheduler. Call once at app launch.
    func startBackgroundChecking() {
        print("UpdateChecker: Starting background update scheduler (interval: \(Int(checkInterval / 3600))h)")
        
        // Always check on app launch (silently — only show popup if update found)
        performBackgroundCheck()
        
        // Schedule hourly timer to evaluate if 24h have passed for subsequent checks
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            guard let checker = self else { return }
            Task { @MainActor in
                checker.checkIfDailyCheckNeeded()
            }
        }
    }
    
    /// Evaluate if 24 hours have passed since last check
    private func checkIfDailyCheckNeeded() {
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        let hoursSinceLastCheck = Date().timeIntervalSince(lastCheck) / 3600
        
        if hoursSinceLastCheck >= 24 {
            print("UpdateChecker: Performing daily update check (last check: \(Int(hoursSinceLastCheck))h ago)")
            performBackgroundCheck()
        } else {
            print("UpdateChecker: Skipping check, last check was \(Int(hoursSinceLastCheck))h ago")
        }
    }
    
    /// Perform background check and show update notification if available
    private func performBackgroundCheck() {
        Task {
            await checkForUpdates()
            
            // Record successful check
            UserDefaults.standard.set(Date(), forKey: lastCheckKey)
            
            if updateAvailable {
                // Respect "remind me later" snooze
                if let snoozeUntil = UserDefaults.standard.object(forKey: remindLaterKey) as? Date,
                   Date() < snoozeUntil {
                    print("UpdateChecker: Update available but snoozed until \(snoozeUntil)")
                    return
                }
                showUpdateAlert()
            }
        }
    }
    
    /// Snooze the update popup for 3 days
    func remindLater() {
        let snoozeUntil = Date().addingTimeInterval(3 * 86400)
        UserDefaults.standard.set(snoozeUntil, forKey: remindLaterKey)
        print("UpdateChecker: Snoozed until \(snoozeUntil)")
    }
    
    /// Clear any active snooze (e.g. when user manually checks)
    func clearRemindLater() {
        UserDefaults.standard.removeObject(forKey: remindLaterKey)
    }
    
    /// Check for updates from GitHub releases
    func checkForUpdates() async {
        guard !isChecking else { return }
        
        isChecking = true
        defer { isChecking = false }
        
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("UpdateChecker: Failed to fetch releases")
                return
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                print("UpdateChecker: Invalid response format")
                return
            }
            
            // Parse version (remove 'v' prefix if present)
            let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            
            latestVersion = remoteVersion
            releaseNotes = json["body"] as? String
            
            // Find DMG download URL from assets
            if let assets = json["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let name = asset["name"] as? String,
                       name.lowercased().hasSuffix(".dmg"),
                       let urlString = asset["browser_download_url"] as? String,
                       let assetURL = URL(string: urlString) {
                        downloadURL = assetURL
                        break
                    }
                }
            }
            
            updateAvailable = isNewerVersion(remoteVersion, than: currentVersion)
            print("UpdateChecker: Check complete. Update available: \(updateAvailable) (\(currentVersion) → \(remoteVersion))")
            
        } catch {
            print("UpdateChecker: Error checking for updates: \(error)")
        }
    }
    
    /// Compare version strings (supports semantic versioning)
    /// Special handling for version reset from 9.x to production 1.x/2.x/etc.
    private func isNewerVersion(_ remote: String, than current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        
        let currentMajor = currentParts.first ?? 0
        let remoteMajor = remoteParts.first ?? 0
        
        // Handle version reset: 9.x is the bridge version
        // If user is on 9.x (bridge) and remote is 1.x through 8.x (production), treat as update
        // This allows: 9.0.0 → 1.0.4, 9.0.5 → 2.0.0, etc.
        if currentMajor == 9 && remoteMajor >= 1 && remoteMajor <= 8 {
            print("UpdateChecker: Version reset detected (\(current) → \(remote)), treating as update")
            return true
        }
        
        // Standard semantic version comparison
        for i in 0..<max(remoteParts.count, currentParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            
            if r > c { return true }
            if r < c { return false }
        }
        
        return false
    }
    
    /// Show the update-available alert popup
    func showUpdateAlert() {
        guard updateAvailable, latestVersion != nil else { return }
        UpdateAlertWindowController.shared.show()
    }

    /// Notify that an update is available — the Settings view observes updateAvailable reactively
    func showUpdateWindow() {
        guard updateAvailable, latestVersion != nil else { return }
        NotificationCenter.default.post(name: Notification.Name("VolumeGlassUpdateAvailable"), object: nil)
    }
    
    // Removed old update methods as they are replaced by AutoUpdater
    
    /// Check for updates and update published state — also shows popup if update found
    func checkAndNotify() {
        clearRemindLater()
        UpdateAlertWindowController.shared.showChecking()
        Task {
            await checkForUpdates()
            if updateAvailable {
                showingUpToDate = false
                UpdateAlertWindowController.shared.dismiss()
                showUpdateAlert()
            } else {
                showingUpToDate = true
                UpdateAlertWindowController.shared.showUpToDate()
            }
        }
    }
    
    /// Published property to indicate we're showing "up to date" state
    @Published var showingUpToDate = false
}
