//
//  AutoUpdater.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import Foundation
import AppKit

/// Handles downloading and installing app updates
class AutoUpdater {
    static let shared = AutoUpdater()
    
    private init() {}
    
    /// Downloads and installs the update from the given URL
    func installUpdate(from url: URL) {
        Task {
            // 1. Download DMG
            guard let dmgURL = await downloadDMG(from: url) else {
                return
            }
            
            // 2. Install and Restart using helper app
            do {
                try launchUpdaterHelper(dmgPath: dmgURL.path)
            } catch {
                print("AutoUpdater: Installation failed: \(error)")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Update Failed"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }
    
    private func downloadDMG(from url: URL) async -> URL? {
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("VolumeGlassUpdate.dmg")
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: destinationURL)
            return destinationURL
        } catch {
            print("AutoUpdater: Download failed: \(error)")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Update Failed"
                alert.informativeText = "Could not download the update. Please try again later."
                alert.runModal()
            }
            return nil
        }
    }
    
    private func launchUpdaterHelper(dmgPath: String) throws {
        let appPath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        
        // Look for the helper in the app bundle
        let helperInBundle = Bundle.main.bundlePath + "/Contents/Helpers/VolumeGlassUpdater"
        
        // Fallback to temp directory (for development)
        let helperInTemp = FileManager.default.temporaryDirectory.appendingPathComponent("VolumeGlassUpdater").path
        
        // Determine which helper to use
        let helperPath: String
        if FileManager.default.fileExists(atPath: helperInBundle) {
            helperPath = helperInBundle
        } else if FileManager.default.fileExists(atPath: helperInTemp) {
            helperPath = helperInTemp
        } else {
            // Fallback: Copy helper from source location to temp
            let sourceHelper = (Bundle.main.bundlePath as NSString)
                .deletingLastPathComponent
                .appending("/VolumeGlassUpdater/VolumeGlassUpdater")
            
            if FileManager.default.fileExists(atPath: sourceHelper) {
                try? FileManager.default.copyItem(atPath: sourceHelper, toPath: helperInTemp)
                helperPath = helperInTemp
            } else {
                // Ultimate fallback: Use Terminal script
                try fallbackToTerminalScript(dmgPath: dmgPath, appPath: appPath, pid: pid)
                return
            }
        }
        
        // Launch the helper
        let process = Process()
        process.executableURL = URL(fileURLWithPath: helperPath)
        process.arguments = [dmgPath, appPath, String(pid)]
        
        try process.run()
        
        // Terminate current app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }
    
    /// Fallback to Terminal script if helper is not available
    private func fallbackToTerminalScript(dmgPath: String, appPath: String, pid: Int32) throws {
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("update_volumeglass.command").path
        let appName = "VolumeGlass.app"
        
        let script = """
        #!/bin/bash
        
        # Colors
        BLUE='\\033[0;34m'
        PURPLE='\\033[0;35m'
        CYAN='\\033[0;36m'
        GREEN='\\033[0;32m'
        BOLD='\\033[1m'
        NC='\\033[0m'
        
        clear
        echo -e "${BLUE}${BOLD}"
        echo "  VolumeGlass Updater"
        echo "  -------------------"
        echo -e "${NC}"
        echo -e "${PURPLE}${BOLD}    >>> UPDATING VOLUMEGLASS <<<${NC}"
        echo ""
        
        APP_PATH="\(appPath)"
        DMG_PATH="\(dmgPath)"
        APP_NAME="\(appName)"
        OLD_PID=\(pid)
        
        # Kill and wait
        echo -e "${CYAN}⏳ Closing VolumeGlass...${NC}"
        kill -9 $OLD_PID 2>/dev/null || true
        sleep 2
        
        # Mount
        echo -e "${CYAN}📦 Mounting update image...${NC}"
        hdiutil attach "$DMG_PATH" -nobrowse -mountpoint /Volumes/VolumeGlassUpdate > /dev/null 2>&1
        
        # Remove old
        echo -e "${CYAN}🗑️  Removing old version...${NC}"
        rm -rf "$APP_PATH" 2>/dev/null || osascript -e "do shell script \\"rm -rf '$APP_PATH'\\" with administrator privileges" 2>/dev/null
        
        # Install
        echo -e "${CYAN}🚀 Installing new VolumeGlass...${NC}"
        cp -R "/Volumes/VolumeGlassUpdate/$APP_NAME" "$APP_PATH"
        xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true
        
        # Cleanup
        echo -e "${CYAN}🧹 Cleaning up...${NC}"
        hdiutil detach /Volumes/VolumeGlassUpdate > /dev/null 2>&1 || true
        rm -f "$DMG_PATH" 2>/dev/null || true
        
        echo ""
        echo -e "${GREEN}${BOLD}✅ UPDATE COMPLETE!${NC}"
        sleep 1
        open -n "$APP_PATH"
        (sleep 1 && rm -f "$0") &
        exit 0
        """
        
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        
        var attributes = [FileAttributeKey : Any]()
        attributes[.posixPermissions] = 0o755
        try FileManager.default.setAttributes(attributes, ofItemAtPath: scriptPath)
        
        NSWorkspace.shared.open(URL(fileURLWithPath: scriptPath))
        NSApplication.shared.terminate(nil)
    }
}
