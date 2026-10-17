import Foundation

/// Kind of pickable input (host catalog maps these to platform backends).
public enum SourceKind: Sendable, Equatable {
    case localFile(URL)
    case interAppInput(serverName: String)
    /// Remote URL stream (not implemented on macOS v0).
    case url(URL)
    /// Camera / capture device (reserved for Web and future hosts).
    case captureDevice(deviceID: String?)
}

/// Stable identity for a catalog entry and for `SourceSelection`.
public struct SourceDescriptor: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let kind: SourceKind

    public init(id: String, displayName: String, kind: SourceKind) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
    }

    public static func id(for kind: SourceKind) -> String {
        switch kind {
        case .localFile(let url):
            return "file:\(url.standardizedFileURL.path)"
        case .interAppInput(let serverName):
            return "inter-app:\(serverName)"
        case .url(let url):
            return "url:\(url.absoluteString)"
        case .captureDevice(let deviceID):
            return "capture:\(deviceID ?? "default")"
        }
    }

    public init(displayName: String, kind: SourceKind) {
        self.id = Self.id(for: kind)
        self.displayName = displayName
        self.kind = kind
    }
}

/// A pickable input in the source browser (host-agnostic).
public protocol Source: Sendable {
    var id: String { get }
    var displayName: String { get }
    var kind: SourceKind { get }
}

extension Source {
    public var descriptor: SourceDescriptor {
        SourceDescriptor(id: id, displayName: displayName, kind: kind)
    }
}

/// Concrete catalog row (platform catalogs usually build these).
public struct ListedSource: Source, Equatable {
    public let id: String
    public let displayName: String
    public let kind: SourceKind

    public init(descriptor: SourceDescriptor) {
        id = descriptor.id
        displayName = descriptor.displayName
        kind = descriptor.kind
    }

    public init(displayName: String, kind: SourceKind) {
        let descriptor = SourceDescriptor(displayName: displayName, kind: kind)
        id = descriptor.id
        self.displayName = descriptor.displayName
        self.kind = descriptor.kind
    }
}

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

/// Host-provided list of pickable inputs (`OpenVJApp` registers macOS implementation at launch).
public protocol SourceCatalog: AnyObject {
    func refresh()
    var sources: [any Source] { get }
    var selectionState: SourceSelectionState { get }
}

/// Platform registers a `SourceCatalog` at app start; `SourceBrowser` reads it during render.
public enum SourceCatalogRegistry {
    private static let lock = NSLock()
    private static weak var registered: (any SourceCatalog)?

    public static func register(_ catalog: any SourceCatalog) {
        lock.lock()
        registered = catalog
        lock.unlock()
    }

    public static func unregister() {
        lock.lock()
        registered = nil
        lock.unlock()
    }

    public static var current: (any SourceCatalog)? {
        lock.lock()
        defer { lock.unlock() }
        return registered
    }

    public static var selectionState: SourceSelectionState {
        current?.selectionState ?? SourceSelectionState.shared
    }
}

public enum SourceRendering {
    /// Maps the active selection to `Video` / `InterAppTextureInput` draw hooks.
    public static func draw(selection: SourceSelection, in context: inout ViewRenderContext) {
        switch selection {
        case .none:
            break
        case .source(let descriptor):
            draw(kind: descriptor.kind, in: &context)
        }
    }

    public static func draw(kind: SourceKind, in context: inout ViewRenderContext) {
        switch kind {
        case .localFile(let url):
            context.drawVideo(fileURL: url)
        case .interAppInput(let serverName):
            context.drawInterAppTextureInput(serverName: serverName)
        case .url, .captureDevice:
            break
        }
    }
}
