import Foundation
import Syphon

public struct SyphonServerEntry: Sendable, Equatable {
    public var serverName: String
    public var displayName: String
}

/// Syphon servers from `SyphonServerDirectory` (for source browser UI).
public enum SyphonServerListing {
    public static func entries() -> [SyphonServerEntry] {
        let directory = SyphonServerDirectory.shared()
        let servers = directory.servers(matchingName: nil, appName: nil)
        var result: [SyphonServerEntry] = []
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
            result.append(SyphonServerEntry(serverName: serverName, displayName: display))
        }
        return result.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
