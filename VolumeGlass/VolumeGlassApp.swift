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
                        print("🟢 Setup complete view appeared - starting volume monitoring...")
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
                print("🟢 Setup completion detected - triggering volume monitoring...")
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
    var setupState: SetupState?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 App launched")
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.set(false, forKey: "ApplePersistenceIgnoreState")
        
        // Setup keyboard monitoring IMMEDIATELY on launch
        setupKeyboardMonitoring()
        
        for window in NSApp.windows {
            window.isRestorable = false
        }
    }
    
    private func setupKeyboardMonitoring() {
        print("⌨️ Setting up global keyboard monitoring...")
        
        // Monitor BOTH system events and key events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .systemDefined, .flagsChanged]) { [weak self] event in
            guard let self = self else { return }
            
            // Handle system volume keys (F11/F12 or media keys)
            if event.type == .systemDefined && event.subtype.rawValue == 8 {
                let keyCode = ((event.data1 & 0xFFFF0000) >> 16)
                let keyFlags = (event.data1 & 0x0000FFFF)
                let keyPressed = ((keyFlags & 0xFF00) >> 8) == 0xA
                
                if keyPressed {
                    print("🎹 System media key detected: \(keyCode)")
                    switch Int32(keyCode) {
                    case NX_KEYTYPE_SOUND_UP:
                        self.handleVolumeUp()
                    case NX_KEYTYPE_SOUND_DOWN:
                        self.handleVolumeDown()
                    case NX_KEYTYPE_MUTE:
                        self.handleMuteToggle()
                    default:
                        break
                    }
                }
            }
            
            // Handle custom keyboard shortcuts
            if event.type == .keyDown {
                let flags = event.modifierFlags
                let keyCode = event.keyCode
                
                print("🎹 Key pressed - Code: \(keyCode), Flags: \(flags)")
                
                // Cmd + Shift + Up Arrow = Volume Up (keyCode 126)
                if flags.contains([.command, .shift]) && keyCode == 126 {
                    print("⬆️ Volume Up shortcut detected")
                    self.handleVolumeUp()
                }
                // Cmd + Shift + Down Arrow = Volume Down (keyCode 125)
                else if flags.contains([.command, .shift]) && keyCode == 125 {
                    print("⬇️ Volume Down shortcut detected")
                    self.handleVolumeDown()
                }
                // Cmd + Shift + M = Mute Toggle
                else if flags.contains([.command, .shift]) && event.characters?.lowercased() == "m" {
                    print("🔇 Mute Toggle shortcut detected")
                    self.handleMuteToggle()
                }
            }
        }
        
        print("✅ Global keyboard monitoring activated")
    }
    
    private func handleVolumeUp() {
        guard let volumeMonitor = volumeMonitor else {
            print("⚠️ VolumeMonitor not ready")
            return
        }
        let currentVolume = volumeMonitor.currentVolume
        let newVolume = min(1.0, currentVolume + 0.05)
        print("🔊 Increasing volume from \(Int(currentVolume * 100))% to \(Int(newVolume * 100))%")
        volumeMonitor.setSystemVolume(Float(newVolume))
    }
    
    private func handleVolumeDown() {
        guard let volumeMonitor = volumeMonitor else {
            print("⚠️ VolumeMonitor not ready")
            return
        }
        let currentVolume = volumeMonitor.currentVolume
        let newVolume = max(0.0, currentVolume - 0.05)
        print("🔉 Decreasing volume from \(Int(currentVolume * 100))% to \(Int(newVolume * 100))%")
        volumeMonitor.setSystemVolume(Float(newVolume))
    }
    
    private func handleMuteToggle() {
        guard let volumeMonitor = volumeMonitor else {
            print("⚠️ VolumeMonitor not ready")
            return
        }
        print("🔇 Toggling mute")
        volumeMonitor.toggleMute()
    }
    
    func startVolumeMonitoring(with setupState: SetupState) {
        print("🎯 startVolumeMonitoring called")
        print("📍 Position: \(setupState.selectedPosition.displayName)")
        print("📏 Size: \(setupState.barSize)")
        
        if volumeMonitor != nil {
            print("⚠️ Volume monitor already exists, cleaning up...")
            volumeMonitor = nil
        }
        
        NSApp.setActivationPolicy(.accessory)
        hideAllWindows()
        
        volumeMonitor = VolumeMonitor()
        volumeMonitor?.setupState = setupState
        volumeMonitor?.createVolumeOverlay()
        print("✅ Volume monitoring started successfully")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🧪 Testing volume bar visibility...")
            self.volumeMonitor?.startVolumeChangeIndicator()
        }
    }
    
    private func hideAllWindows() {
        for window in NSApp.windows {
            window.orderOut(nil)
        }
        print("👻 All windows hidden")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return volumeMonitor == nil
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        for window in NSApp.windows {
            window.isRestorable = false
        }
    }
}

