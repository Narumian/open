import AVFoundation
import CoreVideo
import CWGPU
import Foundation
import OpenUI
import OpenVJ
import XRender
import XRenderApple
import XRenderWGPU
import XShader
import XUI
import XUIHost

/// OpenVJ shell around SwiftX **`XRenderer`** (`WGPURenderer`).
///
/// Default: **XUI** `X3DView` deck mixer. Set `OPEN_VJ_RENDERER=openui` for the legacy
/// `OpenUIXSceneCompiler` + `ViewSceneHosting.rootView` path.
public final class XRendererVisualRenderer: VisualRenderer, ViewSceneHosting {
    private enum SceneBackend {
        case xui
        case openUI
    }

    private let backend: WGPURenderer
    private let sceneBackend: SceneBackend
    private var configuredWidth: UInt32 = 0
    private var configuredHeight: UInt32 = 0
    private let startTime = CFAbsoluteTimeGetCurrent()
    private var videoSources: [String: VideoFrameSource] = [:]
    private var videoTextureIDs: [String: TextureID] = [:]
    private var nextVideoTextureID: UInt32 = 1
    private var sourcePlayback = SourcePlaybackContext()

    private let xuiHost: XUIHost
    private let frameContext = OpenVJFrameContext()

    private var interAppPublisher: InterAppTexturePublisher?
    private var interAppPublisherServerName: String?
    private var interAppPublishTextureBus: String?
    private static var didLogMissingInterAppBackend = false

    public var rootView: OpenUI.AnyView = OpenUI.AnyView(OpenVJSourceBrowserMixerScene())
    public var visualProgram: OpenVJVisualProgram = .sourceBrowserMixer
    public var sceneInterAppPublishSuppressed = false

    public init?(metalLayer: UnsafeMutableRawPointer) {
        let raw = ProcessInfo.processInfo.environment["OPEN_VJ_RENDERER"]?.lowercased()
        sceneBackend = (raw == "openui" || raw == "open-ui") ? .openUI : .xui

        var instancePtr: UnsafeMutableRawPointer?
        var surfacePtr: UnsafeMutableRawPointer?
        xrender_apple_create_surface(metalLayer, &instancePtr, &surfacePtr)
        guard let instancePtr, let surfacePtr,
              let backend = WGPURenderer(ownedInstancePointer: instancePtr, surfacePointer: surfacePtr)
        else { return nil }
        self.backend = backend
        backend.registerX3DShader(OpenVJX3DGenerativeShader.key, source: OpenVJX3DGenerativeShader.fragmentWGSL)

        xuiHost = XUIHost(
            size: RenderSize(width: 1280, height: 720),
            background: RenderColor(0, 0, 0, 1)
        )
        var environment = EnvironmentValues()
        environment.environmentObject(frameContext)
        xuiHost.environment = environment

        wireFrameContext()
    }

    @discardableResult
    public func configure(width: UInt32, height: UInt32) -> Bool {
        guard width > 0, height > 0 else { return false }
        backend.configure(width: width, height: height)
        configuredWidth = width
        configuredHeight = height
        xuiHost.size = RenderSize(width: Float(width), height: Float(height))
        interAppPublisher?.resize(width: width, height: height)
        return true
    }

    public func setInterAppPublisher(_ publisher: InterAppTexturePublisher?) {
        interAppPublisher?.detach()
        interAppPublisher = publisher
        if publisher == nil {
            interAppPublisherServerName = nil
            interAppPublishTextureBus = nil
        }
        interAppPublisher?.attach(device: backend.webGPUDevice, queue: backend.webGPUQueue)
        if configuredWidth > 0, configuredHeight > 0 {
            interAppPublisher?.resize(width: configuredWidth, height: configuredHeight)
        }
    }

    public func render(frameTime: CFTimeInterval?) -> VisualFrameStatus {
        guard configuredWidth > 0, configuredHeight > 0 else { return .notConfigured }
        let elapsed = Float(frameTime ?? (CFAbsoluteTimeGetCurrent() - startTime))
        OpenVJSceneTime.current = elapsed

        switch effectiveSceneBackend() {
        case .openUI:
            return renderOpenUI(elapsed: elapsed)
        case .xui:
            return renderXUI(elapsed: elapsed)
        }
    }

