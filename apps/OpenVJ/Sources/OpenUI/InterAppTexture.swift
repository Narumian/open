import Foundation

/// Declarative inter-app texture publish leaf (Syphon when `OpenVJSyphon` is linked).
///
/// Does not draw; during tree walk it configures the renderer's inter-app publisher
/// via `InterAppPublishConfiguration`.
public struct InterAppTexture: View {
    public typealias Body = Never

    public let serverName: String

    public init(_ label: String) {
        serverName = label
    }

    public var body: Never {
        fatalError("InterAppTexture is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.requestInterAppPublish(serverName: serverName)
    }
}

extension InterAppTexture: ViewRepresentable {
    var viewNode: ViewNode { .interAppPublish(serverName: serverName) }
}

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

/// Example scene: publish frames under a named server, then draw `SomeVisual`.
public struct OpenVJInterAppTextureScene: View {
    public init() {}

    public var body: Add<TupleView2<InterAppTexture, SomeVisual>> {
        Add {
            InterAppTexture("OpenVJ")
            SomeVisual()
        }
    }
}
