import Foundation

/// Frame clock for nested playback scopes (renderer or host sets before tree walk).
public enum VJPlaybackSession {
    public static var activeTime: Float = 0
    public static var isPlaying: Bool = true
}

/// Root transport scope. v0: transparent forward; future: owns `SequencePlaybackState` ticks.
public struct VJPlayer<Content: View>: View {
    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Content { content }
}

/// Single-clip loop. macOS v0: same draw path as `Video` (decoder loops on end).
public struct LoopPlayer: View {
    public typealias Body = Never

    public let fileURL: URL
    public var loops: Bool

    public init(url: URL, loops: Bool = true) {
        fileURL = url
        self.loops = loops
    }

    public init(_ video: Video, loops: Bool = true) {
        fileURL = video.fileURL
        self.loops = loops
    }

    public var body: Never {
        fatalError("LoopPlayer is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.drawVideo(fileURL: fileURL)
    }
}

extension LoopPlayer: ViewRepresentable {
    var viewNode: ViewNode { .video(fileURL: fileURL.absoluteString) }
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

/// Host-driven playlist leaf. v0 stub: always draws the first clip until `SequencePlaybackState` is wired.
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
        let index = SequencePlaybackState.shared.clipIndex(clips: clips, loops: loops)
        guard clips.indices.contains(index) else { return }
        context.drawVideo(fileURL: clips[index])
    }
}

extension SequencePlayer: ViewRepresentable {
    var viewNode: ViewNode {
        guard let first = clips.first else { return .empty }
        return .video(fileURL: first.absoluteString)
    }
}

/// Mutable playlist index (OpenVJ / browser host advances on clip end). Stub: index 0.
public final class SequencePlaybackState: @unchecked Sendable {
    public static let shared = SequencePlaybackState()

    private var clipIndex = 0

    public init() {}

    public func clipIndex(clips: [URL], loops: Bool) -> Int {
        guard !clips.isEmpty else { return 0 }
        if clipIndex >= clips.count {
            clipIndex = loops ? 0 : clips.count - 1
        }
        return min(clipIndex, clips.count - 1)
    }

    /// Future: call from host when clip `i` ends or each frame with durations.
    public func advance(by count: Int, clipCount: Int, loops: Bool) {
        guard clipCount > 0 else { return }
        let next = clipIndex + count
        if next < clipCount {
            clipIndex = next
        } else if loops {
            clipIndex = next % clipCount
        } else {
            clipIndex = clipCount - 1
        }
    }

    public func reset() {
        clipIndex = 0
    }
}
