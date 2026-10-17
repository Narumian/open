import CWGPU
import Foundation
import OpenVJApple

public final class WGPUVisualRenderer: VisualRenderer {
    private static let surfaceFormat = WGPUTextureFormat_BGRA8Unorm
    private static let uniformStride = 16

    private let instance: WGPUInstance
    private let surface: WGPUSurface
    private let adapter: WGPUAdapter
    private let device: WGPUDevice
    private let queue: WGPUQueue
    private let pipeline: WGPURenderPipeline
    private let bindGroupLayout: WGPUBindGroupLayout
    private let bindGroup: WGPUBindGroup
    private let uniformBuffer: WGPUBuffer

    private var configuredWidth: UInt32 = 0
    private var configuredHeight: UInt32 = 0
    private var interAppCopyTexture: WGPUTexture?
    private var interAppCopyWidth: UInt32 = 0
    private var interAppCopyHeight: UInt32 = 0
    private let startTime = CFAbsoluteTimeGetCurrent()

    /// Optional inter-app publisher (Syphon when `OpenVJSyphon` is linked). Off by default on the publisher itself.
    public var interAppPublisher: InterAppTexturePublisher?

    /// Root declarative visual tree rendered each frame.
    public var rootVisual: AnyVisual = AnyVisual(OpenVJDefaultScene())

    public init?(metalLayer: UnsafeMutableRawPointer) {
        installWGPULoggingOnce()

        var instancePtr: UnsafeMutableRawPointer?
        var surfacePtr: UnsafeMutableRawPointer?
        openvj_apple_create_surface(metalLayer, &instancePtr, &surfacePtr)
        guard let instancePtr, let surfacePtr else { return nil }

        let instance = OpaquePointer(instancePtr)
        let surface = OpaquePointer(surfacePtr)

        guard let adapter = requestAdapterSync(instance: instance, surface: surface),
              let device = requestDeviceSync(instance: instance, adapter: adapter),
              let queue = wgpuDeviceGetQueue(device)
        else {
            wgpuSurfaceRelease(surface)
            wgpuInstanceRelease(instance)
            return nil
        }

        guard let shader = Self.makeShaderModule(device: device),
              let uniformBuffer = Self.makeUniformBuffer(device: device),
              let bindGroupLayout = Self.makeBindGroupLayout(device: device),
              let bindGroup = Self.makeBindGroup(device: device, layout: bindGroupLayout, buffer: uniformBuffer),
              let pipeline = Self.makePipeline(device: device, layout: bindGroupLayout, shader: shader)
        else {
            wgpuQueueRelease(queue)
            wgpuDeviceRelease(device)
            wgpuAdapterRelease(adapter)
            wgpuSurfaceRelease(surface)
            wgpuInstanceRelease(instance)
            return nil
        }

        self.instance = instance
        self.surface = surface
        self.adapter = adapter
        self.device = device
        self.queue = queue
        self.uniformBuffer = uniformBuffer
        self.bindGroupLayout = bindGroupLayout
        self.bindGroup = bindGroup
        self.pipeline = pipeline
        interAppPublisher?.attach(device: device, queue: queue)
    }

    deinit {
        releaseInterAppCopyTexture()
        interAppPublisher?.detach()
        wgpuRenderPipelineRelease(pipeline)
        wgpuBindGroupRelease(bindGroup)
        wgpuBindGroupLayoutRelease(bindGroupLayout)
        wgpuBufferRelease(uniformBuffer)
        wgpuQueueRelease(queue)
        wgpuDeviceRelease(device)
        wgpuAdapterRelease(adapter)
        wgpuSurfaceRelease(surface)
        wgpuInstanceRelease(instance)
    }

    @discardableResult
    public func configure(width: UInt32, height: UInt32) -> Bool {
        guard width > 0, height > 0 else { return false }
        guard width != configuredWidth || height != configuredHeight else { return true }

        var configuration = WGPUSurfaceConfiguration()
        configuration.device = device
        configuration.format = Self.surfaceFormat
        configuration.usage = WGPUTextureUsage_RenderAttachment | WGPUTextureUsage_CopySrc
        configuration.width = width
        configuration.height = height
        configuration.alphaMode = WGPUCompositeAlphaMode_Opaque
        configuration.presentMode = WGPUPresentMode_Fifo
        wgpuSurfaceConfigure(surface, &configuration)
        configuredWidth = width
        configuredHeight = height
        syncInterAppCopyTexture()
        interAppPublisher?.resize(width: width, height: height)
        return true
    }

