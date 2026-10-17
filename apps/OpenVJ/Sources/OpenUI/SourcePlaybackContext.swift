import Foundation

/// Per-frame source catalog state carried on `ViewRenderContext`.
///
/// This is intentionally **not** SwiftUI `@Environment`: the host constructs one
/// `ViewRenderContext` per frame (or export step). Child views read/write selection
/// through `context.sourcePlayback` during `render` / `renderLeaf`.
public struct SourcePlaybackContext {
    /// When nil, reads/writes go through `SourceCatalogRegistry.selectionState`.
    public var selectionState: SourceSelectionState?

    public init(selectionState: SourceSelectionState? = nil) {
        self.selectionState = selectionState
    }

    public var resolvedSelectionState: SourceSelectionState {
        selectionState ?? SourceCatalogRegistry.selectionState
    }

    public var selection: SourceSelection {
        get { resolvedSelectionState.selection }
        set { resolvedSelectionState.selection = newValue }
    }

    public var mediaFolderURL: URL? {
        get { resolvedSelectionState.mediaFolderURL }
        set { resolvedSelectionState.mediaFolderURL = newValue }
    }

    /// `ObjectIdentifier` of the registered catalog when present (for logging / host adapters).
    public var catalogID: ObjectIdentifier? {
        SourceCatalogRegistry.current.map { ObjectIdentifier($0) }
    }

    /// Local file URL from the current browser selection, if any.
    public var selectedLocalFileURL: URL? {
        guard let descriptor = selection.descriptor else { return nil }
        if case .localFile(let url) = descriptor.kind {
            return url
        }
        return nil
    }
}
