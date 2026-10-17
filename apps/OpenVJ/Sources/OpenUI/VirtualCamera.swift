import Foundation

/// Declarative virtual-camera publish leaf (`OpenVJVirtualCam` when linked).
///
/// Does not draw; during tree walk it configures the renderer's virtual-camera publisher.
public struct VirtualCamera: View {
    public typealias Body = Never

    public let cameraLabel: String

    public init(_ label: String) {
        cameraLabel = label
    }

    public var body: Never {
        fatalError("VirtualCamera is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.requestVirtualCameraPublish(cameraLabel: cameraLabel)
    }
}

extension VirtualCamera: ViewRepresentable {
    var viewNode: ViewNode { .virtualCameraPublish(cameraLabel: cameraLabel) }
}

/// Publish to virtual camera + Syphon + mix a remote inter-app source.
public struct OpenVJVirtualCamMixScene: View {
    public let remoteServerName: String

    public init(remoteServerName: String = "OtherApp") {
        self.remoteServerName = remoteServerName
    }

    public var body: Add<
        TupleView3<
            VirtualCamera,
            InterAppTexture,
            Mixer<TupleView2<SinBody, InterAppTextureInput>>
        >
    > {
        Add {
            VirtualCamera("OpenVJ")
            InterAppTexture("OpenVJ")
            Mixer {
                SinBody()
                InterAppTextureInput(remoteServerName)
            }
        }
    }
}
