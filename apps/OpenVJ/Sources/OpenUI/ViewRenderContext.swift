import Foundation

/// Backend-neutral configuration for inter-app texture publish during tree walk.
public struct InterAppPublishConfiguration: Sendable {
    public var serverName: String
    public var enabled: Bool

    public init(serverName: String, enabled: Bool = true) {
        self.serverName = serverName
        self.enabled = enabled
    }
}

/// Backend-neutral draw commands issued while traversing a `View` tree.
public struct ViewRenderContext {
    public var frameTime: Float

    private var blendLayerIndex: Int
    private var equalWeightMixLayerCount: Int?
    private var savedEqualWeightMixLayerCount: Int?
    private var savedBlendLayerIndex: Int?
    private let drawShaderLegacy: () -> Void
    private let drawWaveBodyImpl: (WaveMode, Float, Float) -> Void
    private let drawVideoImpl: (URL, Float) -> Void
    private let drawInterAppTextureInputImpl: (String, Float) -> Void
    private let applyInterAppPublish: (InterAppPublishConfiguration) -> Void
    private let applyInterAppSubscribe: (InterAppSubscribeConfiguration) -> Void

    public init(
        frameTime: Float,
        drawShaderLegacy: @escaping () -> Void,
        drawWaveBody: @escaping (WaveMode, Float, Float) -> Void,
        drawVideo: @escaping (URL, Float) -> Void,
        drawInterAppTextureInput: @escaping (String, Float) -> Void = { _, _ in },
        applyInterAppPublish: @escaping (InterAppPublishConfiguration) -> Void,
        applyInterAppSubscribe: @escaping (InterAppSubscribeConfiguration) -> Void = { _ in }
    ) {
        self.frameTime = frameTime
        blendLayerIndex = 0
        equalWeightMixLayerCount = nil
        self.drawShaderLegacy = drawShaderLegacy
        drawWaveBodyImpl = drawWaveBody
        drawVideoImpl = drawVideo
        drawInterAppTextureInputImpl = drawInterAppTextureInput
        self.applyInterAppPublish = applyInterAppPublish
        self.applyInterAppSubscribe = applyInterAppSubscribe
    }

    private mutating func nextBlendLayerAlpha() -> Float {
        if let layerCount = equalWeightMixLayerCount, layerCount > 0 {
            blendLayerIndex += 1
            return 1 / Float(layerCount)
        }
        let alpha: Float = blendLayerIndex == 0 ? 1 : 0.55
        blendLayerIndex += 1
        return alpha
    }

    mutating func beginEqualWeightMix(layerCount: Int) {
        savedEqualWeightMixLayerCount = equalWeightMixLayerCount
        savedBlendLayerIndex = blendLayerIndex
        equalWeightMixLayerCount = max(1, layerCount)
        blendLayerIndex = 0
    }

    mutating func endEqualWeightMix() {
        equalWeightMixLayerCount = savedEqualWeightMixLayerCount
        blendLayerIndex = savedBlendLayerIndex ?? 0
        savedEqualWeightMixLayerCount = nil
        savedBlendLayerIndex = nil
    }

    /// Called by the `InterAppTexture` view leaf during tree walk.
    public mutating func requestInterAppPublish(serverName: String, enabled: Bool = true) {
        applyInterAppPublish(InterAppPublishConfiguration(serverName: serverName, enabled: enabled))
    }

    /// Called by `InterAppTextureInput` during tree walk.
    public mutating func requestInterAppSubscribe(serverName: String) {
        applyInterAppSubscribe(InterAppSubscribeConfiguration(serverName: serverName))
    }

    /// Remote inter-app texture leaf draw (`InterAppTextureInput`).
    public mutating func drawInterAppTextureInput(serverName: String) {
        requestInterAppSubscribe(serverName: serverName)
        drawInterAppTextureInputImpl(serverName, nextBlendLayerAlpha())
    }

    /// Legacy full-screen generative path (single sin-style warp, opaque).
    public func drawGenerativeShader() {
        drawShaderLegacy()
    }

    /// Sin / tan wave-body leaf draw. `time` nil uses `frameTime`.
    public mutating func drawWaveBody(mode: WaveMode, time: Float?) {
        let resolvedTime = time ?? frameTime
        drawWaveBodyImpl(mode, resolvedTime, nextBlendLayerAlpha())
    }

    /// Local video file leaf draw (`Video`).
    public mutating func drawVideo(fileURL: URL) {
        drawVideoImpl(fileURL, nextBlendLayerAlpha())
    }

    /// Renders a flattened node tree using the same draw hooks as the declarative API.
    public mutating func render(node: ViewNode) {
        switch node {
        case .empty:
            break
        case .generativeShader:
            drawGenerativeShader()
        case .waveBody(let mode, let explicitTime):
            drawWaveBody(mode: mode, time: explicitTime)
        case .interAppPublish(let serverName):
            requestInterAppPublish(serverName: serverName)
        case .interAppSubscribe(let serverName):
            drawInterAppTextureInput(serverName: serverName)
        case .video(let fileURLString):
            if let url = URL(string: fileURLString) {
                drawVideo(fileURL: url)
            }
        case .group(let children):
            for child in children {
                render(node: child)
            }
        case .mixer(let children):
            beginEqualWeightMix(layerCount: children.count)
            for child in children {
                render(node: child)
            }
            endEqualWeightMix()
        }
    }
}
