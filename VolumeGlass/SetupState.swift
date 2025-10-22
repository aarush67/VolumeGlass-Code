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
      
        let padding: CGFloat = 40
      
        switch self {
        case .leftMiddleVertical:
            return NSRect(
                x: screenFrame.origin.x + padding,
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
                x: screenFrame.origin.x + screenFrame.width - windowWidth - padding,
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
                y: screenFrame.origin.y + padding,
                width: windowWidth,
                height: windowHeight
            )
        }
    }
}

class SetupState: ObservableObject {
    @Published var selectedPosition: VolumeBarPosition = .leftMiddleVertical
    @Published var barSize: CGFloat = 1.0
    @Published var isSetupComplete: Bool

    init() {
        // Force walkthrough to always show during testing
        UserDefaults.standard.set(false, forKey: "isSetupComplete")

        isSetupComplete = UserDefaults.standard.bool(forKey: "isSetupComplete")
    
        if let savedPositionRaw = UserDefaults.standard.string(forKey: "volumeBarPosition"),
           let savedPosition = VolumeBarPosition.allCases.first(where: { $0.displayName == savedPositionRaw }) {
            self.selectedPosition = savedPosition
        }
    
        let savedSize = UserDefaults.standard.double(forKey: "barSize")
        if savedSize > 0 {
            self.barSize = CGFloat(savedSize)
        }
    }
  
    func completeSetup() {
        UserDefaults.standard.set(true, forKey: "isSetupComplete")
        UserDefaults.standard.set(selectedPosition.displayName, forKey: "volumeBarPosition")
        UserDefaults.standard.set(Double(barSize), forKey: "barSize")
    
        isSetupComplete = true
    
        NotificationCenter.default.post(name: NSNotification.Name("SetupComplete"), object: nil)
    }
}

