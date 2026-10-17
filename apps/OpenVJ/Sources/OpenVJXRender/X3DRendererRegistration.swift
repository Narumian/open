import Foundation
import OpenVJ

/// Installs the default `VisualRenderer` factory: SwiftX **`XRenderer`** (`WGPURenderer` + X3D graph).
///
/// - `OPEN_VJ_RENDERER=wgpu` / `legacy` — in-tree `WGPUVisualRenderer`
/// - `OPEN_VJ_RENDERER=openui` — `OpenUIXSceneCompiler` instead of native XUI X3D (XRenderer only)
public func openVJXRenderBootstrap() {
    let raw = ProcessInfo.processInfo.environment["OPEN_VJ_RENDERER"]?.lowercased()
    if raw == "wgpu" || raw == "legacy" {
        registerLegacyWGPURendererFactory()
        return
    }
    VisualRender.registerRendererFactory { attachment in
        XRendererVisualRenderer(metalLayer: attachment.metalLayer)
    }
}
