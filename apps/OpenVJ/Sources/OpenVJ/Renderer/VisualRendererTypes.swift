import Foundation

/// Frame outcome from a visual render pass (backend-agnostic).
public enum VisualFrameStatus: Equatable, Sendable {
    case rendered
    case renderedSuboptimal
    case notConfigured
    case skipped
}

/// Native surface handle used to create a renderer (macOS: `CAMetalLayer` pointer).
public struct VisualSurfaceAttachment {
    public var metalLayer: UnsafeMutableRawPointer

    public init(metalLayer: UnsafeMutableRawPointer) {
        self.metalLayer = metalLayer
    }
}

/// Renders generative visuals into a window surface; implementations may publish frames via `InterAppTexturePublisher`.
public protocol VisualRenderer: AnyObject {
    @discardableResult
    func configure(width: UInt32, height: UInt32) -> Bool
    /// `frameTime` is seconds since renderer creation when nil; backends may use it for animation.
    func render(frameTime: CFTimeInterval?) -> VisualFrameStatus
    func setInterAppPublisher(_ publisher: InterAppTexturePublisher?)
}

public extension VisualRenderer {
    func render() -> VisualFrameStatus {
        render(frameTime: nil)
    }
}

/// Registry and factory for `VisualRenderer` backends (default: WebGPU when linked).
public enum VisualRender {
    public typealias RendererFactory = (_ attachment: VisualSurfaceAttachment) -> VisualRenderer?

    private static var rendererFactory: RendererFactory?
    private static var didRegisterDefaultBackend = false

    /// Override or register an alternate backend (e.g. future Metal-native renderer).
    public static func registerRendererFactory(_ factory: @escaping RendererFactory) {
        rendererFactory = factory
        didRegisterDefaultBackend = true
    }

    public static func makeRenderer(attachment: VisualSurfaceAttachment) -> VisualRenderer? {
        ensureDefaultBackendRegistered()
        return rendererFactory?(attachment)
    }

    public static var isBackendRegistered: Bool {
        ensureDefaultBackendRegistered()
        return rendererFactory != nil
    }

    private static func ensureDefaultBackendRegistered() {
        guard !didRegisterDefaultBackend else { return }
        registerDefaultWGPURendererFactory()
        didRegisterDefaultBackend = true
    }
}
