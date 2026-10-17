import Foundation

/// Backend-neutral configuration emitted when a `SourceBrowser` leaf is walked.
public struct SourceBrowserConfiguration: Sendable {
    /// Folder scanned for local video files in the source browser UI (nil → app default).
    public var mediaFolderURL: URL?

    public init(mediaFolderURL: URL? = nil) {
        self.mediaFolderURL = mediaFolderURL
    }
}
