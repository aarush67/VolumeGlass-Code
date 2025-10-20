import SwiftUI
import Carbon

@main
struct VolumeGlassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var setupState = SetupState()
    
    init() {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
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
            if setupState.isSetupComplete {
                EmptyView()
                    .frame(width: 0, height: 0)
                    .onAppear {
                        appDelegate.startVolumeMonitoring(with: setupState)
                    }
            } else {
                SetupWalkthroughView(setupState: setupState)
                    .onAppear {
                        appDelegate.setupState = setupState
                    }
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 700)
        .restorationBehavior(.disabled)
        .windowToolbarStyle(.unifiedCompact)
        .onChange(of: setupState.isSetupComplete) { isComplete in
            if isComplete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    appDelegate.startVolumeMonitoring(with: setupState)
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var volumeMonitor: VolumeMonitor?
    private var eventMonitor: Any?
    private var statusItem: NSStatusItem?
    private var updateManager = UpdateManager()
    private var updateCheckTimer: Timer?
    var setupState: SetupState?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.set(false, forKey: "ApplePersistenceIgnoreState")
        
        setupKeyboardMonitoring()
        setupStatusBar()
        setupAutomaticUpdateChecks()
        
        for window in NSApp.windows {
            window.isRestorable = false
        }
    }
    
    private func setupAutomaticUpdateChecks() {
        // Check immediately on launch
        checkForUpdatesInBackground()
        
        // Check every 24 hours
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.checkForUpdatesInBackground()
        }
        
        print("🔄 Automatic update checks enabled (every 24 hours)")
    }
    
    private func checkForUpdatesInBackground() {
        print("🔍 Checking for updates in background...")
        updateManager.checkForUpdates()
        
        // Wait for response then show notification if update available
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.updateManager.updateAvailable {
                self.showUpdateNotification()
            }
        }
    }
    
    private func showUpdateNotification() {
        let notification = NSUserNotification()
        notification.title = "VolumeGlass Update Available"
        notification.informativeText = "Version \(updateManager.latestVersion) is now available!"
        notification.soundName = NSUserNotificationDefaultSoundName
        notification.actionButtonTitle = "Download"
        
        NSUserNotificationCenter.default.deliver(notification)
        
        // Also update menu bar icon with badge
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "speaker.badge.exclamationmark", accessibilityDescription: "Update Available")
        }
        
        print("📢 Update notification shown")
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "speaker.wave.3", accessibilityDescription: "VolumeGlass")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About VolumeGlass", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check for Updates", action: #selector(checkUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let keyboardHintsItem = NSMenuItem(title: "Keyboard Shortcuts", action: nil, keyEquivalent: "")
        let keyboardSubmenu = NSMenu()
        keyboardSubmenu.addItem(withTitle: "⌘⇧↑  Volume Up", action: nil, keyEquivalent: "")
        keyboardSubmenu.addItem(withTitle: "⌘⇧↓  Volume Down", action: nil, keyEquivalent: "")
        keyboardSubmenu.addItem(withTitle: "⌘⇧M  Toggle Mute", action: nil, keyEquivalent: "")
        keyboardHintsItem.submenu = keyboardSubmenu
        menu.addItem(keyboardHintsItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc private func checkUpdates() {
        print("🔍 Manual update check requested")
        updateManager.checkForUpdates()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.updateManager.updateAvailable {
                let alert = NSAlert()
                alert.messageText = "Update Available! 🎉"
                alert.informativeText = "Version \(self.updateManager.latestVersion) is available.\n\nYou're currently on version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown").\n\nWould you like to download it?"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Download")
                alert.addButton(withTitle: "Later")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    self.updateManager.downloadUpdate()
                    
                    // Reset icon after user action
                    if let button = self.statusItem?.button {
                        button.image = NSImage(systemSymbolName: "speaker.wave.3", accessibilityDescription: "VolumeGlass")
                    }
                }
            } else {
                let alert = NSAlert()
                alert.messageText = "You're Up to Date! ✅"
                alert.informativeText = "VolumeGlass \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown") is the latest version."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func setupKeyboardMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .systemDefined, .flagsChanged]) { [weak self] event in
            guard let self = self else { return }
            
            if event.type == .systemDefined && event.subtype.rawValue == 8 {
                let keyCode = ((event.data1 & 0xFFFF0000) >> 16)
                let keyFlags = (event.data1 & 0x0000FFFF)
                let keyPressed = ((keyFlags & 0xFF00) >> 8) == 0xA
                
                if keyPressed {
                    switch Int32(keyCode) {
                    case NX_KEYTYPE_SOUND_UP: self.handleVolumeUp()
                    case NX_KEYTYPE_SOUND_DOWN: self.handleVolumeDown()
                    case NX_KEYTYPE_MUTE: self.handleMuteToggle()
                    default: break
                    }
                }
            }
            
            if event.type == .keyDown {
                let flags = event.modifierFlags
                let keyCode = event.keyCode
                
                if flags.contains([.command, .shift]) && keyCode == 126 { self.handleVolumeUp() }
                else if flags.contains([.command, .shift]) && keyCode == 125 { self.handleVolumeDown() }
                else if flags.contains([.command, .shift]) && event.characters?.lowercased() == "m" { self.handleMuteToggle() }
            }
        }
    }
    
    private func handleVolumeUp() {
        guard let volumeMonitor = volumeMonitor else { return }
        let newVolume = min(1.0, volumeMonitor.currentVolume + 0.05)
        volumeMonitor.setSystemVolume(Float(newVolume))
    }
    
    private func handleVolumeDown() {
        guard let volumeMonitor = volumeMonitor else { return }
        let newVolume = max(0.0, volumeMonitor.currentVolume - 0.05)
        volumeMonitor.setSystemVolume(Float(newVolume))
    }
    
    private func handleMuteToggle() {
        volumeMonitor?.toggleMute()
    }
    
    func startVolumeMonitoring(with setupState: SetupState) {
        if volumeMonitor != nil {
            volumeMonitor = nil
        }
        
        NSApp.setActivationPolicy(.accessory)
        hideAllWindows()
        
        volumeMonitor = VolumeMonitor()
        volumeMonitor?.setupState = setupState
        volumeMonitor?.createVolumeOverlay()
    }
    
    private func hideAllWindows() {
        for window in NSApp.windows {
            window.orderOut(nil)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return volumeMonitor == nil
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        updateCheckTimer?.invalidate()
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        for window in NSApp.windows {
            window.isRestorable = false
        }
    }
}

