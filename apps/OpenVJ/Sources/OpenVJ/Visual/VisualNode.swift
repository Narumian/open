import Foundation

/// Type-erased visual tree for storage and backend traversal.
public enum VisualNode: Equatable, Sendable {
    case empty
    case generativeShader
    case waveBody(WaveMode, explicitTime: Float?)
    case interAppPublish(serverName: String)
    case video(fileURL: String)
    /// Sequential stack (`Add`): first child full opacity, later layers ~55%.
    case group([VisualNode])
    /// Equal-weight mix (`Mixer`): each child uses opacity `1 / N`.
    case mixer([VisualNode])
}

protocol VisualRepresentable {
    var visualNode: VisualNode { get }
}

extension Visual {
    public func flattenedNode() -> VisualNode {
        if let representable = self as? any VisualRepresentable {
            return representable.visualNode
        }
        if Body.self == Never.self {
            return .empty
        }
        return body.flattenedNode()
    }
}
