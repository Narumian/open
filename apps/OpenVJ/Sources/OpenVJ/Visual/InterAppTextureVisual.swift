import Foundation

/// Declarative inter-app texture publish leaf (Syphon when `OpenVJSyphon` is linked).
///
/// Does not draw; during tree walk it configures `InterAppTexturePublisher` on the renderer
/// via `PublisherConfiguration(serverName:label, enabled: true)`.
public struct InterAppTexture: Visual {
    public typealias Body = Never

    public let serverName: String

    public init(_ label: String) {
        serverName = label
    }

    public var body: Never {
        fatalError("InterAppTexture is a leaf")
    }

    public func renderLeaf(in context: inout VisualRenderContext) {
        context.requestInterAppPublish(serverName: serverName)
    }
}

extension InterAppTexture: VisualRepresentable {
    var visualNode: VisualNode { .interAppPublish(serverName: serverName) }
}

/// Demo generative leaf for inter-app publish scenes.
public struct SomeVisual: Visual {
    public typealias Body = Never

    public init() {}

    public var body: Never {
        fatalError("SomeVisual is a leaf")
    }

    public func renderLeaf(in context: inout VisualRenderContext) {
        context.drawWaveBody(mode: .sin, time: nil)
    }
}

extension SomeVisual: VisualRepresentable {
    var visualNode: VisualNode { .waveBody(.sin, explicitTime: nil) }
}

/// Example scene: publish frames under a named server, then draw `SomeVisual`.
public struct OpenVJInterAppTextureScene: Visual {
    public init() {}

    public var body: Add<TupleVisual2<InterAppTexture, SomeVisual>> {
        Add {
            InterAppTexture("OpenVJ")
            SomeVisual()
        }
    }
}
