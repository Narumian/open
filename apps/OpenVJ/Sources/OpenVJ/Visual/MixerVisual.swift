import Foundation

/// Composes multiple visuals with **equal-weight VJ mix** semantics (v0).
///
/// Each child draws full-screen in tree order with opacity `1 / N` (`N` = child count).
/// Combined with the shared src-alpha pipeline, layers contribute evenly — a crossfade-style
/// mix rather than the sequential stack used by `Add` (first layer opaque, later ~55%).
///
/// ```swift
/// Mixer {
///     SinBody()
///     TanBody().time(t)
///     Video(path: "/path/to/clip.mov")
/// }
/// ```
public struct Mixer<Content: Visual>: Visual {
    public let content: Content

    public init(@VisualBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Never {
        fatalError("Mixer is a composite container")
    }

    public func renderLeaf(in context: inout VisualRenderContext) {
        let layerCount = max(1, Self.layerCount(of: content))
        context.beginEqualWeightMix(layerCount: layerCount)
        content.render(in: &context)
        context.endEqualWeightMix()
    }
}

extension Mixer: VisualRepresentable {
    var visualNode: VisualNode {
        switch content.flattenedNode() {
        case .group(let children):
            return .mixer(children)
        case .mixer(let children):
            return .mixer(children)
        default:
            return .mixer([content.flattenedNode()])
        }
    }
}

extension Mixer {
    static func layerCount(of visual: some Visual) -> Int {
        switch visual.flattenedNode() {
        case .group(let children), .mixer(let children):
            return children.count
        case .empty:
            return 0
        default:
            return 1
        }
    }
}
