//
//  MediaKeyInterceptor.swift
//  VolumeGlass
//
//  Created by Aarush Prakash on 2/15/26.
//

import AppKit
import CoreGraphics
import Foundation

/// Media key types from IOKit
private let NX_KEYTYPE_SOUND_UP: UInt32 = 0
private let NX_KEYTYPE_SOUND_DOWN: UInt32 = 1
private let NX_KEYTYPE_MUTE: UInt32 = 7

// Transport control keys - MUST be passed through to system, never intercepted
private let NX_KEYTYPE_PLAY: UInt32 = 16
private let NX_KEYTYPE_FAST: UInt32 = 17       // Next track
private let NX_KEYTYPE_REWIND: UInt32 = 18     // Previous track (some keyboards)
private let NX_KEYTYPE_PREVIOUS: UInt32 = 19   // Previous track (other keyboards)

/// Intercepts volume keys to prevent system HUD from appearing
/// Requires Accessibility permissions to function
final class MediaKeyInterceptor {
    static let shared = MediaKeyInterceptor()
    
    // Made internal for callback access
    var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
    
    // Dedicated background queue for event tap (prevents main thread contention on M4 Macs)
    private var eventTapQueue: DispatchQueue?
    private var eventTapRunLoop: CFRunLoop?
    
    /// Reference to the volume monitor for handling volume changes
    weak var volumeMonitor: VolumeMonitor?
    
    /// Callbacks for key events (optional, for additional UI updates)
    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?
    var onMute: (() -> Void)?
    
    /// Volume step size (matches the app's default step)
    private let volumeStep: Float = 0.05
    
    private init() {}
    
    /// Start intercepting media keys
    /// Returns true if successfully started, false if permissions denied
    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        
        // Check for Accessibility permissions using cached grant
        // Avoids false negatives when TCC hasn't synced yet
        guard PermissionManager.shared.isAccessibilityGranted else {
            print("MediaKeyInterceptor: Accessibility permissions not granted. Grant in System Settings > Privacy & Security > Accessibility")
            return false
        }
        
        // Create event tap for system-defined events (media keys)
        // CGEventType.systemDefined is raw value 14
        let systemDefinedType = CGEventType(rawValue: 14)!
        let eventMask: CGEventMask = (1 << systemDefinedType.rawValue)
        
        // NOTE: Using cgSessionEventTap (not cgAnnotatedSessionEventTap)
        // The annotated tap breaks transport controls (play/pause/next/previous) on macOS Tahoe
        // by intercepting events before they reach the media subsystem, even when we passthrough.
        // cgSessionEventTap works correctly for all keys.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: mediaKeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("MediaKeyInterceptor: Failed to create event tap")
            return false
        }
        
        eventTap = tap
        print("MediaKeyInterceptor: Using session event tap")
        return setupEventTapRunLoop(tap: tap)
    }
    
    /// Sets up the run loop for the event tap on a dedicated background queue
    private func setupEventTapRunLoop(tap: CFMachPort) -> Bool {
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        guard let source = runLoopSource else {
            print("MediaKeyInterceptor: Failed to create run loop source")
            return false
        }
        
        // Run on dedicated background queue to avoid main thread contention
        // This fixes double HUD issue on M4 Macs where macOS Tahoe has stricter timing
        let queue = DispatchQueue(label: "com.volumeglass.MediaKeyTap", qos: .userInteractive)
        self.eventTapQueue = queue
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.eventTapRunLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(self.eventTapRunLoop, source, .commonModes)
            
            // Enable tap and verify it's running
            CGEvent.tapEnable(tap: tap, enable: true)
            
            // Verify tap is enabled
            if CFMachPortIsValid(tap) {
                print("MediaKeyInterceptor: Event tap verified as valid and enabled")
            } else {
                print("⚠️ MediaKeyInterceptor: Event tap created but not valid!")
            }
            
            CFRunLoopRun()
        }
        
        isRunning = true
        print("MediaKeyInterceptor: Started successfully on dedicated queue")
        return true
    }
    
    /// Stop intercepting media keys
    func stop() {
        guard isRunning else { return }
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        // Stop the dedicated run loop
        if let runLoop = eventTapRunLoop {
            CFRunLoopStop(runLoop)
        }
        
        if let source = runLoopSource, let runLoop = eventTapRunLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        eventTapQueue = nil
        eventTapRunLoop = nil
        isRunning = false
        print("MediaKeyInterceptor: Stopped")
    }
    
    /// Handle a media key event
    /// Returns true if the event was handled (should be suppressed)
    /// Returns false if the event should pass through to the system
    fileprivate func handleMediaKey(keyCode: UInt32, keyDown: Bool, optionHeld: Bool) -> Bool {
        // Only handle volume keys
        let isVolumeKey = keyCode == NX_KEYTYPE_SOUND_UP ||
                          keyCode == NX_KEYTYPE_SOUND_DOWN ||
                          keyCode == NX_KEYTYPE_MUTE
        
        guard isVolumeKey else {
            // Let non-volume keys pass through to system
            return false
        }
        
        // Only act on key down events
        guard keyDown else { return true }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch keyCode {
            case NX_KEYTYPE_SOUND_UP:
                self.handleVolumeUp(fineStep: optionHeld)
                self.onVolumeUp?()
                
            case NX_KEYTYPE_SOUND_DOWN:
                self.handleVolumeDown(fineStep: optionHeld)
                self.onVolumeDown?()
                
            case NX_KEYTYPE_MUTE:
                self.handleMuteToggle()
                self.onMute?()
                
            default:
                break
            }
        }
        
        return true
    }
    
    // MARK: - Volume Control
    
    private func effectiveVolumeStep(fineStep: Bool) -> Float {
        guard fineStep else { return volumeStep }
        let divisor = max(1.0, SetupState.currentFineStepDivisor)
        return volumeStep / divisor
    }
    
    private func handleVolumeUp(fineStep: Bool = false) {
        guard let monitor = volumeMonitor else {
            print("⚠️ MediaKeyInterceptor: No volume monitor attached")
            return
        }
        let step = effectiveVolumeStep(fineStep: fineStep)
        let newVolume = min(1.0, monitor.currentVolume + step)
        print("🔊 MediaKeyInterceptor: Volume Up -> \(newVolume)")
        monitor.setSystemVolume(newVolume)
    }
    
    private func handleVolumeDown(fineStep: Bool = false) {
        guard let monitor = volumeMonitor else {
            print("⚠️ MediaKeyInterceptor: No volume monitor attached")
            return
        }
        let step = effectiveVolumeStep(fineStep: fineStep)
        let newVolume = max(0.0, monitor.currentVolume - step)
        print("🔉 MediaKeyInterceptor: Volume Down -> \(newVolume)")
        monitor.setSystemVolume(newVolume)
    }
    
    private func handleMuteToggle() {
        guard let monitor = volumeMonitor else {
            print("⚠️ MediaKeyInterceptor: No volume monitor attached")
            return
        }
        print("🔇 MediaKeyInterceptor: Mute Toggle")
        monitor.toggleMute()
    }
}

