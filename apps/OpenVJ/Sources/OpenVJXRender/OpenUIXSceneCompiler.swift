import Foundation
import OpenUI
import XRender
import XShader

/// Lowers a flattened `OpenUI` tree into a `CompiledFrame` for `XRenderer` / X3D.
enum OpenUIXSceneCompiler {
    struct Context {
        var playback: SourcePlaybackContext
        var nextTextureID: UInt32 = 1
        var videoTextureIDs: [String: TextureID] = [:]
        /// `OffscreenTexture` name → X3D color attachment from the last compile.
        var offscreenTextureIDs: [String: X3DResourceID] = [:]
    }

    private enum LayerMix {
        case none
        case add(layerIndex: Int)
        case mixer(layerIndex: Int, layerCount: Int)
    }

    private static let planeCamera = X3DCamera(
        position: SIMD3(0, 0, 2.5),
        target: .zero,
        fieldOfView: .pi / 3
    )
    private static let planeModel = X3DTransform.identity

    static func compile(
        node: ViewNode,
        framebuffer: RenderSize,
        playback: SourcePlaybackContext = SourcePlaybackContext()
    ) -> (frame: CompiledFrame, context: Context) {
        var ctx = Context(playback: playback)
        var builder = SceneBuilder(
            size: framebuffer,
            background: RenderColor(0, 0, 0, 1)
        )
        let full = RenderRect(x: 0, y: 0, width: framebuffer.width, height: framebuffer.height)
        emit(node: node, into: &builder, fullRect: full, mix: .none, context: &ctx)
        let frame = SceneCompiler.compile(
            builder.scene,
            canvas: framebuffer,
            framebuffer: framebuffer,
            fit: false
        )
        return (frame, ctx)
    }

    private static func emit(
        node: ViewNode,
        into builder: inout SceneBuilder,
        fullRect: RenderRect,
        mix: LayerMix,
        context: inout Context
    ) {
        switch node {
        case .empty:
            break
        case .output(let children):
            for child in children { emit(node: child, into: &builder, fullRect: fullRect, mix: mix, context: &context) }
        case .group(let children):
            for (index, child) in children.enumerated() {
                emit(node: child, into: &builder, fullRect: fullRect, mix: .add(layerIndex: index), context: &context)
            }
        case .mixer(let children):
            let count = max(1, children.count)
            for (index, child) in children.enumerated() {
                emit(node: child, into: &builder, fullRect: fullRect, mix: .mixer(layerIndex: index, layerCount: count), context: &context)
            }
        case .offscreenTexture(let name, let child):
            emitOffscreenTexture(name: name, node: child, into: &builder, fullRect: fullRect, context: &context)
        case .sourceBrowser(let deckID, let mediaFolderURL):
            let folder = mediaFolderURL.flatMap { URL(string: $0) }
            var playback = context.playback
            if let deckID {
                playback = SourcePlaybackContext(deckID: deckID)
            }
            var scratch = ViewRenderContext(
                frameTime: 0,
                sourcePlayback: playback,
                drawShaderLegacy: {},
                drawWaveBody: { _, _, _ in },
                drawVideo: { _, _ in },
                applyInterAppPublish: { _ in }
            )
            SourceBrowser.presentAndDraw(mediaFolderURL: folder, deckID: deckID, in: &scratch)
            context.playback = scratch.sourcePlayback
            emit(
                node: scratch.sourcePlayback.selection.opened().flattenedNode(),
                into: &builder,
                fullRect: fullRect,
                mix: mix,
                context: &context
            )
        case .video(let fileURLString):
            guard let url = URL(string: fileURLString) else { break }
            let key = url.absoluteString
            let texture: TextureID
            if let existing = context.videoTextureIDs[key] {
                texture = existing
            } else {
                texture = TextureID(context.nextTextureID)
                context.nextTextureID += 1
                context.videoTextureIDs[key] = texture
            }
            builder.sprite(texture, in: fullRect, opacity: layerOpacity(mix: mix), layer: .background)
        case .generativeShader:
            emitWaveX3D(into: &builder, fullRect: fullRect, mode: 0, mix: mix)
        case .waveBody(let mode, _):
            emitWaveX3D(into: &builder, fullRect: fullRect, mode: mode.rawValue, mix: mix)
        case .interAppTextureOutput, .interAppSubscribe, .encodedStream, .muxedBroadcast, .fileRecording, .rawSampleBuffer:
            break
        }
    }

    private static func emitOffscreenTexture(
        name: String,
        node: ViewNode,
        into builder: inout SceneBuilder,
        fullRect: RenderRect,
        context: inout Context
    ) {
        let texID = X3DResourceID(scope: textureScope(for: name), name: "color")
        context.offscreenTextureIDs[name] = texID
        builder.beginX3D(in: fullRect)
        builder.emitX3D(.resource(.texture(id: texID, format: .rgba8Unorm, size: .target)))
        builder.emitX3D(.beginPass(target: .texture(texID), load: .clear(SIMD4(0, 0, 0, 1)), depth: false))
        emitAsMixPlanes(node: node, into: &builder, fullRect: fullRect, context: &context)
        builder.emitX3D(.endPass)
        builder.emitX3D(.beginPass(target: .output, load: .clear(SIMD4(0, 0, 0, 1)), depth: false))
        builder.emitX3D(.blit(texID, blend: .alpha))
        builder.emitX3D(.endPass)
        builder.endX3D()
    }

    private static func emitAsMixPlanes(
        node: ViewNode,
        into builder: inout SceneBuilder,
        fullRect: RenderRect,
        context: inout Context
    ) {
        let children: [ViewNode]
        switch node {
        case .mixer(let mixerChildren):
            children = mixerChildren
        case .group(let groupChildren):
            children = groupChildren
        default:
            children = [node]
        }
        let count = max(1, children.count)
        for (index, child) in children.enumerated() {
            let mix: LayerMix
            switch node {
            case .mixer:
                mix = .mixer(layerIndex: index, layerCount: count)
            default:
                mix = .none
            }
            builder.beginX3DView(in: fullRect)
            emit(node: child, into: &builder, fullRect: fullRect, mix: mix, context: &context)
            builder.endX3DPlane(camera: planeCamera, model: planeModel)
        }
    }

    private static func textureScope(for name: String) -> Int {
        var hasher = Hasher()
        hasher.combine("openvj.offscreen")
        hasher.combine(name)
        return hasher.finalize()
    }

    private static func layerOpacity(mix: LayerMix) -> Float {
        switch mix {
        case .none:
            return 1
        case .add(let index):
            return index == 0 ? 1 : 0.55
        case .mixer(_, let count):
            return 1 / Float(max(1, count))
        }
    }

    private static func emitWaveX3D(
        into builder: inout SceneBuilder,
        fullRect: RenderRect,
        mode: Float,
        mix: LayerMix
    ) {
        builder.beginX3D(in: fullRect)
        builder.emitX3D(.beginPass(target: .output, load: .clear(SIMD4(0, 0, 0, 1)), depth: false))
        builder.emitX3D(.draw(X3DDraw(
            shader: OpenVJX3DGenerativeShader.key,
            vertexEntry: "x3d_fullscreen",
            fragmentEntry: "openvj_wave_fs",
            vertexCount: 3,
            blend: .alpha,
            uniforms: [mode, layerOpacity(mix: mix)]
        )))
        builder.emitX3D(.endPass)
        builder.endX3D()
    }
}
