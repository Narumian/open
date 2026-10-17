import Foundation

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
