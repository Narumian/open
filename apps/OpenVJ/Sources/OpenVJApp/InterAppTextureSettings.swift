import Foundation

enum InterAppTextureSettings {
    private static let defaultsKey = "openvj.publishInterAppTexture"

    static var publishEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: defaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    static var interAppPublishRequestedAtLaunch: Bool {
        let keys = ["OPEN_VJ_INTER_APP_PUBLISH", "OPEN_VJ_SYPHON"]
        for key in keys {
            let env = ProcessInfo.processInfo.environment[key]?.lowercased()
            if env == "1" || env == "true" || env == "yes" { return true }
        }
        return publishEnabled
    }
}
