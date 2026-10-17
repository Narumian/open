import Foundation

/// Frame clock for nested playback scopes (renderer or host sets before tree walk).
public enum VJPlaybackSession {
    public static var activeTime: Float = 0
    public static var isPlaying: Bool = true
}

/// Root transport scope: binds session clock and forwards `sourcePlayback` to children.
public struct VJPlayer<Content: View>: View {
    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Never {
        fatalError("VJPlayer is a composite container")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.sourcePlayback.beginVJTransport(frameTime: context.frameTime)
        content.render(in: &context)
        context.sourcePlayback.endVJTransport()
    }
}

extension VJPlayer: ViewRepresentable {
    var viewNode: ViewNode {
        content.flattenedNode()
    }
}

/// Ordered clip list builder (`Sequence(a, b, c).loop()`).
public struct Sequence {
    public let clips: [URL]

    public init(_ clips: URL...) {
        self.clips = clips
    }

    public init(_ v0: Video, _ v1: Video) {
        clips = [v0.fileURL, v1.fileURL]
    }

    public init(_ v0: Video, _ v1: Video, _ v2: Video) {
        clips = [v0.fileURL, v1.fileURL, v2.fileURL]
    }

    public func loop() -> SequencePlayer {
        SequencePlayer(clips: clips, loops: true)
    }

    public func playOnce() -> SequencePlayer {
        SequencePlayer(clips: clips, loops: false)
    }
}

/// Host-driven playlist leaf; index advances via `ViewRenderContext.tickPlaybackTransport()`.
public struct SequencePlayer: View {
    public typealias Body = Never

    public let clips: [URL]
    public var loops: Bool
    public var crossfadeDuration: Float?

    public init(clips: [URL], loops: Bool, crossfadeDuration: Float? = nil) {
        self.clips = clips
        self.loops = loops
        self.crossfadeDuration = crossfadeDuration
    }

    public var body: Never {
        fatalError("SequencePlayer is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.sourcePlayback.bindSequence(clips: clips, loops: loops)
        guard let url = context.sourcePlayback.activeSequenceClipURL() else { return }
        context.drawVideo(fileURL: url, loops: false)
    }
}

extension SequencePlayer: ViewRepresentable {
    var viewNode: ViewNode {
        guard let first = clips.first else { return .empty }
        return .video(fileURL: first.absoluteString)
    }
}
