import Foundation
import XRender

/// Per-frame bridge from XUI `SceneDraw` into OpenVJ source decks and video upload.
public final class OpenVJFrameContext: @unchecked Sendable {
    public var mediaFolderURL: URL?
    public var onPresentSourceBrowser: ((String?) -> Void)?
    public var drawDeck: ((String, inout SceneBuilder, RenderRect) -> Void)?

    public init() {}
}
