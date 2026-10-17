import Foundation

/// Composes multiple views with **equal-weight VJ mix** semantics (v0).
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
public struct Mixer<Content: View>: View {
    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Never {
        fatalError("Mixer is a composite container")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        let layerCount = max(1, Self.layerCount(of: content))
        context.beginEqualWeightMix(layerCount: layerCount)
        content.render(in: &context)
        context.endEqualWeightMix()
    }
}

extension Mixer: ViewRepresentable {
    var viewNode: ViewNode {
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
    static func layerCount(of view: some View) -> Int {
        switch view.flattenedNode() {
        case .group(let children), .mixer(let children):
            return children.count
        case .empty:
            return 0
        default:
            return 1
        }
    }
}
