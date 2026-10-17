import Foundation

/// Backend-neutral draw commands issued while traversing a `Visual` tree.
public struct VisualRenderContext {
    public var frameTime: Float

    private var waveLayerIndex: Int
    private let drawShaderLegacy: () -> Void
    private let drawWaveBodyImpl: (WaveMode, Float, Float) -> Void
    private let applyInterAppPublish: (PublisherConfiguration) -> Void

    init(
        frameTime: Float,
        drawShaderLegacy: @escaping () -> Void,
        drawWaveBody: @escaping (WaveMode, Float, Float) -> Void,
        applyInterAppPublish: @escaping (PublisherConfiguration) -> Void
    ) {
        self.frameTime = frameTime
        waveLayerIndex = 0
        self.drawShaderLegacy = drawShaderLegacy
        drawWaveBodyImpl = drawWaveBody
        self.applyInterAppPublish = applyInterAppPublish
    }

    /// Called by the `InterAppTexture` visual leaf during tree walk.
    public mutating func requestInterAppPublish(serverName: String, enabled: Bool = true) {
        applyInterAppPublish(PublisherConfiguration(serverName: serverName, enabled: enabled))
    }

    /// Legacy full-screen generative path (single sin-style warp, opaque).
    public func drawGenerativeShader() {
        drawShaderLegacy()
    }

    /// Sin / tan wave-body leaf draw. `time` nil uses `frameTime`.
    public mutating func drawWaveBody(mode: WaveMode, time: Float?) {
        let resolvedTime = time ?? frameTime
        let layerAlpha: Float = waveLayerIndex == 0 ? 1 : 0.55
        drawWaveBodyImpl(mode, resolvedTime, layerAlpha)
        waveLayerIndex += 1
    }

    /// Renders a flattened node tree using the same draw hooks as the declarative API.
    public mutating func render(node: VisualNode) {
        switch node {
        case .empty:
            break
        case .generativeShader:
            drawGenerativeShader()
        case .waveBody(let mode, let explicitTime):
            drawWaveBody(mode: mode, time: explicitTime)
        case .interAppPublish(let serverName):
            requestInterAppPublish(serverName: serverName)
        case .group(let children):
            for child in children {
                render(node: child)
            }
        }
    }
}
