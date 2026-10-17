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
