import Foundation

/// Declarative inter-app texture subscribe leaf (requires a linked inter-app backend in the app target).
///
/// Draws the latest frame from a remote server as a composited layer (same blend path as `Video`).
public struct InterAppTextureInput: View {
    public typealias Body = Never

    public let serverName: String

    public init(_ serverName: String) {
        self.serverName = serverName
    }

    public var body: Never {
        fatalError("InterAppTextureInput is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.drawInterAppTextureInput(serverName: serverName)
    }
}

extension InterAppTextureInput: ViewRepresentable {
    var viewNode: ViewNode { .interAppSubscribe(serverName: serverName) }
}

extension InterAppTexture {
    /// Factory for an incoming inter-app texture layer subscribed to `serverName`.
    public static func subscribe(_ serverName: String) -> InterAppTextureInput {
        InterAppTextureInput(serverName)
    }
}

/// Example: publish local output and mix in a remote inter-app source by name.
public struct OpenVJInterAppMixScene: View {
    public let remoteServerName: String

    public init(remoteServerName: String = "OpenVJ") {
        self.remoteServerName = remoteServerName
    }

    public var body: Add<TupleView2<InterAppTexture, Mixer<TupleView2<SinBody, InterAppTextureInput>>>> {
        Add {
            InterAppTexture("OpenVJ")
            Mixer {
                SinBody()
                InterAppTexture.subscribe(remoteServerName)
            }
        }
    }
}
