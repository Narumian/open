import CWGPU
import Foundation

/// Shared GPU frame bus for macOS system virtual cameras (CMIO extension, OBS-style DAL plugins, etc.).
public enum VirtualCameraRegistry {
    public typealias PublisherFactory = (_ configuration: VirtualCameraConfiguration) -> VirtualCameraPublisher?

    private static var publisherFactory: PublisherFactory?

    /// Register a platform backend (e.g. `OpenVJVirtualCam` stub or future CMIO plugin host). Called at load time.
    public static func registerPublisherFactory(_ factory: @escaping PublisherFactory) {
        publisherFactory = factory
    }

    public static func makePublisher(configuration: VirtualCameraConfiguration) -> VirtualCameraPublisher? {
        publisherFactory?(configuration)
    }

    public static var isBackendRegistered: Bool { publisherFactory != nil }
}

public struct VirtualCameraConfiguration: Sendable {
    public var cameraLabel: String
    public var enabled: Bool

    public init(cameraLabel: String = "OpenVJ", enabled: Bool = true) {
        self.cameraLabel = cameraLabel
        self.enabled = enabled
    }
}

/// Publishes rendered WGPU frames to a macOS-visible virtual camera device.
public protocol VirtualCameraPublisher: AnyObject {
    var isEnabled: Bool { get set }
    func attach(device: WGPUDevice, queue: WGPUQueue)
    func resize(width: UInt32, height: UInt32)
    /// `texture` must be BGRA8 on the same WGPU device; GPU work must be flushed before calling.
    func publish(texture: WGPUTexture, width: UInt32, height: UInt32)
    func detach()
}

public enum VirtualCameraError: Error, Sendable {
    case backendUnavailable
}
