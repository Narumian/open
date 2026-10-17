import Foundation
import OpenUI

/// Named visual program for the app window, headless export, and renderer backends.
///
/// **OpenUI** `rootView` drives WGPU traversal and inter-app `Output { }` leaves.
/// **XRenderer** may draw a separate **XUI** graph when `OpenVJXUIPipeline` supports the program.
public enum OpenVJVisualProgram: String, Sendable, CaseIterable {
    case `default`
    case sourceBrowserMixer
    case live
    case timedDemo

    /// Declarative tree (publish, stubs, legacy compiler input).
    public var openUIRootView: AnyView {
        switch self {
        case .default:
            return AnyView(OpenVJDefaultScene())
        case .sourceBrowserMixer:
            return AnyView(OpenVJSourceBrowserMixerScene())
        case .live:
            return AnyView(OpenVJLiveScene())
        case .timedDemo:
            return AnyView(OpenVJTimedDemoScene(time: OpenVJSceneTime.current))
        }
    }

    public var displayName: String {
        switch self {
        case .default: return "default"
        case .sourceBrowserMixer: return "source-browser-mixer"
        case .live: return "live"
        case .timedDemo: return "timed-demo"
        }
    }

    /// Parses `OPEN_VJ_SCENE` / CLI `--scene` names (case-insensitive).
    public static func parseSceneName(_ raw: String?) -> OpenVJVisualProgram? {
        switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case nil, "":
            return nil
        case "default", "openvjdefaultscene":
            return .default
        case "source-browser-mixer", "source_browser_mixer":
            return .sourceBrowserMixer
        case "live", "openvjlivescene":
            return .live
        case "timed-demo", "timed_demo", "openvjtimeddemoscene":
            return .timedDemo
        default:
            return nil
        }
    }
}

/// Resolves which program to run from environment and app settings.
public enum OpenVJVisualProgramResolver {
    /// `VisualView` at launch: inter-app on → `live`, else `OPEN_VJ_SCENE`, else deck mixer.
    public static func forApp(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        interAppPublishAtLaunch: Bool = InterAppTextureSettingsForResolver.interAppPublishAtLaunch
    ) -> OpenVJVisualProgram {
        if interAppPublishAtLaunch {
            return .live
        }
        if let parsed = OpenVJVisualProgram.parseSceneName(environment[OpenVJSceneEnvironment.sceneKey]) {
            return parsed
        }
        return .sourceBrowserMixer
    }

    /// Headless `OpenVJRender` and tests: honor scene name, fall back to `.default`.
    public static func forHeadless(sceneName: String?) -> OpenVJVisualProgram {
        if let parsed = OpenVJVisualProgram.parseSceneName(sceneName) {
            return parsed
        }
        if let sceneName, !sceneName.isEmpty {
            fputs(
                "[OpenVJ] Unknown OPEN_VJ_SCENE=\"\(sceneName)\"; using \(OpenVJVisualProgram.default.displayName).\n",
                stderr
            )
        }
        return .default
    }
}

/// Decouples resolver from `OpenVJApp` (keeps `OpenVJ` target free of AppKit).
public enum InterAppTextureSettingsForResolver {
    public static var interAppPublishAtLaunch: Bool {
        let keys = ["OPEN_VJ_INTER_APP_PUBLISH", "OPEN_VJ_SYPHON"]
        for key in keys {
            let env = ProcessInfo.processInfo.environment[key]?.lowercased()
            if env == "1" || env == "true" || env == "yes" { return true }
        }
        return UserDefaults.standard.bool(forKey: "openvj.publishInterAppTexture")
    }
}

/// Applies `rootView` on any `ViewSceneHosting` renderer.
public enum OpenVJVisualProgramApplication {
    public static func apply(_ program: OpenVJVisualProgram, to hosting: some ViewSceneHosting) {
        hosting.rootView = program.openUIRootView
    }
}
