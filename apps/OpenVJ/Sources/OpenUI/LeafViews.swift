import Foundation

/// Draws nothing.
public struct EmptyView: View {
    public typealias Body = Never

    public init() {}

    public var body: Never {
        fatalError("EmptyView is a leaf")
    }
}

extension EmptyView: ViewRepresentable {
    var viewNode: ViewNode { .empty }
}

/// Full-screen generative WGSL shader (wired in `WGPUVisualRenderer`).
public struct ShaderView: View {
    public typealias Body = Never

    public init() {}

    public var body: Never {
        fatalError("ShaderView is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.drawGenerativeShader()
    }
}

extension ShaderView: ViewRepresentable {
    var viewNode: ViewNode { .generativeShader }
}
