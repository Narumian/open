import CWGPU
import Foundation

/// Announced remote server that can be subscribed via `InterAppTextureInput`.
public struct InterAppTextureInputServer: Sendable, Equatable {
    public var serverName: String
    public var displayName: String

    public init(serverName: String, displayName: String) {
        self.serverName = serverName
        self.displayName = displayName
    }
}

/// Shared GPU frame bus for sending visuals to other macOS apps (optional platform backends).
public enum InterAppTextureRegistry {
    /// Publish-side registry (`InterAppTextureOutput` → `InterAppTexturePublisher`).
    public enum Output {
        public typealias Factory = (_ configuration: PublisherConfiguration) -> InterAppTexturePublisher?

        public static func registerFactory(_ factory: @escaping Factory) {
            publisherFactory = factory
        }

        public static func makePublisher(configuration: PublisherConfiguration) -> InterAppTexturePublisher? {
            publisherFactory?(configuration)
        }

        public static var isBackendRegistered: Bool { publisherFactory != nil }
    }

    /// Subscribe-side registry (`InterAppTextureInput` → `InterAppTextureSubscriber` + discovery).
    public enum Input {
        public typealias SubscriberFactory = (_ configuration: SubscriberConfiguration) -> InterAppTextureSubscriber?
        public typealias ServerDiscovery = () -> [InterAppTextureInputServer]

        public static let serversDidChangeNotification = Notification.Name(
            "InterAppTextureRegistry.inputServersDidChange"
        )

        public static func registerSubscriberFactory(_ factory: @escaping SubscriberFactory) {
            subscriberFactory = factory
        }

        public static func registerServerDiscovery(_ discovery: @escaping ServerDiscovery) {
            serverDiscovery = discovery
        }

        public static func availableServers() -> [InterAppTextureInputServer] {
            serverDiscovery?() ?? []
        }

        public static func availableServerNames() -> [String] {
            availableServers().map(\.serverName)
        }

        public static func notifyServersDidChange() {
            NotificationCenter.default.post(name: serversDidChangeNotification, object: nil)
        }

        public static func makeSubscriber(configuration: SubscriberConfiguration) -> InterAppTextureSubscriber? {
            subscriberFactory?(configuration)
        }

        public static var isBackendRegistered: Bool { subscriberFactory != nil }
    }

    private static var publisherFactory: Output.Factory?
    private static var subscriberFactory: Input.SubscriberFactory?
    private static var serverDiscovery: Input.ServerDiscovery?

    // MARK: - Legacy flat API (forwards to nested namespaces)

    public typealias PublisherFactory = Output.Factory
    public typealias SubscriberFactory = Input.SubscriberFactory
    public typealias InputServerDiscovery = Input.ServerDiscovery

    public static let inputServersDidChangeNotification = Input.serversDidChangeNotification

    @available(*, deprecated, renamed: "InterAppTextureRegistry.Output.registerFactory")
    public static func registerPublisherFactory(_ factory: @escaping PublisherFactory) {
        Output.registerFactory(factory)
    }

    @available(*, deprecated, renamed: "InterAppTextureRegistry.Input.registerSubscriberFactory")
    public static func registerSubscriberFactory(_ factory: @escaping SubscriberFactory) {
        Input.registerSubscriberFactory(factory)
    }

    @available(*, deprecated, renamed: "InterAppTextureRegistry.Input.registerServerDiscovery")
    public static func registerInputServerDiscovery(_ discovery: @escaping InputServerDiscovery) {
        Input.registerServerDiscovery(discovery)
    }

    @available(*, deprecated, renamed: "InterAppTextureRegistry.Input.availableServers")
    public static func availableInputServers() -> [InterAppTextureInputServer] {
        Input.availableServers()
    }

    @available(*, deprecated, renamed: "InterAppTextureRegistry.Input.availableServerNames")
    public static func availableInputServerNames() -> [String] {
        Input.availableServerNames()
    }

    @available(*, deprecated, renamed: "InterAppTextureRegistry.Input.notifyServersDidChange")
    public static func notifyInputServersDidChange() {
        Input.notifyServersDidChange()
    }

    @available(*, deprecated, renamed: "InterAppTextureRegistry.Output.makePublisher")
    public static func makePublisher(configuration: PublisherConfiguration) -> InterAppTexturePublisher? {
        Output.makePublisher(configuration: configuration)
    }

    @available(*, deprecated, renamed: "InterAppTextureRegistry.Input.makeSubscriber")
    public static func makeSubscriber(configuration: SubscriberConfiguration) -> InterAppTextureSubscriber? {
        Input.makeSubscriber(configuration: configuration)
    }

    public static var isPublisherBackendRegistered: Bool { Output.isBackendRegistered }
    public static var isSubscriberBackendRegistered: Bool { Input.isBackendRegistered }
    public static var isBackendRegistered: Bool { isPublisherBackendRegistered }
}

/// Publish-side registry alias.
public typealias InterAppTextureOutputRegistry = InterAppTextureRegistry.Output

/// Subscribe-side registry alias.
public typealias InterAppTextureInputRegistry = InterAppTextureRegistry.Input

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
