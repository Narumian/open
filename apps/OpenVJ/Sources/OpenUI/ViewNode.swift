import Foundation

/// Type-erased view tree for storage and backend traversal.
public enum ViewNode: Equatable, Sendable {
    case empty
    case generativeShader
    case waveBody(WaveMode, explicitTime: Float?)
    case interAppTextureOutput(serverName: String, textureBus: String?)
    case interAppSubscribe(serverName: String)
    case encodedStream(preset: VideoEncodePreset)
    case muxedBroadcast(endpointLabel: String)
    case fileRecording(destinationLabel: String)
    case rawSampleBuffer
    /// Export sink group (`Output { … }`); children do not draw.
    case output([ViewNode])
    case video(fileURL: String)
    /// Source picker leaf (draws from catalog / deck selection during walk).
    case sourceBrowser(deckID: String?, mediaFolderURL: String?)
    /// Mix bus rendered to a named GPU texture, then blitted to the swapchain (XRenderer).
    indirect case offscreenTexture(name: String, content: ViewNode)
    /// Sequential stack (`Add`): first child full opacity, later layers ~55%.
    case group([ViewNode])
    /// Equal-weight mix (`Mixer`): each child uses opacity `1 / N`.
    case mixer([ViewNode])
}

protocol ViewRepresentable {
    var viewNode: ViewNode { get }
}

extension View {
    public func flattenedNode() -> ViewNode {
        if let representable = self as? any ViewRepresentable {
            return representable.viewNode
        }
        if Body.self == Never.self {
            return .empty
        }
        return body.flattenedNode()
    }
}
