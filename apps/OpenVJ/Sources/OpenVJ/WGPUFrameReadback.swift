import CWGPU
import Foundation

private final class BufferMapBox {
    var done = false
    var status: WGPUMapAsyncStatus = WGPUMapAsyncStatus_Error
}

func mapBufferReadSync(instance: WGPUInstance, device: WGPUDevice, buffer: WGPUBuffer, offset: Int, size: Int) -> Data? {
    let box = BufferMapBox()
    var info = WGPUBufferMapCallbackInfo()
    info.mode = WGPUCallbackMode_AllowProcessEvents
    info.callback = { status, _, userdata1, _ in
        let box = Unmanaged<BufferMapBox>.fromOpaque(userdata1!).takeUnretainedValue()
        box.status = status
        box.done = true
    }
    info.userdata1 = Unmanaged.passUnretained(box).toOpaque()

    _ = wgpuBufferMapAsync(buffer, WGPUMapMode_Read, offset, size, info)

    var spins = 0
    while !box.done && spins < 100_000 {
        _ = wgpuDevicePoll(device, 1, nil)
        wgpuInstanceProcessEvents(instance)
        spins += 1
    }
    guard box.done, box.status == WGPUMapAsyncStatus_Success else { return nil }

    guard let mapped = wgpuBufferGetConstMappedRange(buffer, offset, size) else { return nil }
    let data = Data(bytes: mapped, count: size)
    wgpuBufferUnmap(buffer)
    return data
}

/// GPU copy of a BGRA8 texture into tightly packed row-major BGRA bytes.
func readBGRA8Texture(
    instance: WGPUInstance,
    device: WGPUDevice,
    queue: WGPUQueue,
    texture: WGPUTexture,
    width: UInt32,
    height: UInt32
) -> Data? {
    guard width > 0, height > 0 else { return nil }

    let bytesPerPixel = 4
    let tightBytesPerRow = Int(width) * bytesPerPixel
    let paddedBytesPerRow = (tightBytesPerRow + 255) & ~255
    let bufferSize = paddedBytesPerRow * Int(height)

    var bufferDescriptor = WGPUBufferDescriptor()
    bufferDescriptor.usage = WGPUBufferUsage_CopyDst | WGPUBufferUsage_MapRead
    bufferDescriptor.size = UInt64(bufferSize)
    guard let buffer = wgpuDeviceCreateBuffer(device, &bufferDescriptor) else { return nil }
    defer { wgpuBufferRelease(buffer) }

    guard let encoder = wgpuDeviceCreateCommandEncoder(device, nil) else { return nil }
    defer { wgpuCommandEncoderRelease(encoder) }

    var source = WGPUTexelCopyTextureInfo()
    source.texture = texture
    source.mipLevel = 0
    source.origin = WGPUOrigin3D(x: 0, y: 0, z: 0)
    source.aspect = WGPUTextureAspect_All

    var destination = WGPUTexelCopyBufferInfo()
    destination.buffer = buffer
    destination.layout.offset = 0
    destination.layout.bytesPerRow = UInt32(paddedBytesPerRow)
    destination.layout.rowsPerImage = height

    var copySize = WGPUExtent3D(width: width, height: height, depthOrArrayLayers: 1)
    wgpuCommandEncoderCopyTextureToBuffer(encoder, &source, &destination, &copySize)

    guard let commandBuffer = wgpuCommandEncoderFinish(encoder, nil) else { return nil }
    var submitted: WGPUCommandBuffer? = commandBuffer
    withUnsafePointer(to: &submitted) { wgpuQueueSubmit(queue, 1, $0) }
    wgpuCommandBufferRelease(commandBuffer)
    _ = wgpuDevicePoll(device, 1, nil)
    wgpuInstanceProcessEvents(instance)

    guard let padded = mapBufferReadSync(instance: instance, device: device, buffer: buffer, offset: 0, size: bufferSize) else {
        return nil
    }

    // WebGPU/Metal framebuffer rows are bottom-up; PNG and CPU chrome use top-left origin.
    var tight = Data(count: tightBytesPerRow * Int(height))
    tight.withUnsafeMutableBytes { dest in
        guard let destBase = dest.baseAddress else { return }
        padded.withUnsafeBytes { src in
            guard let srcBase = src.baseAddress else { return }
            for row in 0 ..< Int(height) {
                let srcRow = srcBase.advanced(by: (Int(height) - 1 - row) * paddedBytesPerRow)
                let destRow = destBase.advanced(by: row * tightBytesPerRow)
                destRow.copyMemory(from: srcRow, byteCount: tightBytesPerRow)
            }
        }
    }
    return tight
}
