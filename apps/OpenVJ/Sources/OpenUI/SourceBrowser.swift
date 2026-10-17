import Foundation

/// Declarative source-picker leaf (macOS UI is hosted in `OpenVJApp`).
///
/// During tree walk this leaf:
/// 1. Requests the AppKit source browser panel (once per scene attachment).
/// 2. Draws the current `SourceCatalogRegistry.selectionState.selection`.
///
/// v0: no GPU draw when selection is `.none` (mixer sibling layers still render).
public struct SourceBrowser: View {
    public typealias Body = Never

    public let mediaFolderURL: URL?
    private let catalog: (any SourceCatalog)?

    public init() {
        mediaFolderURL = nil
        catalog = nil
    }

    public init(mediaFolder: URL) {
        mediaFolderURL = mediaFolder
        catalog = nil
    }

    public init(mediaFolderPath: String) {
        mediaFolderURL = URL(fileURLWithPath: mediaFolderPath)
        catalog = nil
    }

    public init(mediaFolderURL: URL?) {
        self.mediaFolderURL = mediaFolderURL
        catalog = nil
    }

    public init(catalog: any SourceCatalog, mediaFolderURL: URL? = nil) {
        self.catalog = catalog
        self.mediaFolderURL = mediaFolderURL
    }

    public var body: Never {
        fatalError("SourceBrowser is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        let activeCatalog = catalog ?? SourceCatalogRegistry.current
        let selectionState = activeCatalog?.selectionState ?? SourceCatalogRegistry.selectionState
        if let folder = mediaFolderURL {
            selectionState.mediaFolderURL = folder
        }
        context.requestSourceBrowser(
            SourceBrowserConfiguration(mediaFolderURL: selectionState.mediaFolderURL ?? mediaFolderURL)
        )
        SourceRendering.draw(selection: selectionState.selection, in: &context)
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
