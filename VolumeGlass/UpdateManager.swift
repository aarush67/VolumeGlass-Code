import Foundation
import AppKit
import Combine

class UpdateManager: ObservableObject {
    @Published var updateAvailable = false
    @Published var latestVersion = ""
    @Published var downloadURL = ""
    
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let repoOwner = "aarush67"
    private let repoName = "VolumeGlass-Code"
    
    func checkForUpdates() {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("❌ Update check failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tagName = json["tag_name"] as? String,
               let assets = json["assets"] as? [[String: Any]],
               let firstAsset = assets.first,
               let downloadURL = firstAsset["browser_download_url"] as? String {
                
                let latestVersion = tagName.replacingOccurrences(of: "v", with: "")
                
                DispatchQueue.main.async {
                    self?.latestVersion = latestVersion
                    self?.downloadURL = downloadURL
                    
                    if self?.isNewerVersion(latestVersion) == true {
                        self?.updateAvailable = true
                        print("✅ Update available: \(latestVersion)")
                    } else {
                        print("✅ Already on latest version")
                    }
                }
            }
        }.resume()
    }
    
    private func isNewerVersion(_ newVersion: String) -> Bool {
        let current = currentVersion.components(separatedBy: ".").compactMap { Int($0) }
        let new = newVersion.components(separatedBy: ".").compactMap { Int($0) }
        
        for (index, newNum) in new.enumerated() {
            guard index < current.count else { return true }
            if newNum > current[index] { return true }
            if newNum < current[index] { return false }
        }
        return false
    }
    
    func downloadUpdate() {
        guard let url = URL(string: downloadURL) else { return }
        NSWorkspace.shared.open(url)
    }
}