    public func setInterAppPublisher(_ publisher: InterAppTexturePublisher?) {
        interAppPublisher?.detach()
        interAppPublisher = publisher
        interAppPublisher?.attach(device: device, queue: queue)
        if configuredWidth > 0, configuredHeight > 0 {
            interAppPublisher?.resize(width: configuredWidth, height: configuredHeight)
        }
        syncInterAppCopyTexture()
    }

    private func syncInterAppCopyTexture() {
        guard interAppPublisher?.isEnabled == true, configuredWidth > 0, configuredHeight > 0 else {
            releaseInterAppCopyTexture()
            return
        }
        ensureInterAppCopyTexture(width: configuredWidth, height: configuredHeight)
    }

    public func render(frameTime: CFTimeInterval?) -> VisualFrameStatus {
        guard configuredWidth > 0, configuredHeight > 0 else { return .notConfigured }

        let time = frameTime ?? (CFAbsoluteTimeGetCurrent() - startTime)
        let elapsed = Float(time)
        let uniforms: (Float, Float, Float, Float) = (
            elapsed,
            Float(configuredWidth),
            Float(configuredHeight),
            0
        )
        withUnsafeBytes(of: uniforms) { bytes in
            wgpuQueueWriteBuffer(queue, uniformBuffer, 0, bytes.baseAddress, Self.uniformStride)
        }

        var surfaceTexture = WGPUSurfaceTexture()
        wgpuSurfaceGetCurrentTexture(surface, &surfaceTexture)

        let okStatus: VisualFrameStatus
        switch surfaceTexture.status {
        case WGPUSurfaceGetCurrentTextureStatus_SuccessOptimal:
            okStatus = .rendered
        case WGPUSurfaceGetCurrentTextureStatus_SuccessSuboptimal:
            okStatus = .renderedSuboptimal
        default:
            if let texture = surfaceTexture.texture { wgpuTextureRelease(texture) }
            return .skipped
        }

        guard let texture = surfaceTexture.texture else { return .skipped }

        var didPresent = false
        func present() {
            guard !didPresent else { return }
            didPresent = true
            _ = wgpuSurfacePresent(surface)
            _ = wgpuDevicePoll(device, 0, nil)
        }
        defer {
            present()
            wgpuTextureRelease(texture)
        }

        guard let targetView = wgpuTextureCreateView(texture, nil) else { return .skipped }
        defer { wgpuTextureViewRelease(targetView) }
        guard let encoder = wgpuDeviceCreateCommandEncoder(device, nil) else { return .skipped }
        defer { wgpuCommandEncoderRelease(encoder) }

        var attachment = WGPURenderPassColorAttachment()
        attachment.view = targetView
        attachment.depthSlice = UInt32.max
        attachment.loadOp = WGPULoadOp_Clear
        attachment.storeOp = WGPUStoreOp_Store
        attachment.clearValue = WGPUColor(r: 0, g: 0, b: 0, a: 1)

        let encoded = withUnsafePointer(to: &attachment) { attachmentPointer -> Bool in
            var descriptor = WGPURenderPassDescriptor()
            descriptor.colorAttachmentCount = 1
            descriptor.colorAttachments = attachmentPointer
            guard let pass = wgpuCommandEncoderBeginRenderPass(encoder, &descriptor) else { return false }
            let drawPipeline = pipeline
            let drawBindGroup = bindGroup
            var visualContext = VisualRenderContext {
                wgpuRenderPassEncoderSetPipeline(pass, drawPipeline)
                wgpuRenderPassEncoderSetBindGroup(pass, 0, drawBindGroup, 0, nil)
                wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0)
            }
            rootVisual.render(in: &visualContext)
            wgpuRenderPassEncoderEnd(pass)
            wgpuRenderPassEncoderRelease(pass)
            return true
        }

        guard encoded else { return .skipped }

