import Foundation
import OpenUI
import OpenVJ

/// Wires `OpenVJVisualProgram` into renderers (OpenUI root + XRenderer program).
public enum OpenVJXVisualProgramApplication {
    public static func apply(
        _ program: OpenVJVisualProgram,
        hosting: some ViewSceneHosting,
        renderer: VisualRenderer?
    ) {
        OpenVJVisualProgramApplication.apply(program, to: hosting)
        if let xrenderer = renderer as? XRendererVisualRenderer {
            xrenderer.visualProgram = program
        }
    }
}
