import Foundation
import SwiftUI
import Combine

// MARK: - Shortcut Key Model

struct ShortcutKey: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt  // NSEvent.ModifierFlags.rawValue filtered to [.command, .shift, .option, .control]

    /// Carbon modifier flags for RegisterEventHotKey
    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.command) { m |= 0x0100 }
        if flags.contains(.shift)   { m |= 0x0200 }
        if flags.contains(.option)  { m |= 0x0800 }
        if flags.contains(.control) { m |= 0x1000 }
        return m
    }

    var displayString: String {
        var s = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option)  { s += "⌥" }
        if flags.contains(.shift)   { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        s += Self.keyName(for: keyCode)
        return s
    }

    static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 126: return "↑"
        case 125: return "↓"
        case 123: return "←"
        case 124: return "→"
        case 49:  return "Space"
        case 36:  return "↩"
        case 51:  return "⌫"
        case 53:  return "Esc"
        case 0:   return "A"
        case 11:  return "B"
        case 8:   return "C"
        case 2:   return "D"
        case 14:  return "E"
        case 3:   return "F"
        case 5:   return "G"
        case 4:   return "H"
        case 34:  return "I"
        case 38:  return "J"
        case 40:  return "K"
        case 37:  return "L"
        case 46:  return "M"
        case 45:  return "N"
        case 31:  return "O"
        case 35:  return "P"
        case 12:  return "Q"
        case 15:  return "R"
        case 1:   return "S"
        case 17:  return "T"
        case 32:  return "U"
        case 9:   return "V"
        case 13:  return "W"
        case 7:   return "X"
        case 16:  return "Y"
        case 6:   return "Z"
        case 29:  return "0"
        case 18:  return "1"
        case 19:  return "2"
        case 20:  return "3"
        case 21:  return "4"
        case 23:  return "5"
        case 22:  return "6"
        case 26:  return "7"
        case 28:  return "8"
        case 25:  return "9"
        default:  return "Key\(keyCode)"
        }
    }

    static var defaultVolumeUp: ShortcutKey {
        ShortcutKey(keyCode: 126, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
    }
    static var defaultVolumeDown: ShortcutKey {
        ShortcutKey(keyCode: 125, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
    }
    static var defaultMute: ShortcutKey {
        ShortcutKey(keyCode: 46, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
    }
}

enum VolumeBarPosition: CaseIterable {
    case leftMiddleVertical
    case bottomVertical
    case rightVertical
    case topHorizontal
    case bottomHorizontal
  
    var displayName: String {
        switch self {
        case .leftMiddleVertical: return "Left Middle (Vertical)"
        case .bottomVertical: return "Bottom (Vertical)"
        case .rightVertical: return "Right (Vertical)"
        case .topHorizontal: return "Top (Horizontal)"
        case .bottomHorizontal: return "Bottom (Horizontal)"
        }
    }
  
    var isVertical: Bool {
        switch self {
        case .leftMiddleVertical, .bottomVertical, .rightVertical:
            return true
        case .topHorizontal, .bottomHorizontal:
            return false
        }
    }
  
    func getScreenPosition(screenFrame: NSRect, barSize: CGFloat) -> NSRect {
        // Base sizes should match VolumeControlView's VolumeIndicatorView frame sizes
        let windowWidth = isVertical ? CGFloat(100 * barSize) : CGFloat(320 * barSize)
        let windowHeight = isVertical ? CGFloat(300 * barSize) : CGFloat(100 * barSize)
      
        // Scale padding with barSize so larger bars have more space from edges
        let padding: CGFloat = 40 + (20 * (barSize - 1.0))
        let leftPadding: CGFloat = padding + (20 * max(barSize - 1.0, 0)) + 10
        
        switch self {
        case .leftMiddleVertical:
            return NSRect(
                x: screenFrame.origin.x + leftPadding,
                y: screenFrame.origin.y + (screenFrame.height / 2) - (windowHeight / 2),
                width: windowWidth,
                height: windowHeight
            )
        case .bottomVertical:
            return NSRect(
                x: screenFrame.origin.x + (screenFrame.width / 2) - (windowWidth / 2),
                y: screenFrame.origin.y + padding,
                width: windowWidth,
                height: windowHeight
            )
        case .rightVertical:
            return NSRect(
                x: screenFrame.maxX - windowWidth - 30,
                y: screenFrame.origin.y + (screenFrame.height / 2) - (windowHeight / 2),
                width: windowWidth,
                height: windowHeight
            )
        case .topHorizontal:
            return NSRect(
                x: screenFrame.origin.x + (screenFrame.width / 2) - (windowWidth / 2),
                y: screenFrame.origin.y + screenFrame.height - windowHeight - padding,
                width: windowWidth,
                height: windowHeight
            )
        case .bottomHorizontal:
            return NSRect(
                x: screenFrame.origin.x + (screenFrame.width / 2) - (windowWidth / 2),
                y: screenFrame.origin.y + padding + 70,
                width: windowWidth,
                height: windowHeight
            )
        }
    }
}

// MARK: - Volume Bar Color Mode

enum VolumeBarColorMode: String, CaseIterable {
    case system = "System"
    case white = "White"
    case black = "Black"
    case accent = "Accent"
    case custom = "Custom"

    var displayName: String { rawValue }
}

class SetupState: ObservableObject {
    @Published var selectedPosition: VolumeBarPosition = .leftMiddleVertical
    @Published var barSize: CGFloat = 1.0
    @Published var isSetupComplete: Bool
    @Published var shortcutVolumeUp: ShortcutKey = .defaultVolumeUp
    @Published var shortcutVolumeDown: ShortcutKey = .defaultVolumeDown
    @Published var shortcutMute: ShortcutKey = .defaultMute
    @Published var showInNotch: Bool = false
    @Published var showNotchBar: Bool = false
    @Published var volumeDismissTime: Double = 2.0
    @Published var volumeBarColorMode: VolumeBarColorMode = .system
    @Published var customBarColorHex: String = "#FFFFFF"
    @Published var fineStepDivisor: Float = 3.0

    /// Read current shortcuts from UserDefaults — safe to call from any context.
    static var currentShortcuts: (volumeUp: ShortcutKey, volumeDown: ShortcutKey, mute: ShortcutKey) {
        (
            loadShortcut(forKey: "shortcutVolumeUp") ?? .defaultVolumeUp,
            loadShortcut(forKey: "shortcutVolumeDown") ?? .defaultVolumeDown,
            loadShortcut(forKey: "shortcutMute") ?? .defaultMute
        )
    }
    
    static var currentFineStepDivisor: Float {
        let stored = UserDefaults.standard.float(forKey: "fineStepDivisor")
        if stored > 0 {
            return max(1.0, min(10.0, stored))
        }
        return 3.0
    }

    private static func loadShortcut(forKey key: String) -> ShortcutKey? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ShortcutKey.self, from: data)
    }

    private func saveShortcut(_ shortcut: ShortcutKey, forKey key: String) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
            UserDefaults.standard.synchronize()
        }
    }

    init() {
        // Only show onboarding on first launch - check if key exists
        let hasLaunchedBefore = UserDefaults.standard.object(forKey: "hasLaunchedBefore") != nil
        
        if hasLaunchedBefore {
            isSetupComplete = UserDefaults.standard.bool(forKey: "isSetupComplete")
        } else {
            // First launch - show onboarding
            isSetupComplete = false
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    
        // Load saved position
        if let savedPositionRaw = UserDefaults.standard.string(forKey: "volumeBarPosition") {
            print("📍 Loading saved position: \(savedPositionRaw)")
            if let savedPosition = VolumeBarPosition.allCases.first(where: { $0.displayName == savedPositionRaw }) {
                self.selectedPosition = savedPosition
                print("✅ Position loaded: \(savedPosition.displayName)")
            } else {
                print("⚠️ Could not find matching position for: \(savedPositionRaw)")
            }
        } else {
            print("📍 No saved position found, using default")
        }
    
        // Load saved size
        let savedSize = UserDefaults.standard.double(forKey: "barSize")
        if savedSize > 0 {
            self.barSize = CGFloat(savedSize)
            print("📏 Size loaded: \(savedSize)")
        }
        
        // Load saved shortcuts
        if let sk = Self.loadShortcut(forKey: "shortcutVolumeUp") { shortcutVolumeUp = sk }
        if let sk = Self.loadShortcut(forKey: "shortcutVolumeDown") { shortcutVolumeDown = sk }
        if let sk = Self.loadShortcut(forKey: "shortcutMute") { shortcutMute = sk }

        // Load notch display preferences
        if UserDefaults.standard.object(forKey: "showInNotch") != nil {
            self.showInNotch = UserDefaults.standard.bool(forKey: "showInNotch")
        }
        if UserDefaults.standard.object(forKey: "showNotchBar") != nil {
            self.showNotchBar = UserDefaults.standard.bool(forKey: "showNotchBar")
        }
        if UserDefaults.standard.object(forKey: "volumeDismissTime") != nil {
            let t = UserDefaults.standard.double(forKey: "volumeDismissTime")
            if t > 0 { self.volumeDismissTime = t }
        }

        // Load volume bar color preferences
        if let savedColorMode = UserDefaults.standard.string(forKey: "volumeBarColorMode"),
           let mode = VolumeBarColorMode(rawValue: savedColorMode) {
            self.volumeBarColorMode = mode
        }
        if let savedHex = UserDefaults.standard.string(forKey: "customBarColorHex") {
            self.customBarColorHex = savedHex
        }
        if UserDefaults.standard.object(forKey: "fineStepDivisor") != nil {
            let stored = UserDefaults.standard.float(forKey: "fineStepDivisor")
            if stored > 0 {
                self.fineStepDivisor = max(1.0, min(10.0, stored))
            }
        }

        UserDefaults.standard.synchronize()
    }
  
    func completeSetup() {
        UserDefaults.standard.set(true, forKey: "isSetupComplete")
        UserDefaults.standard.set(selectedPosition.displayName, forKey: "volumeBarPosition")
        UserDefaults.standard.set(Double(barSize), forKey: "barSize")
        UserDefaults.standard.synchronize()
    
        isSetupComplete = true
    
        NotificationCenter.default.post(name: NSNotification.Name("SetupComplete"), object: nil)
        print("✅ Setup complete - Position: \(selectedPosition.displayName), Size: \(barSize)")
    }
    
    func updatePosition(_ position: VolumeBarPosition) {
        selectedPosition = position
        UserDefaults.standard.set(position.displayName, forKey: "volumeBarPosition")
        UserDefaults.standard.synchronize()
        print("📍 Position updated to: \(position.displayName)")
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }
    
    func updateSize(_ size: CGFloat) {
        barSize = size
        UserDefaults.standard.set(Double(size), forKey: "barSize")
        UserDefaults.standard.synchronize()
        print("📏 Size updated to: \(size)")
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }

    func updateShowInNotch(_ enabled: Bool) {
        showInNotch = enabled
        UserDefaults.standard.set(enabled, forKey: "showInNotch")
        UserDefaults.standard.synchronize()
        print("🔲 Show in notch updated to: \(enabled)")
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }

    func updateShowNotchBar(_ enabled: Bool) {
        showNotchBar = enabled
        UserDefaults.standard.set(enabled, forKey: "showNotchBar")
        UserDefaults.standard.synchronize()
        print("🖥️ Show notch bar updated to: \(enabled)")
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }

    func updateVolumeDismissTime(_ seconds: Double) {
        let clamped = max(0.2, min(10.0, seconds))
        volumeDismissTime = clamped
        UserDefaults.standard.set(clamped, forKey: "volumeDismissTime")
        UserDefaults.standard.synchronize()
        print("⏱️ Volume dismiss time updated to: \(clamped)s")
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }

    func updateShortcutVolumeUp(_ shortcut: ShortcutKey) {
        shortcutVolumeUp = shortcut
        saveShortcut(shortcut, forKey: "shortcutVolumeUp")
        NotificationCenter.default.post(name: NSNotification.Name("ShortcutsChanged"), object: nil)
    }

    func updateShortcutVolumeDown(_ shortcut: ShortcutKey) {
        shortcutVolumeDown = shortcut
        saveShortcut(shortcut, forKey: "shortcutVolumeDown")
        NotificationCenter.default.post(name: NSNotification.Name("ShortcutsChanged"), object: nil)
    }

    func updateShortcutMute(_ shortcut: ShortcutKey) {
        shortcutMute = shortcut
        saveShortcut(shortcut, forKey: "shortcutMute")
        NotificationCenter.default.post(name: NSNotification.Name("ShortcutsChanged"), object: nil)
    }

    func updateBarColorMode(_ mode: VolumeBarColorMode) {
        volumeBarColorMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "volumeBarColorMode")
        UserDefaults.standard.synchronize()
        print("🎨 Bar color mode updated to: \(mode.rawValue)")
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }

    func updateCustomBarColor(_ hexColor: String) {
        customBarColorHex = hexColor
        UserDefaults.standard.set(hexColor, forKey: "customBarColorHex")
        UserDefaults.standard.synchronize()
        print("🎨 Custom bar color updated to: \(hexColor)")
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }
    
    func updateFineStepDivisor(_ divisor: Float) {
        let clamped = max(1.0, min(10.0, divisor))
        fineStepDivisor = clamped
        UserDefaults.standard.set(clamped, forKey: "fineStepDivisor")
        UserDefaults.standard.synchronize()
        print("🎚️ Fine step divisor updated to: \(clamped)")
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }

    /// Converts the custom hex color string to a SwiftUI Color
    var customBarColor: Color {
        Color(hex: customBarColorHex) ?? .white
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b: Double
        switch hexSanitized.count {
        case 6:
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        case 8:
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
        default:
            return nil
        }

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return "#FFFFFF"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}