import Foundation

enum SourceBrowserSettings {
    static var requestedAtLaunch: Bool {
        let env = ProcessInfo.processInfo.environment["OPEN_VJ_SOURCE_BROWSER"]?.lowercased()
        return env == "1" || env == "true" || env == "yes"
    }
}
