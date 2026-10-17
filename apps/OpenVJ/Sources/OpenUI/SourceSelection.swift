import Foundation

/// Current browser choice (optional none).
public enum SourceSelection: Sendable, Equatable {
    case none
    case source(SourceDescriptor)

    public var descriptor: SourceDescriptor? {
        switch self {
        case .none:
            return nil
        case .source(let descriptor):
            return descriptor
        }
    }
}

/// Thread-safe selection shared between host UI and the declarative scene graph.
public final class SourceSelectionState: @unchecked Sendable {
    public static let shared = SourceSelectionState()

    private let lock = NSLock()
    private var _selection: SourceSelection = .none
    private var _mediaFolderURL: URL?

    public var selection: SourceSelection {
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

    /// Last folder scanned for local files (updated by the host browser).
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
