import Foundation

enum InterAppTextureSettings {
    private static let defaultsKey = "openvj.publishInterAppTexture"

    static var publishEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: defaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    static var syphonRequestedAtLaunch: Bool {
        let env = ProcessInfo.processInfo.environment["OPEN_VJ_SYPHON"]?.lowercased()
        if env == "1" || env == "true" || env == "yes" { return true }
        return publishEnabled
    }
}
