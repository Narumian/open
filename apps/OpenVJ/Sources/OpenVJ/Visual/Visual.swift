import Foundation

/// SwiftUI-style declarative visual tree. Leaf types use `Body == Never` and draw via `renderLeaf`.
public protocol Visual {
    associatedtype Body: Visual

    @VisualBuilder var body: Body { get }
}

extension Never: Visual {
    @VisualBuilder public var body: Never {
        fatalError("Never is not a renderable visual")
    }
}

extension Visual where Body == Never {
    /// Leaf visuals override this to issue draw commands.
    public func renderLeaf(in context: inout VisualRenderContext) {}
}

extension Visual {
    /// Walks `body` for composites, or `renderLeaf` for leaves.
    public func render(in context: inout VisualRenderContext) {
        _VisualRenderWalker.walk(self, in: &context)
    }
}

private enum _VisualRenderWalker {
    static func walk<V: Visual>(_ visual: V, in context: inout VisualRenderContext) {
        renderLeafIfNeeded(visual, in: &context)
    }

    static func renderLeafIfNeeded<V: Visual>(_ visual: V, in context: inout VisualRenderContext)
    where V.Body == Never {
        visual.renderLeaf(in: &context)
    }

    static func renderLeafIfNeeded<V: Visual>(_ visual: V, in context: inout VisualRenderContext) {
        visual.body.render(in: &context)
    }
}

/// Default generative scene shipped with OpenVJ (single shader leaf).
public struct OpenVJDefaultScene: Visual {
    public init() {}

    public var body: ShaderVisual {
        ShaderVisual()
    }
}
