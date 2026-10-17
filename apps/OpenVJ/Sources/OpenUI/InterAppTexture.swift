import Foundation

/// Renamed to `InterAppTextureOutput`; use `InterAppTextureOutput("name")` inside `Output { }`.
@available(*, deprecated, renamed: "InterAppTextureOutput")
public typealias InterAppTexture = InterAppTextureOutput

/// Short name for mixer / source-browser examples (`Some()` in scene DSL).
public typealias Some = SomeVisual

/// Demo generative leaf for inter-app publish scenes.
public struct SomeVisual: View {
    public typealias Body = Never

    public init() {}

    public var body: Never {
        fatalError("SomeVisual is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.drawWaveBody(mode: .sin, time: nil)
    }
}

extension SomeVisual: ViewRepresentable {
    var viewNode: ViewNode { .waveBody(.sin, explicitTime: nil) }
}
