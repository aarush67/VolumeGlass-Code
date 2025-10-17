import Foundation
import SwiftUI
import Combine

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
        let windowWidth = isVertical ? CGFloat(50 * barSize) : CGFloat(240 * barSize)
        let windowHeight = isVertical ? CGFloat(240 * barSize) : CGFloat(50 * barSize)
        
        switch self {
        case .leftMiddleVertical:
            return NSRect(
                x: 20,
                y: screenFrame.height / 2 - windowHeight / 2,
                width: windowWidth,
                height: windowHeight
            )
        case .bottomVertical:
            return NSRect(
                x: screenFrame.width / 2 - windowWidth / 2,
                y: 50,
                width: windowWidth,
                height: windowHeight
            )
        case .rightVertical:
            return NSRect(
                x: screenFrame.width - windowWidth - 20,
                y: screenFrame.height / 2 - windowHeight / 2,
                width: windowWidth,
                height: windowHeight
            )
        case .topHorizontal:
            return NSRect(
                x: screenFrame.width / 2 - windowWidth / 2,
                y: screenFrame.height - windowHeight - 50,
                width: windowWidth,
                height: windowHeight
            )
        case .bottomHorizontal:
            return NSRect(
                x: screenFrame.width / 2 - windowWidth / 2,
                y: 50,
                width: windowWidth,
                height: windowHeight
            )
        }
    }
}

class SetupState: ObservableObject {
    @Published var selectedPosition: VolumeBarPosition = .leftMiddleVertical
    @Published var barSize: CGFloat = 1.0
    @Published var isSetupComplete = false
    
    var isVertical: Bool {
        selectedPosition.isVertical
    }
    
    func completeSetup() {
        print("⚙️ completeSetup() called")
        
        // Save preferences
        UserDefaults.standard.set(selectedPosition.rawValue, forKey: "VolumeBarPosition")
        UserDefaults.standard.set(barSize, forKey: "VolumeBarSize")
        UserDefaults.standard.set(true, forKey: "VolumeSetupComplete")
        
        print("💾 Settings saved:")
        print("   Position: \(selectedPosition.displayName)")
        print("   Size: \(barSize)")
        
        // Mark as complete - FORCE STATE CHANGE
        isSetupComplete = true
        print("✅ Setup marked as complete: \(isSetupComplete)")
    }
    
    func loadSavedPreferences() {
        if let positionRawValue = UserDefaults.standard.object(forKey: "VolumeBarPosition") as? Int,
           let position = VolumeBarPosition(rawValue: positionRawValue) {
            selectedPosition = position
        }
        
        let size = UserDefaults.standard.double(forKey: "VolumeBarSize")
        if size > 0 {
            barSize = size
        }
        
        isSetupComplete = UserDefaults.standard.bool(forKey: "VolumeSetupComplete")
    }
}

extension VolumeBarPosition: RawRepresentable {
    var rawValue: Int {
        switch self {
        case .leftMiddleVertical: return 0
        case .bottomVertical: return 1
        case .rightVertical: return 2
        case .topHorizontal: return 3
        case .bottomHorizontal: return 4
        }
    }
    
    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .leftMiddleVertical
        case 1: self = .bottomVertical
        case 2: self = .rightVertical
        case 3: self = .topHorizontal
        case 4: self = .bottomHorizontal
        default: return nil
        }
    }
}

