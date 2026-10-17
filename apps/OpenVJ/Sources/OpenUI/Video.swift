import Foundation

/// Local video file leaf (macOS: AVFoundation decode → WGPU texture each frame).
///
/// **v0:** `file://` URLs only; remote streams and drag-and-drop are not wired yet.
public struct Video: View {
    public typealias Body = Never

    public let fileURL: URL

    public init(url: URL) {
        fileURL = url
    }

    public init(_ url: URL) {
        self.init(url: url)
    }

    public init(path: String) {
        fileURL = URL(fileURLWithPath: path)
    }

    public var body: Never {
        fatalError("Video is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.drawVideo(fileURL: fileURL)
    }
}

extension Video: ViewRepresentable {
    var viewNode: ViewNode { .video(fileURL: fileURL.absoluteString) }
}

/// Example scene: video under a light generative overlay.
public struct OpenVJVideoScene: View {
    public let videoURL: URL

    public init(videoAt url: URL) {
        videoURL = url
    }

    public init(path: String) {
        videoURL = URL(fileURLWithPath: path)
    }

    public var body: Add<TupleView2<Video, SinBody>> {
        Add {
            Video(url: videoURL)
            SinBody()
        }
    }
}
