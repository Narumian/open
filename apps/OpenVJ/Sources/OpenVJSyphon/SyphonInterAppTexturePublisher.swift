import AppKit
import CWGPU
import Foundation
import Metal
import OpenVJ
import Syphon

/// macOS Syphon server backed by the same Metal device as wgpu-native.
public final class SyphonInterAppTexturePublisher: InterAppTexturePublisher {
    public var isEnabled: Bool {
        didSet {
            if !isEnabled {
                server?.stop()
                server = nil
            } else if server == nil, let metalDevice {
                server = SyphonMetalServer(name: serverName, device: metalDevice, options: nil)
            }
        }
    }

    public var hasClients: Bool { server?.hasClients ?? false }

    private let serverName: String
    private var metalDevice: MTLDevice?
    private var metalQueue: MTLCommandQueue?
    private var server: SyphonMetalServer?
    private var width: UInt32 = 0
    private var height: UInt32 = 0

    public init(configuration: PublisherConfiguration) {
        serverName = configuration.serverName
        isEnabled = configuration.enabled
    }

    public func attach(device: WGPUDevice, queue: WGPUQueue) {
        guard let devicePointer = wgpuDeviceGetNativeMetalDevice(device),
              let queuePointer = wgpuQueueGetNativeMetalCommandQueue(queue)
        else {
            fputs("[OpenVJ Syphon] Native Metal device/queue unavailable (non-Metal WGPU backend?).\n", stderr)
            return
        }

        metalDevice = Unmanaged<MTLDevice>.fromOpaque(devicePointer).takeUnretainedValue()
        metalQueue = Unmanaged<MTLCommandQueue>.fromOpaque(queuePointer).takeUnretainedValue()

        if isEnabled, server == nil, let metalDevice {
            server = SyphonMetalServer(name: serverName, device: metalDevice, options: nil)
        }
    }

    public func resize(width: UInt32, height: UInt32) {
        self.width = width
        self.height = height
    }

    public func publish(texture: WGPUTexture, width: UInt32, height: UInt32) {
        guard isEnabled, let server, let metalQueue else { return }
        guard width > 0, height > 0 else { return }
        if !server.hasClients { return }

        guard let metalTexturePointer = wgpuTextureGetNativeMetalTexture(texture) else {
            fputs("[OpenVJ Syphon] wgpuTextureGetNativeMetalTexture returned nil.\n", stderr)
            return
        }
        let metalTexture = Unmanaged<MTLTexture>.fromOpaque(metalTexturePointer).takeUnretainedValue()

        guard let commandBuffer = metalQueue.makeCommandBuffer() else { return }
        let region = NSRect(origin: .zero, size: NSSize(width: CGFloat(width), height: CGFloat(height)))
        server.publishFrameTexture(
            metalTexture,
            on: commandBuffer,
            imageRegion: region,
            flipped: false
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    public func detach() {
        server?.stop()
        server = nil
        metalQueue = nil
        metalDevice = nil
        width = 0
        height = 0
    }
}
