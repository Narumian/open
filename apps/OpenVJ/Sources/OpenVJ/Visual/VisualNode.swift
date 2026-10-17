import Foundation

/// Type-erased visual tree for storage and backend traversal.
public enum VisualNode: Equatable, Sendable {
    case empty
    case generativeShader
    case waveBody(WaveMode, explicitTime: Float?)
    case interAppPublish(serverName: String)
    case group([VisualNode])
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
