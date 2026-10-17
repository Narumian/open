import Foundation

/// Active input chosen in the macOS source browser (AppKit UI writes, render walk reads).
public enum SourceBrowserSelection: Sendable, Equatable {
    case none
    case localVideo(URL)
    case interAppInput(name: String)
}

/// Thread-safe selection shared between `OpenVJApp` and the declarative scene graph.
public final class SourceBrowserState: @unchecked Sendable {
    public static let shared = SourceBrowserState()

    private let lock = NSLock()
    private var _selection: SourceBrowserSelection = .none
    private var _mediaFolderURL: URL?

    public var selection: SourceBrowserSelection {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _selection
        }
        set {
            lock.lock()
            _selection = newValue
            lock.unlock()
        }
    }

    /// Last folder used for directory listing (updated by the AppKit browser).
    public var mediaFolderURL: URL? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _mediaFolderURL
        }
        set {
            lock.lock()
            _mediaFolderURL = newValue
            lock.unlock()
        }
    }
}

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
