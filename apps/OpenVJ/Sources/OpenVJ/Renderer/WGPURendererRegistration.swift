import Foundation

/// Legacy in-tree wgpu path (`OPEN_VJ_RENDERER=wgpu`). Prefer SwiftX `XRenderer` when `OpenVJXRender` is linked.
public func registerLegacyWGPURendererFactory() {
    VisualRender.registerRendererFactory { attachment in
        WGPUVisualRenderer(metalLayer: attachment.metalLayer)
    }
}

func registerDefaultWGPURendererFactory() {
    registerLegacyWGPURendererFactory()
}
