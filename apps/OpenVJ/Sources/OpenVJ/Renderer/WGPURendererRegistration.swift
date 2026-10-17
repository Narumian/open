import Foundation

func registerDefaultWGPURendererFactory() {
    VisualRender.registerRendererFactory { attachment in
        WGPUVisualRenderer(metalLayer: attachment.metalLayer)
    }
}
