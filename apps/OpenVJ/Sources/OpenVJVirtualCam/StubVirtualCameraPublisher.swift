import CWGPU
import Foundation
import OpenVJ

/// v0 backend: validates the publish path and documents integration; no CMIO device yet.
public final class StubVirtualCameraPublisher: VirtualCameraPublisher {
    public var isEnabled: Bool {
        didSet {
            if !isEnabled {
                detach()
            }
        }
    }

    private let cameraLabel: String
    private var width: UInt32 = 0
    private var height: UInt32 = 0
    private var publishCount: UInt64 = 0
    private static var didLogIntegrationPath = false

    public init(configuration: VirtualCameraConfiguration) {
        cameraLabel = configuration.cameraLabel
        isEnabled = configuration.enabled
    }

    public func attach(device: WGPUDevice, queue: WGPUQueue) {
        guard isEnabled else { return }
        if !Self.didLogIntegrationPath {
            Self.didLogIntegrationPath = true
            fputs(
                """
                [OpenVJ VirtualCam] Stub backend active for camera "\(cameraLabel)".
                Frames are composited in OpenVJ but not exposed to FaceTime/Zoom yet.
                Real output path: CMIO DAL plugin (OBS Virtual Camera model) or host-owned IOSurface → extension.
                See docs/virtual-camera.md.

                """,
                stderr
            )
        }
    }

    public func resize(width: UInt32, height: UInt32) {
        self.width = width
        self.height = height
    }

    public func publish(texture: WGPUTexture, width: UInt32, height: UInt32) {
        guard isEnabled, width > 0, height > 0 else { return }
        publishCount += 1
        if publishCount == 1 || publishCount % 300 == 0 {
            fputs(
                "[OpenVJ VirtualCam] stub publish #\(publishCount) \(cameraLabel) \(width)x\(height)\n",
                stderr
            )
        }
        _ = texture
    }

    public func detach() {
        width = 0
        height = 0
    }
}
