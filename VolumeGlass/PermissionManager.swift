//
//  PermissionManager.swift
//  VolumeGlass
//
//  Created by Aarush Prakash on 2/15/26.
//

import AppKit
import ApplicationServices

/// Manages accessibility permissions for the app
/// Required for intercepting media keys and suppressing system HUD
final class PermissionManager {
    static let shared = PermissionManager()
    
    /// Cached trust state to avoid false negatives when TCC hasn't synced
    private var cachedTrustState: Bool = false
    private var lastCheckTime: Date = .distantPast
    private let cacheTimeout: TimeInterval = 1.0 // Re-check every second
    
    private init() {
        // Initial check without prompting
        cachedTrustState = AXIsProcessTrusted()
    }
    
    /// Returns true if accessibility permissions are granted
    /// Uses caching to avoid false negatives when TCC database hasn't synced
    var isAccessibilityGranted: Bool {
        // Check cache validity
        let now = Date()
        if now.timeIntervalSince(lastCheckTime) > cacheTimeout {
            let trusted = AXIsProcessTrusted()
            if trusted {
                cachedTrustState = true
            }
            lastCheckTime = now
        }
        return cachedTrustState || AXIsProcessTrusted()
    }
    
    /// Request accessibility permission with optional system prompt
    /// - Parameter prompt: If true, shows system settings dialog if not already granted
    /// - Returns: True if permission is already granted
    @discardableResult
    func requestAccessibilityPermission(prompt: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if trusted {
            cachedTrustState = true
        }
        
        print("🔐 Accessibility permission check: \(trusted ? "granted" : "not granted") (prompt=\(prompt))")
        return trusted
    }
    
    /// Opens System Settings to the Accessibility pane
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Monitors for permission changes and calls the handler when granted
    /// - Parameters:
    ///   - interval: How often to check (default 1 second)
    ///   - onGranted: Called when permission is granted
    /// - Returns: Timer that can be invalidated to stop monitoring
    func monitorForPermissionGrant(interval: TimeInterval = 1.0, onGranted: @escaping () -> Void) -> Timer {
        return Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.isAccessibilityGranted {
                timer.invalidate()
                onGranted()
            }
        }
    }
    
    /// Force refresh the cached permission state
    func refreshPermissionState() {
        cachedTrustState = AXIsProcessTrusted()
        lastCheckTime = Date()
        print("🔄 Permission state refreshed: \(cachedTrustState)")
    }
}
