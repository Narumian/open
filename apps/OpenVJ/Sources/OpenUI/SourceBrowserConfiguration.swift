import Foundation

/// Backend-neutral configuration emitted when a `SourceBrowser` leaf is walked.
public struct SourceBrowserConfiguration: Sendable {
    /// Folder scanned for local video files in the source browser UI (nil → app default).
    public var mediaFolderURL: URL?
    /// When set, selection is stored on `SourceDeckRegistry` instead of the shared catalog.
    public var deckID: String?

    public init(mediaFolderURL: URL? = nil, deckID: String? = nil) {
        self.mediaFolderURL = mediaFolderURL
        self.deckID = deckID
    }
}
