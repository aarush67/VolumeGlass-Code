import SwiftUI

@main
struct VolumeGlassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var setupState = SetupState()
    
    init() {
        // CRITICAL: Completely disable state restoration at app level
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        
        // Clear all saved application state that causes frame errors
        if let bundleID = Bundle.main.bundleIdentifier {
            let savedAppStatePath = NSHomeDirectory() + "/Library/Saved Application State/" + bundleID + ".savedState"
            try? FileManager.default.removeItem(atPath: savedAppStatePath)
        }
        
        // Remove all window frame UserDefaults
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
        // ADDED: Monitor setup completion changes
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
    var setupState: SetupState?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 App launched")
        
        // CRITICAL: Disable all forms of state restoration
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.set(false, forKey: "ApplePersistenceIgnoreState")
        
        // Clear settings every time the app starts
        clearAllSettings()
        
        // Disable restoration for all existing windows
        for window in NSApp.windows {
            window.isRestorable = false
        }
    }
    
    func startVolumeMonitoring(with setupState: SetupState) {
        print("🎯 startVolumeMonitoring called")
        print("📍 Position: \(setupState.selectedPosition.displayName)")
        print("📏 Size: \(setupState.barSize)")
        
        // Prevent multiple instances
        if volumeMonitor != nil {
            print("⚠️ Volume monitor already exists, cleaning up...")
            volumeMonitor = nil
        }
        
        NSApp.setActivationPolicy(.accessory)
        hideAllWindows()
        
        // Create and start volume monitoring
        volumeMonitor = VolumeMonitor()
        volumeMonitor?.setupState = setupState
        volumeMonitor?.createVolumeOverlay()
        
        print("✅ Volume monitoring started successfully")
        
        // Test the volume bar immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🧪 Testing volume bar visibility...")
            self.volumeMonitor?.startVolumeChangeIndicator()
        }
    }
    
    private func clearAllSettings() {
        UserDefaults.standard.removeObject(forKey: "VolumeBarPosition")
        UserDefaults.standard.removeObject(forKey: "VolumeBarSize")
        UserDefaults.standard.removeObject(forKey: "VolumeSetupComplete")
        print("🧹 Settings cleared")
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
    
    // CRITICAL: Prevent any window state saving
    func applicationWillTerminate(_ notification: Notification) {
        for window in NSApp.windows {
            window.isRestorable = false
        }
    }
}

