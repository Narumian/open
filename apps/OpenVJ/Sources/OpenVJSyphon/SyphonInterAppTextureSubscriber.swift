import AppKit
import CWGPU
import Foundation
import Metal
import OpenVJ
import Syphon

/// macOS Syphon client that imports server frames into WGPU textures on the shared Metal device.
public final class SyphonInterAppTextureSubscriber: InterAppTextureSubscriber {
    public private(set) var isReceiving = false

    private let serverName: String
    private var metalDevice: MTLDevice?
    private var metalQueue: MTLCommandQueue?
    private var client: SyphonMetalClient?
    private var directoryObserver: NSObjectProtocol?

    public init(configuration: SubscriberConfiguration) {
        serverName = configuration.serverName
    }

    deinit {
        stop()
    }

    public func attach(device: WGPUDevice, queue: WGPUQueue) {
        guard let devicePointer = wgpuDeviceGetNativeMetalDevice(device),
              let queuePointer = wgpuQueueGetNativeMetalCommandQueue(queue)
        else {
            fputs("[OpenVJ Syphon] Native Metal device/queue unavailable for subscriber.\n", stderr)
            return
        }

        metalDevice = Unmanaged<MTLDevice>.fromOpaque(devicePointer).takeUnretainedValue()
        metalQueue = Unmanaged<MTLCommandQueue>.fromOpaque(queuePointer).takeUnretainedValue()
    }

    public func start() throws {
        isReceiving = true
        observeServerDirectory()
        connectIfPossible()
    }

    public func stop() {
        isReceiving = false
        if let directoryObserver {
            NotificationCenter.default.removeObserver(directoryObserver)
            self.directoryObserver = nil
        }
        client?.stop()
        client = nil
    }

    public func importLatestFrame(into destination: WGPUTexture, width: UInt32, height: UInt32) -> Bool {
        guard isReceiving else { return false }
        if client == nil || client?.isValid != true {
            connectIfPossible()
        }
        guard let client, client.isValid else { return false }
        guard client.hasNewFrame else { return false }

        guard let source = client.newFrameImage() else { return false }

        let copyWidth = min(source.width, Int(width))
        let copyHeight = min(source.height, Int(height))
        guard copyWidth > 0, copyHeight > 0 else { return false }

        guard let destPointer = wgpuTextureGetNativeMetalTexture(destination) else { return false }
        let destinationMetal = Unmanaged<MTLTexture>.fromOpaque(destPointer).takeUnretainedValue()
        guard let metalQueue,
              let commandBuffer = metalQueue.makeCommandBuffer(),
              let blit = commandBuffer.makeBlitCommandEncoder()
        else {
            return false
        }

        blit.copy(
            from: source,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: copyWidth, height: copyHeight, depth: 1),
            to: destinationMetal,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return true
    }

    private func connectIfPossible() {
        guard isReceiving, let metalDevice else { return }
        guard let description = serverDescription() else { return }

        client?.stop()
        client = SyphonMetalClient(
            serverDescription: description,
            device: metalDevice,
            options: nil,
            newFrameHandler: nil
        )
        if client?.isValid != true {
            client = nil
        }
    }

    private func serverDescription() -> [String: Any]? {
        SyphonServerDirectory.shared()
            .servers(matchingName: serverName, appName: nil)
            .first
    }

    private func observeServerDirectory() {
        guard directoryObserver == nil else { return }
        let center = NotificationCenter.default
        directoryObserver = center.addObserver(
            forName: NSNotification.Name.SyphonServerAnnounce,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isReceiving, self.client == nil || self.client?.isValid != true else { return }
            self.connectIfPossible()
        }
    }
}
