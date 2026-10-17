import Foundation

/// Declarative inter-app texture **publish** leaf (GPU texture bus out).
///
/// Place inside `Output { }`. Does not draw; during tree walk it configures the renderer's
/// inter-app publisher via `InterAppPublishConfiguration` (`InterAppTextureRegistry` backend).
public struct InterAppTextureOutput: View {
    public typealias Body = Never

    public let serverName: String

    public init(_ label: String) {
        serverName = label
    }

    public var body: Never {
        fatalError("InterAppTextureOutput is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.requestInterAppTextureOutput(serverName: serverName)
    }
}

extension InterAppTextureOutput: ViewRepresentable {
    var viewNode: ViewNode { .interAppTextureOutput(serverName: serverName) }
}

/// Example scene: publish frames under a named server, then draw `SomeVisual`.
public struct OpenVJInterAppTextureScene: View {
    public init() {}

    public var body: Add<TupleView2<Output<InterAppTextureOutput>, SomeVisual>> {
        Add {
            Output {
                InterAppTextureOutput("OpenVJ")
            }
            SomeVisual()
        }
    }
}

/// Default live-output scene when inter-app publish is enabled: publish + equal-weight mix of generative layers.
public struct OpenVJLiveScene: View {
    public init() {}

    public var body: Add<TupleView2<Output<InterAppTextureOutput>, Mixer<TupleView2<SinBody, TanBody>>>> {
        Add {
            Output {
                InterAppTextureOutput("OpenVJ")
            }
            Mixer {
                SinBody()
                TanBody().time(OpenVJSceneTime.current)
            }
        }
    }
}

/// Live scene with a local video file mixed under the same inter-app server name.
public struct OpenVJLiveVideoScene: View {
    public let videoPath: String

    public init(path: String) {
        videoPath = path
    }

    public var body: Add<TupleView2<Output<InterAppTextureOutput>, Mixer<TupleView2<SinBody, Video>>>> {
        Add {
            Output {
                InterAppTextureOutput("OpenVJ")
            }
            Mixer {
                SinBody()
                Video(path: videoPath)
            }
        }
    }
}
