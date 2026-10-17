import CWGPU
import Foundation

@inline(__always)
func withChained<C, R>(_ chained: inout C, _ body: (UnsafeMutablePointer<WGPUChainedStruct>) -> R) -> R {
    withUnsafeMutablePointer(to: &chained) { ptr in
        body(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: WGPUChainedStruct.self))
    }
}

@inline(__always)
func withWGPUString<R>(_ string: String, _ body: (WGPUStringView) -> R) -> R {
    var s = string
    return s.withUTF8 { buf in
        body(WGPUStringView(
            data: buf.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) },
            length: buf.count
        ))
    }
}

func installWGPULoggingOnce() {
    struct Once {
        static let run: Void = {
            wgpuSetLogLevel(WGPULogLevel_Warn)
            wgpuSetLogCallback({ level, message, _ in
                let text: String
                if let data = message.data, message.length > 0 {
                    text = String(decoding: UnsafeRawBufferPointer(start: data, count: message.length), as: UTF8.self)
                } else {
                    text = "(no message)"
                }
                fputs("[WGPU \(level.rawValue)] \(text)\n", stderr)
            }, nil)
        }()
    }
    _ = Once.run
}

private final class AdapterBox { var adapter: WGPUAdapter?; var done = false }
private final class DeviceBox { var device: WGPUDevice?; var done = false }

func requestAdapterSync(instance: WGPUInstance, surface: WGPUSurface?) -> WGPUAdapter? {
    let box = AdapterBox()
    var options = WGPURequestAdapterOptions()
    options.compatibleSurface = surface

    var info = WGPURequestAdapterCallbackInfo()
    info.mode = WGPUCallbackMode_AllowProcessEvents
    info.callback = { _, adapter, _, ud1, _ in
        let box = Unmanaged<AdapterBox>.fromOpaque(ud1!).takeUnretainedValue()
        box.adapter = adapter
        box.done = true
    }
    info.userdata1 = Unmanaged.passUnretained(box).toOpaque()

    _ = wgpuInstanceRequestAdapter(instance, &options, info)

    var spins = 0
    while !box.done && spins < 2048 {
        wgpuInstanceProcessEvents(instance)
        spins += 1
    }
    return box.adapter
}

func requestDeviceSync(instance: WGPUInstance, adapter: WGPUAdapter) -> WGPUDevice? {
    let box = DeviceBox()

    var info = WGPURequestDeviceCallbackInfo()
    info.mode = WGPUCallbackMode_AllowProcessEvents
    info.callback = { _, device, _, ud1, _ in
        let box = Unmanaged<DeviceBox>.fromOpaque(ud1!).takeUnretainedValue()
        box.device = device
        box.done = true
    }
    info.userdata1 = Unmanaged.passUnretained(box).toOpaque()

    _ = wgpuAdapterRequestDevice(adapter, nil, info)

    var spins = 0
    while !box.done && spins < 2048 {
        wgpuInstanceProcessEvents(instance)
        spins += 1
    }
    return box.device
}
