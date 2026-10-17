import Foundation

/// Declarative source-picker leaf (macOS UI is hosted in `OpenVJApp`).
///
/// During tree walk this leaf:
/// 1. Requests the AppKit source browser panel (once per scene attachment).
/// 2. Draws the current `SourceBrowserState.shared.selection` (local `Video` or inter-app subscribe).
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
        context.requestSourceBrowser(
            SourceBrowserConfiguration(mediaFolderURL: mediaFolderURL)
        )
        switch SourceBrowserState.shared.selection {
        case .none:
            break
        case .localVideo(let url):
            context.drawVideo(fileURL: url)
        case .interAppInput(let name):
            context.drawInterAppTextureInput(serverName: name)
        }
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
