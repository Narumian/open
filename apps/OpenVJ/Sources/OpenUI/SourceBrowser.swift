import Foundation

/// Declarative source-picker leaf (macOS UI is hosted in `OpenVJApp`).
///
/// Catalog → `SourceSelectionState` → `SourceRendering` (single path via `SourceCatalogRegistry`).
///
/// v0: no GPU draw when selection is `.none` (mixer sibling layers still render).
public struct SourceBrowser: View {
    public typealias Body = Never

    public let deckID: String?
    public let mediaFolderURL: URL?

    public init() {
        deckID = nil
        mediaFolderURL = nil
    }

    public init(deck: String, mediaFolderURL: URL? = nil) {
        deckID = deck
        self.mediaFolderURL = mediaFolderURL
    }

    public init(mediaFolder: URL) {
        deckID = nil
        mediaFolderURL = mediaFolder
    }

    public init(mediaFolderPath: String) {
        deckID = nil
        mediaFolderURL = URL(fileURLWithPath: mediaFolderPath)
    }

    public init(mediaFolderURL: URL?) {
        deckID = nil
        self.mediaFolderURL = mediaFolderURL
    }

    public var body: Never {
        fatalError("SourceBrowser is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        Self.presentAndDraw(mediaFolderURL: mediaFolderURL, deckID: deckID, in: &context)
    }

    /// Shared walk for the declarative leaf and flattened `ViewNode.sourceBrowser`.
    public static func presentAndDraw(
        mediaFolderURL: URL?,
        deckID: String? = nil,
        in context: inout ViewRenderContext
    ) {
        var playback = context.sourcePlayback
        if let deckID {
            playback = SourcePlaybackContext(deckID: deckID)
        }
        if let folder = mediaFolderURL {
            playback.mediaFolderURL = folder
        }
        let folderForUI = playback.mediaFolderURL ?? mediaFolderURL
        context.requestSourceBrowser(
            SourceBrowserConfiguration(mediaFolderURL: folderForUI, deckID: deckID)
        )
        var drawContext = context
        drawContext.sourcePlayback = playback
        SourceRendering.draw(selection: playback.selection, in: &drawContext)
        context.sourcePlayback = drawContext.sourcePlayback
    }
}

extension SourceBrowser: ViewRepresentable {
    var viewNode: ViewNode { .sourceBrowser(deckID: deckID, mediaFolderURL: mediaFolderURL?.absoluteString) }
}

/// Documented example: equal-weight mix of browser-driven input + generative placeholder.
///
/// ```swift
/// Mixer {
///     SourceBrowser()
///     Some()
/// }
/// ```
public struct OpenVJSourceBrowserMixerScene: View {
    public let mediaFolderURL: URL?

    public init(mediaFolder: URL? = nil) {
        mediaFolderURL = mediaFolder
    }

    public typealias Body = Add<
        TupleView2<
            Output<InterAppTextureOutput>,
            OffscreenTexture<Mixer<TupleView2<SourceBrowser, SourceBrowser>>>
        >
    >

    public var body: Body {
        Add {
            Output {
                InterAppTextureOutput("OpenVJ", bus: "mix")
            }
            OffscreenTexture("mix") {
                Mixer {
                    SourceBrowser(deck: "A", mediaFolderURL: mediaFolderURL)
                    SourceBrowser(deck: "B", mediaFolderURL: mediaFolderURL)
                }
            }
        }
    }
}