        if let interAppCopyTexture {
            var source = WGPUTexelCopyTextureInfo()
            source.texture = texture
            source.mipLevel = 0
            source.origin = WGPUOrigin3D(x: 0, y: 0, z: 0)
            source.aspect = WGPUTextureAspect_All
            var destination = source
            destination.texture = interAppCopyTexture
            var copySize = WGPUExtent3D(width: configuredWidth, height: configuredHeight, depthOrArrayLayers: 1)
            wgpuCommandEncoderCopyTextureToTexture(encoder, &source, &destination, &copySize)
        }

        guard let commandBuffer = wgpuCommandEncoderFinish(encoder, nil) else { return .skipped }
        var submitted: WGPUCommandBuffer? = commandBuffer
        withUnsafePointer(to: &submitted) { wgpuQueueSubmit(queue, 1, $0) }
        wgpuCommandBufferRelease(commandBuffer)
        _ = wgpuDevicePoll(device, 0, nil)

        if let interAppCopyTexture, let interAppPublisher, interAppPublisher.isEnabled {
            interAppPublisher.publish(
                texture: interAppCopyTexture,
                width: configuredWidth,
                height: configuredHeight
            )
        }

        present()
        return okStatus
    }

    private func ensureInterAppCopyTexture(width: UInt32, height: UInt32) {
        guard width > 0, height > 0 else { return }
        if interAppCopyTexture != nil, interAppCopyWidth == width, interAppCopyHeight == height { return }

        releaseInterAppCopyTexture()
        var descriptor = WGPUTextureDescriptor()
        descriptor.usage = WGPUTextureUsage_CopyDst | WGPUTextureUsage_TextureBinding
        descriptor.dimension = WGPUTextureDimension_2D
        descriptor.size = WGPUExtent3D(width: width, height: height, depthOrArrayLayers: 1)
        descriptor.format = Self.surfaceFormat
        descriptor.mipLevelCount = 1
        descriptor.sampleCount = 1
        interAppCopyTexture = wgpuDeviceCreateTexture(device, &descriptor)
        interAppCopyWidth = width
        interAppCopyHeight = height
    }

    private func releaseInterAppCopyTexture() {
        if let interAppCopyTexture {
            wgpuTextureRelease(interAppCopyTexture)
            self.interAppCopyTexture = nil
        }
        interAppCopyWidth = 0
        interAppCopyHeight = 0
    }

    private static let shaderSource = """
    struct VisualUniforms {
        time: f32,
        resolution: vec2<f32>,
        _pad: f32,
    };

    @group(0) @binding(0) var<uniform> u: VisualUniforms;

    struct VertexOut {
        @builtin(position) position: vec4<f32>,
        @location(0) uv: vec2<f32>,
    };

    @vertex
    fn vs(@builtin(vertex_index) vid: u32) -> VertexOut {
        var positions = array<vec2<f32>, 3>(
            vec2(-1.0, -1.0),
            vec2(3.0, -1.0),
            vec2(-1.0, 3.0),
        );
        var out: VertexOut;
        let pos = positions[vid];
        out.position = vec4(pos, 0.0, 1.0);
        out.uv = pos * 0.5 + 0.5;
        return out;
    }

    fn hash21(p: vec2<f32>) -> f32 {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
    }

    fn noise(p: vec2<f32>) -> f32 {
        let i = floor(p);
        let f = fract(p);
        let u = f * f * (3.0 - 2.0 * f);
        let a = hash21(i);
        let b = hash21(i + vec2(1.0, 0.0));
        let c = hash21(i + vec2(0.0, 1.0));
        let d = hash21(i + vec2(1.0, 1.0));
        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    }

    @fragment
    fn fs(in: VertexOut) -> @location(0) vec4<f32> {
        let uv = in.uv;
        let aspect = u.resolution.x / max(u.resolution.y, 1.0);
        var p = (uv - 0.5) * vec2(aspect, 1.0);

        let t = u.time * 0.35;
        let warp = vec2(
            sin(p.y * 3.0 + t) * 0.15,
            cos(p.x * 2.5 - t * 1.1) * 0.15
        );
        let q = p + warp;
        let n = noise(q * 4.0 + t);
        let bands = sin((length(q) - t * 0.4) * 12.0 + n * 6.0);

        var col = vec3(
            0.45 + 0.35 * sin(t + bands * 2.0 + n),
            0.25 + 0.45 * cos(t * 0.7 + bands),
            0.55 + 0.35 * sin(t * 1.3 - n * 3.0)
        );
        col *= 0.65 + 0.35 * bands;
        return vec4(col, 1.0);
    }
    """

    private static func makeShaderModule(device: WGPUDevice) -> WGPUShaderModule? {
        withWGPUString(shaderSource) { code in
            var shaderSource = WGPUShaderSourceWGSL()
            shaderSource.chain.sType = WGPUSType_ShaderSourceWGSL
            shaderSource.code = code
            return withChained(&shaderSource) { chain in
                var descriptor = WGPUShaderModuleDescriptor()
                descriptor.nextInChain = chain
                return wgpuDeviceCreateShaderModule(device, &descriptor)
            }
        }
    }

    private static func makeUniformBuffer(device: WGPUDevice) -> WGPUBuffer? {
        var descriptor = WGPUBufferDescriptor()
        descriptor.usage = WGPUBufferUsage_Uniform | WGPUBufferUsage_CopyDst
        descriptor.size = UInt64(uniformStride)
        return wgpuDeviceCreateBuffer(device, &descriptor)
    }

    private static func makeBindGroupLayout(device: WGPUDevice) -> WGPUBindGroupLayout? {
        var entry = WGPUBindGroupLayoutEntry()
        entry.binding = 0
        entry.visibility = WGPUShaderStage_Fragment
        entry.buffer.type = WGPUBufferBindingType_Uniform
        entry.buffer.minBindingSize = UInt64(uniformStride)
        return withUnsafePointer(to: entry) { entryPointer in
            var descriptor = WGPUBindGroupLayoutDescriptor()
            descriptor.entryCount = 1
            descriptor.entries = entryPointer
            return wgpuDeviceCreateBindGroupLayout(device, &descriptor)
        }
    }

    private static func makeBindGroup(
        device: WGPUDevice,
        layout: WGPUBindGroupLayout,
        buffer: WGPUBuffer
    ) -> WGPUBindGroup? {
        var entry = WGPUBindGroupEntry()
        entry.binding = 0
        entry.buffer = buffer
        entry.offset = 0
        entry.size = UInt64(uniformStride)
        return withUnsafePointer(to: entry) { entryPointer in
            var descriptor = WGPUBindGroupDescriptor()
            descriptor.layout = layout
            descriptor.entryCount = 1
            descriptor.entries = entryPointer
            return wgpuDeviceCreateBindGroup(device, &descriptor)
        }
    }

    private static func makePipeline(
        device: WGPUDevice,
        layout: WGPUBindGroupLayout,
        shader: WGPUShaderModule
    ) -> WGPURenderPipeline? {
        var pipelineLayoutDescriptor = WGPUPipelineLayoutDescriptor()
        pipelineLayoutDescriptor.bindGroupLayoutCount = 1
        pipelineLayoutDescriptor.bindGroupLayouts = withUnsafePointer(to: layout) { $0 }
        guard let pipelineLayout = wgpuDeviceCreatePipelineLayout(device, &pipelineLayoutDescriptor) else {
            return nil
        }
        defer { wgpuPipelineLayoutRelease(pipelineLayout) }

        return withWGPUString("vs") { vertexEntry in
            withWGPUString("fs") { fragmentEntry in
                var target = WGPUColorTargetState()
                target.format = surfaceFormat
                target.writeMask = WGPUColorWriteMask_All
                return withUnsafePointer(to: &target) { targetPointer in
                    var fragment = WGPUFragmentState()
                    fragment.module = shader
                    fragment.entryPoint = fragmentEntry
                    fragment.targetCount = 1
                    fragment.targets = targetPointer
                    return withUnsafePointer(to: &fragment) { fragmentPointer in
                        var descriptor = WGPURenderPipelineDescriptor()
                        descriptor.layout = pipelineLayout
                        descriptor.vertex.module = shader
                        descriptor.vertex.entryPoint = vertexEntry
                        descriptor.vertex.bufferCount = 0
                        descriptor.fragment = fragmentPointer
                        descriptor.primitive.topology = WGPUPrimitiveTopology_TriangleList
                        descriptor.primitive.cullMode = WGPUCullMode_None
                        descriptor.multisample.count = 1
                        return wgpuDeviceCreateRenderPipeline(device, &descriptor)
                    }
                }
            }
        }
    }
}
