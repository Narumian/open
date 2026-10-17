import CWGPU
import Foundation

/// Shared GPU frame bus for sending visuals to other macOS apps (Syphon, future NDI, etc.).
public enum InterAppTextureRegistry {
    public typealias PublisherFactory = (_ configuration: PublisherConfiguration) -> InterAppTexturePublisher?
    public typealias SubscriberFactory = (_ configuration: SubscriberConfiguration) -> InterAppTextureSubscriber?

    private static var publisherFactory: PublisherFactory?
    private static var subscriberFactory: SubscriberFactory?

    /// Register a platform backend (e.g. Syphon). Called from optional `OpenVJSyphon` at load time.
    public static func registerPublisherFactory(_ factory: @escaping PublisherFactory) {
        publisherFactory = factory
    }

    /// Register a receive backend (e.g. Syphon client). Called from optional `OpenVJSyphon` at load time.
    public static func registerSubscriberFactory(_ factory: @escaping SubscriberFactory) {
        subscriberFactory = factory
    }

    public static func makePublisher(configuration: PublisherConfiguration) -> InterAppTexturePublisher? {
        publisherFactory?(configuration)
    }

    public static func makeSubscriber(configuration: SubscriberConfiguration) -> InterAppTextureSubscriber? {
        subscriberFactory?(configuration)
    }

    public static var isPublisherBackendRegistered: Bool { publisherFactory != nil }
    public static var isSubscriberBackendRegistered: Bool { subscriberFactory != nil }
    public static var isBackendRegistered: Bool { isPublisherBackendRegistered }
}

public struct PublisherConfiguration: Sendable {
    public var serverName: String
    public var enabled: Bool

    public init(serverName: String = "OpenVJ", enabled: Bool = true) {
        self.serverName = serverName
        self.enabled = enabled
    }
}

public struct SubscriberConfiguration: Sendable {
    public var serverName: String

    public init(serverName: String) {
        self.serverName = serverName
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

/// Receives textures from other apps into OpenVJ.
public protocol InterAppTextureSubscriber: AnyObject {
    var isReceiving: Bool { get }
    func attach(device: WGPUDevice, queue: WGPUQueue)
    func start() throws
    func stop()
    /// GPU-import the latest server frame into `destination` (BGRA8, same device). Returns false when no frame is available.
    func importLatestFrame(into destination: WGPUTexture, width: UInt32, height: UInt32) -> Bool
}

public enum InterAppTextureError: Error, Sendable {
    case subscriberNotImplemented
    case backendUnavailable
    case serverNotFound(String)
}

public final class UnimplementedInterAppTextureSubscriber: InterAppTextureSubscriber {
    public init() {}

    public var isReceiving: Bool { false }

    public func attach(device: WGPUDevice, queue: WGPUQueue) {}

    public func start() throws {
        throw InterAppTextureError.subscriberNotImplemented
    }

    public func stop() {}

    public func importLatestFrame(into destination: WGPUTexture, width: UInt32, height: UInt32) -> Bool {
        false
    }
}
