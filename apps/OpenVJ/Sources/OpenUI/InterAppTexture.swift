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

/// Default live-output scene when Syphon is enabled: publish + equal-weight mix of generative layers.
///
/// Assign on `ViewSceneHosting.rootView`, or let `OpenVJApp` pick it when `OPEN_VJ_SYPHON=1` / menu is on.
public struct OpenVJLiveScene: View {
    public init() {}

    public var body: Add<TupleView2<InterAppTexture, Mixer<TupleView2<SinBody, TanBody>>>> {
        Add {
            InterAppTexture("OpenVJ")
            Mixer {
                SinBody()
                TanBody().time(OpenVJSceneTime.current)
            }
        }
    }
}

/// Live scene with a local video file mixed under the same Syphon server name.
public struct OpenVJLiveVideoScene: View {
    public let videoPath: String

    public init(path: String) {
        videoPath = path
    }

    public var body: Add<TupleView2<InterAppTexture, Mixer<TupleView2<SinBody, Video>>>> {
        Add {
            InterAppTexture("OpenVJ")
            Mixer {
                SinBody()
                Video(path: videoPath)
            }
        }
    }
}
