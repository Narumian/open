import Foundation

/// Type-erased `View` for renderer storage and heterogeneous trees.
public struct AnyView: View {
    public typealias Body = Never

    public let node: ViewNode
    private let renderImpl: (inout ViewRenderContext) -> Void

    public init<V: View>(_ view: V) {
        node = view.flattenedNode()
        renderImpl = { context in
            view.render(in: &context)
        }
    }

    public init(node: ViewNode, render: @escaping (inout ViewRenderContext) -> Void) {
        self.node = node
        renderImpl = render
    }

    public var body: Never {
        fatalError("AnyView is type-erased")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        renderImpl(&context)
    }

    public func render(in context: inout ViewRenderContext) {
        renderImpl(&context)
    }
}

extension AnyView: ViewRepresentable {
    var viewNode: ViewNode { node }
}
