import Foundation

/// Declarative source-picker leaf (macOS UI is hosted in `OpenVJApp`).
///
/// Catalog → `SourceSelectionState` → `SourceRendering` (single path via `SourceCatalogRegistry`).
///
/// v0: no GPU draw when selection is `.none` (mixer sibling layers still render).
public struct SourceBrowser: View {
    public typealias Body = Never

    public let mediaFolderURL: URL?

    public init() {
        mediaFolderURL = nil
    }

    public init(mediaFolder: URL) {
        mediaFolderURL = mediaFolder
    }

    public init(mediaFolderPath: String) {
        mediaFolderURL = URL(fileURLWithPath: mediaFolderPath)
    }

    public init(mediaFolderURL: URL?) {
        self.mediaFolderURL = mediaFolderURL
    }

    public var body: Never {
        fatalError("SourceBrowser is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        Self.presentAndDraw(mediaFolderURL: mediaFolderURL, in: &context)
    }

    /// Shared walk for the declarative leaf and flattened `ViewNode.sourceBrowser`.
    static func presentAndDraw(mediaFolderURL: URL?, in context: inout ViewRenderContext) {
        if let folder = mediaFolderURL {
            context.sourcePlayback.mediaFolderURL = folder
        }
        let folderForUI = context.sourcePlayback.mediaFolderURL ?? mediaFolderURL
        context.requestSourceBrowser(
            SourceBrowserConfiguration(mediaFolderURL: folderForUI)
        )
        SourceRendering.draw(selection: context.sourcePlayback.selection, in: &context)
    }
}

extension SourceBrowser: ViewRepresentable {
    var viewNode: ViewNode { .sourceBrowser }
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

    public var body: Mixer<TupleView2<SourceBrowser, Some>> {
        Mixer {
            SourceBrowser(mediaFolderURL: mediaFolderURL)
            Some()
        }
    }
}
