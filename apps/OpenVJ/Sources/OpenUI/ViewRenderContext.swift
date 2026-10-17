import Foundation

/// Non-GPU export sink requested from `Output { }` stub leaves (encoder, file, broadcast).
public enum StreamOutputKind: Sendable, Equatable {
    case encodedVideo(preset: VideoEncodePreset)
    case muxedBroadcast(endpointLabel: String)
    case fileRecording(destinationLabel: String)
    case rawSampleBuffer
}

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
    private let applySourceBrowser: (SourceBrowserConfiguration) -> Void
    private let applyStreamOutputStub: (StreamOutputKind) -> Void

    public init(
        frameTime: Float,
        drawShaderLegacy: @escaping () -> Void,
        drawWaveBody: @escaping (WaveMode, Float, Float) -> Void,
        drawVideo: @escaping (URL, Float) -> Void,
        drawInterAppTextureInput: @escaping (String, Float) -> Void = { _, _ in },
        applyInterAppPublish: @escaping (InterAppPublishConfiguration) -> Void,
        applyInterAppSubscribe: @escaping (InterAppSubscribeConfiguration) -> Void = { _ in },
        applySourceBrowser: @escaping (SourceBrowserConfiguration) -> Void = { _ in },
        applyStreamOutputStub: @escaping (StreamOutputKind) -> Void = { _ in }
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
        self.applySourceBrowser = applySourceBrowser
        self.applyStreamOutputStub = applyStreamOutputStub
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

    /// Called by `InterAppTextureOutput` during tree walk.
    public mutating func requestInterAppTextureOutput(serverName: String, enabled: Bool = true) {
        applyInterAppPublish(InterAppPublishConfiguration(serverName: serverName, enabled: enabled))
    }

    /// Stub stream outputs (`EncodedStream`, `FileRecording`, …) inside `Output { }`.
    public mutating func registerStreamOutput(_ kind: StreamOutputKind) {
        applyStreamOutputStub(kind)
    }

    /// Called by `InterAppTextureInput` during tree walk.
    public mutating func requestInterAppSubscribe(serverName: String) {
        applyInterAppSubscribe(InterAppSubscribeConfiguration(serverName: serverName))
    }

    /// Called by `SourceBrowser` during tree walk (opens / refreshes AppKit UI when registered).
    public mutating func requestSourceBrowser(_ configuration: SourceBrowserConfiguration) {
        applySourceBrowser(configuration)
        SourceBrowserUI.requestPresent(configuration)
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
        case .interAppTextureOutput(let serverName):
            requestInterAppTextureOutput(serverName: serverName)
        case .interAppSubscribe(let serverName):
            drawInterAppTextureInput(serverName: serverName)
        case .video(let fileURLString):
            if let url = URL(string: fileURLString) {
                drawVideo(fileURL: url)
            }
        case .sourceBrowser:
            let selectionState = SourceCatalogRegistry.selectionState
            requestSourceBrowser(SourceBrowserConfiguration(mediaFolderURL: selectionState.mediaFolderURL))
            SourceRendering.draw(selection: selectionState.selection, in: &self)
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
        case .encodedStream(let preset):
            registerStreamOutput(.encodedVideo(preset: preset))
        case .muxedBroadcast(let endpointLabel):
            registerStreamOutput(.muxedBroadcast(endpointLabel: endpointLabel))
        case .fileRecording(let destinationLabel):
            registerStreamOutput(.fileRecording(destinationLabel: destinationLabel))
        case .rawSampleBuffer:
            registerStreamOutput(.rawSampleBuffer)
        case .output(let children):
            for child in children {
                render(node: child)
            }
        }
    }
}