/// C callback function for CGEventTap
/// Uses a safe pattern to extract NSEvent data without memory issues
private func mediaKeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    
    // Handle tap being disabled (system temporarily disables if we take too long)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        // CRITICAL CHECK: Before re-enabling, verify we still have permission.
        // If the user revoked permissions, the system disables the tap.
        // If we blindly re-enable it here without checking, we create a tight loop
        // fighting the system, which freezes the WindowServer/whole Mac.
        if !PermissionManager.shared.isAccessibilityGranted {
            print("❌ MediaKeyInterceptor: Tap disabled and permissions revoked. Stopping interceptor to prevent system freeze.")
            
            // We must stop the interceptor. Since we are in a C callback which might be on a background thread,
            // we should dispatch the stop call safely.
            DispatchQueue.main.async {
                MediaKeyInterceptor.shared.stop()
            }
            // Return event to system as is
            return Unmanaged.passUnretained(event)
        }
        
        // Tap temporarily disabled by system - this is normal, silently re-enable
        if let tap = MediaKeyInterceptor.shared.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }
    
    // CRASH FIX: NSEvent(cgEvent:) on background thread crashes when Caps Lock is involved!
    // When Caps Lock is pressed, NSEvent init triggers TSM (Text Services Manager)
    // Caps Lock handling which REQUIRES the main thread. This causes:
    // _dispatch_assert_queue_fail in TISIsDesignatedRomanModeCapsLockSwitchAllowed
    //
    // Solution: Create NSEvent on main thread synchronously. Media key events are
    // infrequent (user key presses), so the sync dispatch latency is acceptable.
    
    // Only process system-defined events (raw value 14)
    guard type.rawValue == 14 else {
        return Unmanaged.passUnretained(event)
    }
    
    // Extract NSEvent data on main thread to avoid TSM Caps Lock crash
    var nsEventData1: Int = 0
    var nsEventSubtype: Int16 = 0
    
    DispatchQueue.main.sync {
        if let nsEvent = NSEvent(cgEvent: event) {
            nsEventData1 = nsEvent.data1
            nsEventSubtype = nsEvent.subtype.rawValue
        }
    }
    
    // Check subtype - we only handle NX_SUBTYPE_AUX_CONTROL_BUTTONS (8)
    guard nsEventSubtype == 8 else {
        return Unmanaged.passUnretained(event)
    }
    
    // Extract key data from data1
    let keyCode = UInt32((nsEventData1 & 0xFFFF0000) >> 16)
    let keyFlags = UInt32(nsEventData1 & 0x0000FFFF)
    let keyState = ((keyFlags & 0xFF00) >> 8)
    
    let keyDown = keyState == 0x0A || keyState == 0x08
    let keyUp = keyState == 0x0B
    let keyRepeat = (keyFlags & 0x1) != 0
    let shouldProcess = (keyDown || keyRepeat) && !keyUp
    let optionHeld = event.flags.contains(.maskAlternate)
    
    // CRITICAL: Transport control keys MUST pass through to system immediately
    // These are: PLAY (16), NEXT/FAST (17), PREVIOUS/REWIND (18, 19)
    // On macOS Tahoe, cgAnnotatedSessionEventTap intercepts these before the media system
    // We MUST NOT touch them at all - return immediately without any processing
    let transportKeys: [UInt32] = [
        NX_KEYTYPE_PLAY,
        NX_KEYTYPE_FAST,
        NX_KEYTYPE_REWIND,
        NX_KEYTYPE_PREVIOUS
    ]
    
    if transportKeys.contains(keyCode) {
        // Pass through transport controls to system media handlers
        return Unmanaged.passUnretained(event)
    }
    
    // Check if this is a volume key we handle
    let handledKeys: [UInt32] = [
        NX_KEYTYPE_SOUND_UP,
        NX_KEYTYPE_SOUND_DOWN,
        NX_KEYTYPE_MUTE
    ]
    
    guard handledKeys.contains(keyCode) else {
        return Unmanaged.passUnretained(event)
    }
    
    // Get the interceptor instance
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    
    let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
    
    // Handle the key event
    if interceptor.handleMediaKey(keyCode: keyCode, keyDown: shouldProcess, optionHeld: optionHeld) {
        // Return nil to suppress system HUD
        return nil
    }
    
    // Let event pass through
    return Unmanaged.passUnretained(event)
}
