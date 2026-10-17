import Foundation
import OpenUI

/// Resolves the root scene from `OPEN_VJ_SCENE` (headless CLI and tests).
public enum OpenVJSceneEnvironment {
    public static let sceneKey = "OPEN_VJ_SCENE"

    public static func resolvedRootView() -> AnyView {
        rootView(named: ProcessInfo.processInfo.environment[sceneKey])
    }

    public static func rootView(named name: String?) -> AnyView {
        switch name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case nil, "", "default", "openvjdefaultscene":
            return AnyView(OpenVJDefaultScene())
        case "source-browser-mixer", "source_browser_mixer":
            return AnyView(OpenVJSourceBrowserMixerScene())
        case "live", "openvjlivescene":
            return AnyView(OpenVJLiveScene())
        case "timed-demo", "timed_demo", "openvjtimeddemoscene":
            return AnyView(OpenVJTimedDemoScene(time: 0))
        default:
            fputs("[OpenVJ] Unknown OPEN_VJ_SCENE=\"\(name ?? "")\"; using OpenVJDefaultScene.\n", stderr)
            return AnyView(OpenVJDefaultScene())
        }
    }
}