    private func effectiveSceneBackend() -> SceneBackend {
        if sceneBackend == .openUI { return .openUI }
        if OpenVJXUIPipelineResolver.preferred(for: visualProgram) != nil {
            return .xui
        }
        return .openUI
    }

    // MARK: - XUI

    private func renderXUI(elapsed: Float) -> VisualFrameStatus {
        applyPublishLeaves(in: rootView.node)

        var compiled: CompiledFrame?
        var textureCatalog: [String: X3DResourceID] = [:]
        let semaphore = DispatchSemaphore(value: 0)

        Task { @XUIActor in
            xuiHost.environment.fxTime = Double(elapsed)
            let xFrame = await xuiHost.render(OpenVJDeckMixerXUIView(), time: Double(elapsed))
            textureCatalog = OpenVJXUITextureCatalog.textureIDs(in: xFrame.scene)
            let size = RenderSize(width: Float(configuredWidth), height: Float(configuredHeight))
            compiled = SceneCompiler.compile(
                xFrame.scene,
                canvas: size,
                framebuffer: size,
                fit: false
            )
            semaphore.signal()
        }
        semaphore.wait()

        guard let compiled else { return .skipped }
        backend.render(compiled, time: elapsed)
        publishInterAppFrame(textureCatalog: textureCatalog)
        return .rendered
    }

    private func wireFrameContext() {
        frameContext.onPresentSourceBrowser = { [weak self] deckID in
            let configuration = SourceBrowserConfiguration(
                mediaFolderURL: self?.frameContext.mediaFolderURL,
                deckID: deckID
            )
            SourceBrowserUI.requestPresent(configuration)
        }
        frameContext.drawDeck = { [weak self] deckID, builder, fullRect in
            self?.drawDeck(deckID: deckID, into: &builder, fullRect: fullRect)
        }
    }

    private func drawDeck(deckID: String, into builder: inout SceneBuilder, fullRect: RenderRect) {
        let state = SourceDeckRegistry.selectionState(for: deckID)
        if let folder = frameContext.mediaFolderURL {
            state.mediaFolderURL = folder
        }
        let node = state.selection.opened().flattenedNode()
        emitOpenUINode(node: node, into: &builder, fullRect: fullRect, opacity: 0.5)
    }

    private func emitOpenUINode(
        node: ViewNode,
        into builder: inout SceneBuilder,
        fullRect: RenderRect,
        opacity: Float
    ) {
        switch node {
        case .empty:
            break
        case .video(let fileURLString):
            guard let url = URL(string: fileURLString) else { break }
            let key = url.absoluteString
            let texture: TextureID
            if let existing = videoTextureIDs[key] {
                texture = existing
            } else {
                texture = TextureID(nextVideoTextureID)
                nextVideoTextureID += 1
                videoTextureIDs[key] = texture
            }
            uploadVideoTexture(url: url, textureID: texture)
            builder.sprite(texture, in: fullRect, opacity: opacity, layer: .background)
        case .generativeShader, .waveBody:
            break
        default:
            break
        }
    }

