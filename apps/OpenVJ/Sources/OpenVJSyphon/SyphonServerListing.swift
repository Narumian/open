import Foundation
import OpenVJ
import Syphon

enum SyphonServerListing {
    static func inputServers() -> [InterAppTextureInputServer] {
        let directory = SyphonServerDirectory.shared()
        let servers = directory.servers(matchingName: nil, appName: nil)
        var result: [InterAppTextureInputServer] = []
        for description in servers {
            let serverName = description[SyphonServerDescriptionNameKey] as? String ?? ""
            guard !serverName.isEmpty else { continue }
            let appName = description[SyphonServerDescriptionAppNameKey] as? String ?? ""
            let display: String
            if appName.isEmpty {
                display = serverName
            } else {
                display = "\(serverName) — \(appName)"
            }
            result.append(InterAppTextureInputServer(serverName: serverName, displayName: display))
        }
        return result.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}
