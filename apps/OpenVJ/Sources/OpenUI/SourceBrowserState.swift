import Foundation

@available(*, deprecated, renamed: "SourceSelection")
public typealias SourceBrowserSelection = SourceSelection

@available(*, deprecated, renamed: "SourceSelectionState")
public typealias SourceBrowserState = SourceSelectionState

/// AppKit registers a presenter here; core targets stay free of AppKit.
public enum SourceBrowserUI {
    public typealias PresentHandler = (SourceBrowserConfiguration) -> Void

    private static let lock = NSLock()
    private static var presentHandler: PresentHandler?

    public static func registerPresentHandler(_ handler: PresentHandler?) {
        lock.lock()
        presentHandler = handler
        lock.unlock()
    }

    public static func requestPresent(_ configuration: SourceBrowserConfiguration) {
        lock.lock()
        let handler = presentHandler
        lock.unlock()
        handler?(configuration)
    }
}