    private func uploadVideoTexture(url: URL, textureID: TextureID) {
        guard let source = videoSource(for: url),
              let pixelBuffer = source.copyCurrentPixelBuffer(),
              let rgba = Self.rgbaBytes(from: pixelBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        backend.registerTexture(textureID, rgba: rgba, width: width, height: height)
    }

    // MARK: - OpenUI compiler (legacy)

    private func renderOpenUI(elapsed: Float) -> VisualFrameStatus {
        applyPublishLeaves(in: rootView.node)

        let size = RenderSize(width: Float(configuredWidth), height: Float(configuredHeight))
        let (frame, context) = OpenUIXSceneCompiler.compile(
            node: rootView.node,
            framebuffer: size,
            playback: sourcePlayback
        )
        sourcePlayback = context.playback
        uploadVideoTextures(compilerContext: context)
        backend.render(frame, time: elapsed)
        publishInterAppFrame(offscreenBuses: context.offscreenTextureIDs)
        return .rendered
    }

    // MARK: - Inter-app

    private func applyPublishLeaves(in node: ViewNode) {
        switch node {
        case .output(let children):
            for child in children {
                if case .interAppTextureOutput(let serverName, let textureBus) = child {
                    applyInterAppPublishConfiguration(
                        PublisherConfiguration(
                            serverName: serverName,
                            enabled: true,
                            textureBus: textureBus
                        )
                    )
                } else {
                    applyPublishLeaves(in: child)
                }
            }
        case .offscreenTexture(_, let child):
            applyPublishLeaves(in: child)
        case .group(let children), .mixer(let children):
            for child in children {
                applyPublishLeaves(in: child)
            }
        default:
            break
        }
    }

    private func applyInterAppPublishConfiguration(_ configuration: PublisherConfiguration) {
        if sceneInterAppPublishSuppressed {
            if interAppPublisher != nil {
                setInterAppPublisher(nil)
            }
            return
        }

        guard configuration.enabled else {
            setInterAppPublisher(nil)
            return
        }

        interAppPublishTextureBus = configuration.textureBus

        if let interAppPublisher,
           interAppPublisherServerName == nil || interAppPublisherServerName == configuration.serverName
        {
            interAppPublisherServerName = configuration.serverName
            interAppPublisher.isEnabled = true
            return
        }

        interAppPublisher?.detach()
        interAppPublisher = nil
        interAppPublisherServerName = nil

        if let publisher = InterAppTextureRegistry.Output.makePublisher(configuration: configuration) {
            interAppPublisher = publisher
            interAppPublisherServerName = configuration.serverName
            interAppPublisher?.attach(device: backend.webGPUDevice, queue: backend.webGPUQueue)
            if configuredWidth > 0, configuredHeight > 0 {
                interAppPublisher?.resize(width: configuredWidth, height: configuredHeight)
            }
        } else if !Self.didLogMissingInterAppBackend {
            Self.didLogMissingInterAppBackend = true
            fputs(
                "[OpenVJ] Inter-app texture publish requested but no backend is linked (e.g. OpenVJSyphon). Run Scripts/fetch-syphon.sh and rebuild.\n",
                stderr
            )
        }
    }

    private func publishInterAppFrame(offscreenBuses: [String: X3DResourceID]) {
        guard let interAppPublisher, interAppPublisher.isEnabled else { return }
        if let bus = interAppPublishTextureBus, let resourceID = offscreenBuses[bus],
           let sampled = backend.x3dColorTexture(id: resourceID)
        {
            interAppPublisher.publish(texture: sampled.texture, width: sampled.width, height: sampled.height)
        }
    }

    private func publishInterAppFrame(textureCatalog: [String: X3DResourceID]) {
        publishInterAppFrame(offscreenBuses: textureCatalog)
    }

    private func uploadVideoTextures(compilerContext: OpenUIXSceneCompiler.Context) {
        for (urlString, textureID) in compilerContext.videoTextureIDs {
            guard let url = URL(string: urlString) else { continue }
            uploadVideoTexture(url: url, textureID: textureID)
        }
    }

    private func videoSource(for url: URL) -> VideoFrameSource? {
        let key = url.absoluteString
        if let existing = videoSources[key] { return existing }
        guard url.isFileURL, let created = VideoFrameSource(fileURL: url) else { return nil }
        created.play()
        videoSources[key] = created
        return created
    }

    private static func rgbaBytes(from pixelBuffer: CVPixelBuffer) -> [UInt8]? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var out = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            let src = base.advanced(by: row * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for col in 0..<width {
                let si = col * 4
                let di = (row * width + col) * 4
                out[di] = src[si + 2]
                out[di + 1] = src[si + 1]
                out[di + 2] = src[si]
                out[di + 3] = src[si + 3]
            }
        }
        return out
    }
}
