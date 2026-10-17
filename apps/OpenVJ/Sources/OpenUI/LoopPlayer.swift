import Foundation

/// Single-clip loop. macOS v0: same draw path as `Video` (decoder loops on end).
public struct LoopPlayer: View {
    public typealias Body = Never

    public let fileURL: URL?
    public var loops: Bool

    public init(url: URL, loops: Bool = true) {
        fileURL = url
        self.loops = loops
    }

    public init(_ video: Video, loops: Bool = true) {
        fileURL = video.fileURL
        self.loops = loops
    }

    /// Uses `context.sourcePlayback.selectedLocalFileURL` (e.g. under `SourceBrowser`).
    public init(browserSelection loops: Bool = true) {
        fileURL = nil
        self.loops = loops
    }

    public var body: Never {
        fatalError("LoopPlayer is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        let url = fileURL ?? context.sourcePlayback.selectedLocalFileURL
        guard let url else { return }
        context.drawVideo(fileURL: url, loops: loops)
    }
}

extension LoopPlayer: ViewRepresentable {
    var viewNode: ViewNode {
        if let fileURL {
            return .video(fileURL: fileURL.absoluteString)
        }
        return .sourceBrowser(deckID: nil, mediaFolderURL: nil)
    }
}
