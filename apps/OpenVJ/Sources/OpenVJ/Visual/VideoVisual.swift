import Foundation

/// Local video file leaf (macOS: AVFoundation decode → WGPU texture each frame).
///
/// **v0:** `file://` URLs only; remote streams and drag-and-drop are not wired yet.
public struct Video: Visual {
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

    public func renderLeaf(in context: inout VisualRenderContext) {
        context.drawVideo(fileURL: fileURL)
    }
}

extension Video: VisualRepresentable {
    var visualNode: VisualNode { .video(fileURL: fileURL.absoluteString) }
}

/// Example scene: video under a light generative overlay.
public struct OpenVJVideoScene: Visual {
    public let videoURL: URL

    public init(videoAt url: URL) {
        videoURL = url
    }

    public init(path: String) {
        videoURL = URL(fileURLWithPath: path)
    }

    public var body: Add<TupleVisual2<Video, SinBody>> {
        Add {
            Video(url: videoURL)
            SinBody()
        }
    }
}
