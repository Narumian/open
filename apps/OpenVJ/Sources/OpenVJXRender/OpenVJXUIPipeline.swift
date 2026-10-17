import Foundation
import OpenVJ

/// Which native **XUI** graph `XRendererVisualRenderer` draws (when not using `OPEN_VJ_RENDERER=openui`).
public enum OpenVJXUIPipeline: Sendable {
    case deckMixer
}

public enum OpenVJXUIPipelineResolver {
    public static func preferred(for program: OpenVJVisualProgram) -> OpenVJXUIPipeline? {
        switch program {
        case .sourceBrowserMixer:
            return .deckMixer
        case .default, .live, .timedDemo:
            return nil
        }
    }
}
