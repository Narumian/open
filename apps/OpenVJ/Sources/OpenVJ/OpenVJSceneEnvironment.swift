import Foundation
import OpenUI

/// Resolves the root scene from `OPEN_VJ_SCENE` (headless CLI and tests).
public enum OpenVJSceneEnvironment {
    public static let sceneKey = "OPEN_VJ_SCENE"

    public static func resolvedRootView() -> AnyView {
        rootView(named: ProcessInfo.processInfo.environment[sceneKey])
    }

    public static func rootView(named name: String?) -> AnyView {
        OpenVJVisualProgramResolver.forHeadless(sceneName: name).openUIRootView
    }
}
