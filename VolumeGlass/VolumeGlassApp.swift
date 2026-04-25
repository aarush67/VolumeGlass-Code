import SwiftUI
import Carbon
import Combine

// MARK: - License Check State

enum LicenseCheckState {
    case checking
    case licensed
    case needsLicense
    case trialExpired
}

@main
struct VolumeGlassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var setupState = SetupState()
    @StateObject private var licenseManager = LicenseManager.shared
    @State private var licenseCheckState: LicenseCheckState = .checking
    
    init() {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UpdateChecker.shared.startBackgroundChecking()
        if let bundleID = Bundle.main.bundleIdentifier {
            let savedAppStatePath = NSHomeDirectory() + "/Library/Saved Application State/" + bundleID + ".savedState"
            try? FileManager.default.removeItem(atPath: savedAppStatePath)
        }
        
        let userDefaults = UserDefaults.standard
        let dictionary = userDefaults.dictionaryRepresentation()
        for key in dictionary.keys {
            if key.contains("NSWindow Frame") || key.contains("window frame") {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup("Setup") {
            Group {
                switch licenseCheckState {
                case .checking:
                    licenseCheckingView
                case .needsLicense:
                    LicenseView(licenseManager: licenseManager) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            licenseCheckState = .licensed
                        }
                    }
                case .trialExpired:
                    TrialExpiredView(licenseManager: licenseManager) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            licenseCheckState = .licensed
                        }
                    }
                case .licensed:
                    if setupState.isSetupComplete {
                        EmptyView()
                            .frame(width: 0, height: 0)
                            .hidden()
                            .onAppear {
                                print("📱 Setup complete view appeared, starting volume monitoring")
                                appDelegate.startVolumeMonitoring(with: setupState)
                                
                                // Close the main window after a short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let window = NSApplication.shared.windows.first(where: { $0.title == "Setup" }) {
                                        print("🔒 Closing setup window")
                                        window.close()
                                    }
                                }
                            }
                    } else {
                        SetupWalkthroughView(setupState: setupState)
                            .onAppear {
                                appDelegate.setupState = setupState
                            }
                    }
                }
            }
            .onAppear {
                performLicenseCheck()
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 720)
        .restorationBehavior(.disabled)
        .windowToolbarStyle(.unifiedCompact)
        .onChange(of: setupState.isSetupComplete) { isComplete in
            if isComplete {
                print("⚙️ Setup completed, isSetupComplete changed to true")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    appDelegate.startVolumeMonitoring(with: setupState)
                    
                    // Close the setup window
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if let window = NSApplication.shared.windows.first(where: { $0.title == "Setup" }) {
                            print("🔒 Closing setup window after completion")
                            window.close()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - License Checking View
    
    private var licenseCheckingView: some View {
        ZStack {
            Color(white: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? 0.1 : 0.94)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .scaleEffect(0.8)
                
                Text("Checking license…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - License Check
    
    private func performLicenseCheck() {
        print("🔑 Checking license on launch…")
        licenseManager.checkLicenseOnLaunch { isValid in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                if isValid {
                    print("✅ License valid — proceeding")
                    licenseCheckState = .licensed
                } else if licenseManager.licenseStatus == .expired || licenseManager.hasUsedTrial {
                    print("⏰ Trial expired")
                    licenseCheckState = .trialExpired
                } else {
                    print("🔒 No valid license")
                    licenseCheckState = .needsLicense
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var volumeMonitor: VolumeMonitor?
    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    private var statusItem: NSStatusItem?
    var setupState: SetupState?
    private var isUpdatingSettings = false
    private var isHandlingTrialExpiration = false
    
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var hotKeyEventHandler: EventHandlerRef?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var accessibilityPromptedOnce = false
    private var permissionMonitorTimer: Timer?
    private var trialExpirationObserver: AnyCancellable?
    
    @discardableResult
    func requestAccessibilityPermission(prompt: Bool = true) -> Bool {
        let trusted = PermissionManager.shared.requestAccessibilityPermission(prompt: prompt)
        accessibilityPromptedOnce = accessibilityPromptedOnce || prompt
        return trusted
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.set(false, forKey: "ApplePersistenceIgnoreState")
        
        _ = requestAccessibilityPermission(prompt: true)
        setupKeyboardMonitoring()
        setupStatusBar()
        
        // Rebuild menu when an update becomes available so badge appears
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildMenuFromNotification),
            name: Notification.Name("VolumeGlassUpdateAvailable"),
            object: nil
        )
        
        // Listen for settings changes from the settings window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsWindowDidChange),
            name: NSNotification.Name("SettingsWindowChanged"),
            object: nil
        )
        
        for window in NSApp.windows {
            window.isRestorable = false
        }
        
        // Observe trial expiration while app is running
        observeTrialExpiration()
        
        // Observe license activation from expired popup to restart monitoring
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLicenseActivatedAfterExpiration),
            name: NSNotification.Name("TrialExpiredLicenseActivated"),
            object: nil
        )
        
        // Re-register Carbon hotkeys when user changes shortcuts
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutsDidChange),
            name: NSNotification.Name("ShortcutsChanged"),
            object: nil
        )
        
        // If setup is already complete from a previous launch, check license first
        // Volume monitoring will start once the license is validated in the SwiftUI body
        let isSetupComplete = UserDefaults.standard.bool(forKey: "isSetupComplete")
        if isSetupComplete {
            print("🚀 Setup was already complete — license check will gate volume monitoring")
            LicenseManager.shared.checkLicenseOnLaunch { [weak self] isValid in
                guard let self = self else { return }
                if isValid {
                    print("✅ License valid on launch, starting volume monitoring")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let tempSetupState = SetupState()
                        self.startVolumeMonitoring(with: tempSetupState)
                    }
                } else {
                    print("🔒 License invalid on launch — waiting for user action")
                }
            }
        }
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "speaker.wave.3", accessibilityDescription: "VolumeGlass") {
                let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
                button.image = image.withSymbolConfiguration(config)
            }
        }
        
        rebuildMenu()
    }
    
    private func rebuildMenu() {
        let menu = NSMenu()
        
        // Volume display at top
        let volumeTitle: String
        if let monitor = volumeMonitor {
            let pct = Int(monitor.currentVolume * 100)
            let icon: String
            if monitor.isMuted {
                icon = "speaker.slash.fill"
            } else if pct > 66 {
                icon = "speaker.wave.3.fill"
            } else if pct > 33 {
                icon = "speaker.wave.2.fill"
            } else if pct > 0 {
                icon = "speaker.wave.1.fill"
            } else {
                icon = "speaker.fill"
            }
            volumeTitle = "\(pct)%"
            
            let volumeItem = NSMenuItem(title: volumeTitle, action: nil, keyEquivalent: "")
            if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
                volumeItem.image = image.withSymbolConfiguration(config)
            }
            volumeItem.isEnabled = false
            menu.addItem(volumeItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Position submenu
        let positionItem = NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
        if let image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            positionItem.image = image.withSymbolConfiguration(config)
        }
        let positionSubmenu = NSMenu()
        
        for position in VolumeBarPosition.allCases {
            let item = NSMenuItem(title: position.displayName, action: #selector(changePosition(_:)), keyEquivalent: "")
            item.representedObject = position
            if setupState?.selectedPosition == position {
                item.state = .on
            }
            positionSubmenu.addItem(item)
        }
        positionItem.submenu = positionSubmenu
        menu.addItem(positionItem)
        
        // Size submenu
        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        if let image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            sizeItem.image = image.withSymbolConfiguration(config)
        }
        let sizeSubmenu = NSMenu()
        
        let sizes: [(String, CGFloat)] = [
            ("Small (50%)", 0.5),
            ("Medium (75%)", 0.75),
            ("Default (100%)", 1.0),
            ("Large (125%)", 1.25),
            ("Extra Large (150%)", 1.5),
            ("Huge (200%)", 2.0)
        ]
        
        for (name, size) in sizes {
            let item = NSMenuItem(title: name, action: #selector(changeSize(_:)), keyEquivalent: "")
            item.representedObject = size
            if let currentSize = setupState?.barSize, abs(currentSize - size) < 0.01 {
                item.state = .on
            }
            sizeSubmenu.addItem(item)
        }
        sizeItem.submenu = sizeSubmenu
        menu.addItem(sizeItem)
        
        // Notch display toggles (only show if a notch screen is connected)
        if NSScreen.screens.contains(where: { NotchAttachedWindow.screenHasNotch($0) }) {
            let notchBarItem = NSMenuItem(title: "Notch Volume Bar", action: #selector(toggleNotchBar(_:)), keyEquivalent: "")
            if let image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                notchBarItem.image = image.withSymbolConfiguration(config)
            }
            notchBarItem.state = setupState?.showNotchBar == true ? .on : .off
            menu.addItem(notchBarItem)

            let notchPillItem = NSMenuItem(title: "Volume Indicator Pill", action: #selector(toggleNotch(_:)), keyEquivalent: "")
            if let image = NSImage(systemSymbolName: "capsule", accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                notchPillItem.image = image.withSymbolConfiguration(config)
            }
            notchPillItem.state = setupState?.showInNotch == true ? .on : .off
            menu.addItem(notchPillItem)
        }

        menu.addItem(NSMenuItem.separator())
        
        // Keyboard shortcuts
        let keyboardHintsItem = NSMenuItem(title: "Keyboard Shortcuts", action: nil, keyEquivalent: "")
        if let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            keyboardHintsItem.image = image.withSymbolConfiguration(config)
        }
        let keyboardSubmenu = NSMenu()
        keyboardSubmenu.addItem(withTitle: "⌘⇧↑  Volume Up", action: nil, keyEquivalent: "")
        keyboardSubmenu.addItem(withTitle: "⌘⇧↓  Volume Down", action: nil, keyEquivalent: "")
        keyboardSubmenu.addItem(withTitle: "⌘⇧M  Toggle Mute", action: nil, keyEquivalent: "")
        keyboardHintsItem.submenu = keyboardSubmenu
        menu.addItem(keyboardHintsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // License info
        let lm = LicenseManager.shared
        let licenseItem: NSMenuItem
        switch lm.licenseStatus {
        case .active:
            licenseItem = NSMenuItem(title: "License: Active", action: nil, keyEquivalent: "")
            if let img = NSImage(systemSymbolName: "checkmark.seal.fill", accessibilityDescription: nil) {
                let cfg = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                licenseItem.image = img.withSymbolConfiguration(cfg)
            }
        case .trial:
            let days = lm.trialDaysRemaining
            licenseItem = NSMenuItem(title: "Trial: \(days) day\(days == 1 ? "" : "s") left", action: nil, keyEquivalent: "")
            if let img = NSImage(systemSymbolName: "clock", accessibilityDescription: nil) {
                let cfg = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                licenseItem.image = img.withSymbolConfiguration(cfg)
            }
        default:
            licenseItem = NSMenuItem(title: "License: Inactive", action: nil, keyEquivalent: "")
            if let img = NSImage(systemSymbolName: "xmark.seal", accessibilityDescription: nil) {
                let cfg = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                licenseItem.image = img.withSymbolConfiguration(cfg)
            }
        }
        licenseItem.isEnabled = false
        menu.addItem(licenseItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        if let img = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            settingsItem.image = img.withSymbolConfiguration(cfg)
        }
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem(title: "About VolumeGlass", action: #selector(showAbout), keyEquivalent: ""))
        
        // Check for Updates
        let checker = UpdateChecker.shared
        let updateTitle = checker.updateAvailable
            ? "Update Available — v\(checker.latestVersion ?? "")"
            : "Check for Updates…"
        let updateItem = NSMenuItem(title: updateTitle, action: #selector(checkForUpdates), keyEquivalent: "")
        if let img = NSImage(systemSymbolName: checker.updateAvailable ? "arrow.down.app.fill" : "arrow.clockwise", accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            updateItem.image = img.withSymbolConfiguration(cfg)
        }
        menu.addItem(updateItem)
        
        menu.addItem(NSMenuItem(title: "Quit VolumeGlass", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func changePosition(_ sender: NSMenuItem) {
        guard let position = sender.representedObject as? VolumeBarPosition else { return }
        setupState?.updatePosition(position)
        rebuildMenu()
        restartVolumeMonitoring()
    }
    
    @objc private func changeSize(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? CGFloat else { return }
        setupState?.updateSize(size)
        rebuildMenu()
        restartVolumeMonitoring()
    }

    @objc private func toggleNotch(_ sender: NSMenuItem) {
        let newValue = !(setupState?.showInNotch ?? false)
        setupState?.updateShowInNotch(newValue)
        rebuildMenu()
        restartVolumeMonitoring()
    }

    @objc private func toggleNotchBar(_ sender: NSMenuItem) {
        let newValue = !(setupState?.showNotchBar ?? false)
        setupState?.updateShowNotchBar(newValue)
        rebuildMenu()
        restartVolumeMonitoring()
    }
    
    private func restartVolumeMonitoring() {
        guard let setupState = setupState else { return }
        
        print("🔄 Restarting volume monitoring with new settings")
        print("   Position: \(setupState.selectedPosition.displayName)")
        print("   Size: \(setupState.barSize)")
        
        isUpdatingSettings = true
        
        // Destroy old overlays first, but do it safely without holding references
        if let oldMonitor = volumeMonitor {
            print("🗑️ Hiding old overlays")
            for window in oldMonitor.overlayWindows {
                window.orderOut(nil)
            }
            oldMonitor.overlayWindows.removeAll()
            for window in oldMonitor.notchWindows {
                window.orderOut(nil)
            }
            oldMonitor.notchWindows.removeAll()
            for window in oldMonitor.notchAttachedWindows {
                window.orderOut(nil)
            }
            oldMonitor.notchAttachedWindows.removeAll()
        }
        volumeMonitor = nil
        
        // Give time for old windows to deallocate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🆕 Creating new VolumeMonitor with updated settings")
            let newMonitor = VolumeMonitor()
            newMonitor.setupState = setupState
            self.volumeMonitor = newMonitor
            
            // Reconnect MediaKeyInterceptor to the new monitor
            MediaKeyInterceptor.shared.volumeMonitor = newMonitor

            print("✅ Creating new overlays")
            newMonitor.createVolumeOverlay()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isUpdatingSettings = false
                print("✅ Settings update complete")
            }
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Trial Expiration Observer
    
    private func observeTrialExpiration() {
        // Use Combine to observe the published property
        trialExpirationObserver = LicenseManager.shared.$trialExpiredWhileRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] expired in
                guard expired else { return }
                self?.handleTrialExpiredWhileRunning()
            }
    }
    
    private func handleTrialExpiredWhileRunning() {
        print("⏰ Trial expired during session — showing expiration popup and stopping volume monitoring")
        
        // Set flag so applicationShouldTerminateAfterLastWindowClosed won't quit us
        isHandlingTrialExpiration = true
        
        // Show popup FIRST (opens a window) so the app has a window when we hide overlays
        TrialExpiredWindowController.shared.showExpiredPopup()
        
        // Now tear down monitoring — app still alive because popup window is open
        stopVolumeMonitoringForExpiration()
    }
    
    /// Tears down volume monitoring, overlays, and media key interceptor.
    private func stopVolumeMonitoringForExpiration() {
        MediaKeyInterceptor.shared.stop()
        
        if let monitor = volumeMonitor {
            for window in monitor.overlayWindows {
                window.orderOut(nil)
            }
            monitor.overlayWindows.removeAll()
            for window in monitor.notchWindows {
                window.orderOut(nil)
            }
            monitor.notchWindows.removeAll()
            for window in monitor.notchAttachedWindows {
                window.orderOut(nil)
            }
            monitor.notchAttachedWindows.removeAll()
        }
        volumeMonitor = nil
        
        print("🛑 Volume monitoring stopped due to trial expiration")
    }
    
    @objc private func shortcutsDidChange() {
        print("⌨️ Shortcuts changed — re-registering hotkeys")
        registerCarbonHotkeys()
    }
    
    @objc private func handleLicenseActivatedAfterExpiration() {
        print("✅ License activated after trial expiration — restarting volume monitoring")
        isHandlingTrialExpiration = false
        guard let state = setupState else {
            let tempState = SetupState()
            startVolumeMonitoring(with: tempState)
            return
        }
        startVolumeMonitoring(with: state)
    }
    
    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc private func openSettings() {
        guard let state = setupState else { return }
        SettingsWindowController.shared.showSettings(setupState: state)
    }
    
    @objc private func checkForUpdates() {
        // Activate app so the floating panel is visible even in accessory mode
        NSApp.activate(ignoringOtherApps: true)
        UpdateChecker.shared.checkAndNotify()
    }
    
    @objc private func rebuildMenuFromNotification() {
        rebuildMenu()
    }
    
    @objc private func settingsWindowDidChange() {
        rebuildMenu()
        restartVolumeMonitoring()
    }
    
    private func setupKeyboardMonitoring() {
        guard requestAccessibilityPermission(prompt: true) else {
            print("⚠️ Accessibility permission not granted; global shortcuts disabled")
            return
        }
        registerCarbonHotkeys()
        
        // Add GLOBAL event monitor for system-defined volume keys
        print("🎹 Setting up global keyboard monitoring")
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .systemDefined]) { [weak self] event in
            guard let self = self else { return }
            
            // Handle system volume keys (media keys)
            if event.type == .systemDefined {
                let keyCode = Int32((event.data1 & 0xFFFF0000) >> 16)
                let keyFlags = (event.data1 & 0x0000FFFF)
                let keyPressed = ((keyFlags & 0xFF00) >> 8) == 0xA
                
                print("🎵 [GLOBAL] System key: keyCode=\(keyCode), pressed=\(keyPressed)")
                
                if keyPressed {
                    switch keyCode {
                    case NX_KEYTYPE_SOUND_UP:
                        print("🔊 [GLOBAL] Volume Up detected via media key")
                        self.handleVolumeUp()
                    case NX_KEYTYPE_SOUND_DOWN:
                        print("🔊 [GLOBAL] Volume Down detected via media key")
                        self.handleVolumeDown()
                    case NX_KEYTYPE_MUTE:
                        print("🔊 [GLOBAL] Mute detected via media key")
                        self.handleMuteToggle()
                    default:
                        break
                    }
                }
            }
            
            // Handle configured keyboard shortcuts (reads from user settings)
            if event.type == .keyDown {
                let sc = SetupState.currentShortcuts
                let keyCode = event.keyCode
                let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
                let upMods   = NSEvent.ModifierFlags(rawValue: sc.volumeUp.modifiers).intersection([.command, .shift, .option, .control])
                let downMods = NSEvent.ModifierFlags(rawValue: sc.volumeDown.modifiers).intersection([.command, .shift, .option, .control])
                let muteMods = NSEvent.ModifierFlags(rawValue: sc.mute.modifiers).intersection([.command, .shift, .option, .control])
                if keyCode == sc.volumeUp.keyCode && flags == upMods {
                    self.handleVolumeUp()
                } else if keyCode == sc.volumeDown.keyCode && flags == downMods {
                    self.handleVolumeDown()
                } else if keyCode == sc.mute.keyCode && flags == muteMods {
                    self.handleMuteToggle()
                }
            }
        }
        
        // Add LOCAL event monitor as fallback (for accessory apps)
        print("🎹 Setting up local keyboard monitoring (fallback)")
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .systemDefined]) { [weak self] event in
            guard let self = self else { return event }
            
            // Handle system volume keys (media keys)
            if event.type == .systemDefined {
                let keyCode = Int32((event.data1 & 0xFFFF0000) >> 16)
                let keyFlags = (event.data1 & 0x0000FFFF)
                let keyPressed = ((keyFlags & 0xFF00) >> 8) == 0xA
                
                print("🎵 [LOCAL] System key: keyCode=\(keyCode), pressed=\(keyPressed)")
                
                if keyPressed {
                    switch keyCode {
                    case NX_KEYTYPE_SOUND_UP:
                        print("🔊 [LOCAL] Volume Up detected via media key")
                        self.handleVolumeUp()
                        return nil  // Consume event
                    case NX_KEYTYPE_SOUND_DOWN:
                        print("🔊 [LOCAL] Volume Down detected via media key")
                        self.handleVolumeDown()
                        return nil  // Consume event
                    case NX_KEYTYPE_MUTE:
                        print("🔊 [LOCAL] Mute detected via media key")
                        self.handleMuteToggle()
                        return nil  // Consume event
                    default:
                        break
                    }
                }
            }
            
            // Handle configured keyboard shortcuts (reads from user settings)
            if event.type == .keyDown {
                let sc = SetupState.currentShortcuts
                let keyCode = event.keyCode
                let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
                let upMods   = NSEvent.ModifierFlags(rawValue: sc.volumeUp.modifiers).intersection([.command, .shift, .option, .control])
                let downMods = NSEvent.ModifierFlags(rawValue: sc.volumeDown.modifiers).intersection([.command, .shift, .option, .control])
                let muteMods = NSEvent.ModifierFlags(rawValue: sc.mute.modifiers).intersection([.command, .shift, .option, .control])
                if keyCode == sc.volumeUp.keyCode && flags == upMods {
                    self.handleVolumeUp()
                    return nil
                } else if keyCode == sc.volumeDown.keyCode && flags == downMods {
                    self.handleVolumeDown()
                    return nil
                } else if keyCode == sc.mute.keyCode && flags == muteMods {
                    self.handleMuteToggle()
                    return nil
                }
            }
            
            return event  // Let other apps handle if not consumed
        }
    }
    
    private func ensureAccessibilityPermission() -> Bool {
        return requestAccessibilityPermission(prompt: true)
    }
    
    private func registerCarbonHotkeys() {
        // Clean up any existing hotkeys before installing new ones
        unregisterCarbonHotkeys()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { (handlerCall, event, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let id = hotKeyID.id
            guard let userData = userData else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            switch id {
            case 1: delegate.handleVolumeUp()
            case 2: delegate.handleVolumeDown()
            case 3: delegate.handleMuteToggle()
            default: break
            }
            return noErr
        }, Int(UInt32(1)), &eventType, Unmanaged.passUnretained(self).toOpaque(), &hotKeyEventHandler)
        guard status == noErr else {
            print("❌ Failed to install hotkey handler: \(status)")
            return
        }
        let shortcuts = SetupState.currentShortcuts
        let hotkeyDefs: [(UInt32, UInt32, UInt32)] = [
            (UInt32(shortcuts.volumeUp.keyCode), shortcuts.volumeUp.carbonModifiers, 1),
            (UInt32(shortcuts.volumeDown.keyCode), shortcuts.volumeDown.carbonModifiers, 2),
            (UInt32(shortcuts.mute.keyCode), shortcuts.mute.carbonModifiers, 3)
        ]
        for (keyCode, modifiers, id) in hotkeyDefs {
            var hotKeyRef: EventHotKeyRef?
            var hotKeyID = EventHotKeyID(signature: OSType(0x56474854), id: id) // "VGHT"
            let err = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
            if err == noErr, let ref = hotKeyRef {
                hotKeyRefs.append(ref)
            } else {
                print("❌ Failed to register hotkey id=\(id) err=\(err)")
            }
        }
    }
    
    private func unregisterCarbonHotkeys() {
        if let handler = hotKeyEventHandler {
            RemoveEventHandler(handler)
            hotKeyEventHandler = nil
        }
        for ref in hotKeyRefs {
            if let ref = ref { UnregisterEventHotKey(ref) }
        }
        hotKeyRefs.removeAll()
    }
    
    private func startGlobalEventTap() {
        // Plain-arrow volume control removed; shortcuts are handled by Carbon hotkeys + NSEvent monitors.
    }
    
    private func stopGlobalEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTapSource = nil
        eventTap = nil
    }
    
    private func handleVolumeUp() {
        print("🔊 handleVolumeUp called")
        guard let volumeMonitor = volumeMonitor else {
            print("⚠️ No volume monitor available")
            return
        }
        let newVolume = min(1.0, volumeMonitor.currentVolume + 0.05)
        print("📈 Setting volume to: \(newVolume)")
        volumeMonitor.setSystemVolume(Float(newVolume))
    }
    
    private func handleVolumeDown() {
        print("🔊 handleVolumeDown called")
        guard let volumeMonitor = volumeMonitor else {
            print("⚠️ No volume monitor available")
            return
        }
        let newVolume = max(0.0, volumeMonitor.currentVolume - 0.05)
        print("📉 Setting volume to: \(newVolume)")
        volumeMonitor.setSystemVolume(Float(newVolume))
    }
    
    private func handleMuteToggle() {
        print("🔇 handleMuteToggle called")
        volumeMonitor?.toggleMute()
    }
    
    func startVolumeMonitoring(with setupState: SetupState) {
        self.setupState = setupState
        
        if volumeMonitor != nil {
            // Stop old interceptor before creating new monitor
            MediaKeyInterceptor.shared.stop()
            volumeMonitor = nil
        }
        
        NSApp.setActivationPolicy(.accessory)
        hideAllWindows()
        
        volumeMonitor = VolumeMonitor()
        volumeMonitor?.setupState = setupState
        volumeMonitor?.createVolumeOverlay()
        
        // Start MediaKeyInterceptor to suppress system HUD
        startMediaKeyInterceptor()
        
        rebuildMenu()
    }
    
    /// Starts the MediaKeyInterceptor if accessibility permission is granted
    private func startMediaKeyInterceptor() {
        // Connect interceptor to volume monitor
        MediaKeyInterceptor.shared.volumeMonitor = volumeMonitor
        
        if PermissionManager.shared.isAccessibilityGranted {
            // Permission already granted, start immediately
            let success = MediaKeyInterceptor.shared.start()
            print("🎹 MediaKeyInterceptor started: \(success)")
        } else {
            // Monitor for permission grant
            print("🔐 Waiting for accessibility permission...")
            permissionMonitorTimer?.invalidate()
            permissionMonitorTimer = PermissionManager.shared.monitorForPermissionGrant { [weak self] in
                guard let self = self else { return }
                print("✅ Accessibility permission granted, starting MediaKeyInterceptor")
                MediaKeyInterceptor.shared.volumeMonitor = self.volumeMonitor
                let success = MediaKeyInterceptor.shared.start()
                print("🎹 MediaKeyInterceptor started: \(success)")
            }
        }
    }
    
    private func hideAllWindows() {
        for window in NSApp.windows {
            window.orderOut(nil)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate if we're just updating settings
        if isUpdatingSettings {
            print("⚙️ Settings update in progress, not terminating")
            return false
        }
        
        // Don't terminate if we're handling trial expiration (popup is about to appear / is visible)
        if isHandlingTrialExpiration || TrialExpiredWindowController.shared.isShowing {
            print("⏰ Trial expiration popup active, not terminating")
            return false
        }
        
        // Only terminate if there's no volume monitor AND we're not in the middle of updates
        let shouldTerminate = volumeMonitor == nil
        print("🔍 applicationShouldTerminateAfterLastWindowClosed: \(shouldTerminate)")
        return shouldTerminate
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop MediaKeyInterceptor
        MediaKeyInterceptor.shared.stop()
        LicenseManager.shared.stopTrialExpirationMonitor()
        permissionMonitorTimer?.invalidate()
        permissionMonitorTimer = nil
        trialExpirationObserver = nil
        
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        unregisterCarbonHotkeys()
        stopGlobalEventTap()
        for window in NSApp.windows {
            window.isRestorable = false
        }
    }
}