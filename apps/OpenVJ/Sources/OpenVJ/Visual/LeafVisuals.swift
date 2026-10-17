import Foundation

/// Draws nothing.
public struct EmptyVisual: Visual {
    public typealias Body = Never

    public init() {}

    public var body: Never {
        fatalError("EmptyVisual is a leaf")
    }
}

extension EmptyVisual: VisualRepresentable {
    var visualNode: VisualNode { .empty }
}

/// Full-screen generative WGSL shader (wired in `WGPUVisualRenderer`).
public struct ShaderVisual: Visual {
    public typealias Body = Never

    public init() {}

    public var body: Never {
        fatalError("ShaderVisual is a leaf")
    }

    public func renderLeaf(in context: inout VisualRenderContext) {
        context.drawGenerativeShader()
    }
}

extension ShaderVisual: VisualRepresentable {
    var visualNode: VisualNode { .generativeShader }
}
