import Foundation

/// Type-erased `Visual` for renderer storage and heterogeneous trees.
public struct AnyVisual: Visual {
    public typealias Body = Never

    public let node: VisualNode
    private let renderImpl: (inout VisualRenderContext) -> Void

    public init<V: Visual>(_ visual: V) {
        node = visual.flattenedNode()
        renderImpl = { context in
            visual.render(in: &context)
        }
    }

    public init(node: VisualNode, render: @escaping (inout VisualRenderContext) -> Void) {
        self.node = node
        renderImpl = render
    }

    public var body: Never {
        fatalError("AnyVisual is type-erased")
    }

    public func renderLeaf(in context: inout VisualRenderContext) {
        renderImpl(&context)
    }

    public func render(in context: inout VisualRenderContext) {
        renderImpl(&context)
    }
}

extension AnyVisual: VisualRepresentable {
    var visualNode: VisualNode { node }
}
