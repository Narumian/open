import CWGPU
import Foundation

/// Shared GPU frame bus for sending visuals to other macOS apps (Syphon, future NDI, etc.).
public enum InterAppTexture {
    public typealias PublisherFactory = (_ configuration: PublisherConfiguration) -> InterAppTexturePublisher?

    private static var publisherFactory: PublisherFactory?

    /// Register a platform backend (e.g. Syphon). Called from optional `OpenVJSyphon` at load time.
    public static func registerPublisherFactory(_ factory: @escaping PublisherFactory) {
        publisherFactory = factory
    }

    public static func makePublisher(configuration: PublisherConfiguration) -> InterAppTexturePublisher? {
        publisherFactory?(configuration)
    }

    public static var isBackendRegistered: Bool { publisherFactory != nil }
}

public struct PublisherConfiguration: Sendable {
    public var serverName: String
    public var enabled: Bool

    public init(serverName: String = "OpenVJ", enabled: Bool = true) {
        self.serverName = serverName
        self.enabled = enabled
    }
}

/// Publishes rendered WGPU frames to an inter-app texture server.
public protocol InterAppTexturePublisher: AnyObject {
    var isEnabled: Bool { get set }
    /// True when at least one remote client is connected (when supported by the backend).
    var hasClients: Bool { get }
    func attach(device: WGPUDevice, queue: WGPUQueue)
    func resize(width: UInt32, height: UInt32)
    /// `texture` must be a BGRA8 texture on the same WGPU device; GPU work must be flushed before calling.
    func publish(texture: WGPUTexture, width: UInt32, height: UInt32)
    func detach()
}

/// Future: receive textures from other apps into OpenVJ.
public protocol InterAppTextureSubscriber: AnyObject {
    var isReceiving: Bool { get }
    func start() throws
    func stop()
}

public enum InterAppTextureError: Error, Sendable {
    case subscriberNotImplemented
    case backendUnavailable
}

public final class UnimplementedInterAppTextureSubscriber: InterAppTextureSubscriber {
    public init() {}

    public var isReceiving: Bool { false }

    public func start() throws {
        throw InterAppTextureError.subscriberNotImplemented
    }

    public func stop() {}
}
