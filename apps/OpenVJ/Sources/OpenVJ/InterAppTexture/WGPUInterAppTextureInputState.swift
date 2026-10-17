import CWGPU
import Foundation

final class WGPUInterAppTextureInputState {
    private static let uniformStride = 16
    private static let surfaceFormat = WGPUTextureFormat_BGRA8Unorm

    private let device: WGPUDevice
    private let queue: WGPUQueue
    private let pipeline: WGPURenderPipeline
    private let bindGroupLayout: WGPUBindGroupLayout
    private let uniformBuffer: WGPUBuffer
    private let sampler: WGPUSampler

    private var subscribers: [String: InterAppTextureSubscriber] = [:]
    private var textures: [String: WGPUTexture] = [:]
    private var textureWidths: [String: UInt32] = [:]
    private var textureHeights: [String: UInt32] = [:]
    private var hasFrame: [String: Bool] = [:]
    private static var didLogMissingInterAppBackend = false

    init?(device: WGPUDevice, queue: WGPUQueue) {
        self.device = device
        self.queue = queue

        guard let shader = Self.makeShaderModule(device: device),
              let uniformBuffer = Self.makeUniformBuffer(device: device),
              let bindGroupLayout = Self.makeBindGroupLayout(device: device),
              let sampler = Self.makeSampler(device: device),
              let pipeline = Self.makePipeline(device: device, layout: bindGroupLayout, shader: shader)
        else {
            return nil
        }

        self.uniformBuffer = uniformBuffer
        self.bindGroupLayout = bindGroupLayout
        self.sampler = sampler
        self.pipeline = pipeline
    }

    deinit {
        for subscriber in subscribers.values {
            subscriber.stop()
        }
        releaseAllTextures()
        wgpuRenderPipelineRelease(pipeline)
        wgpuSamplerRelease(sampler)
        wgpuBindGroupLayoutRelease(bindGroupLayout)
        wgpuBufferRelease(uniformBuffer)
    }

    func applySubscribeConfiguration(_ configuration: SubscriberConfiguration) {
        let key = configuration.serverName
        if let existing = subscribers[key] {
            if !existing.isReceiving {
                try? existing.start()
            }
            return
        }

        if let subscriber = InterAppTextureRegistry.makeSubscriber(configuration: configuration) {
            subscriber.attach(device: device, queue: queue)
            try? subscriber.start()
            subscribers[key] = subscriber
            return
        }

        if !Self.didLogMissingInterAppBackend {
            Self.didLogMissingInterAppBackend = true
            fputs(
                "[OpenVJ] Inter-app texture subscribe requested but no backend is linked (e.g. OpenVJSyphon). Run Scripts/fetch-syphon.sh and rebuild.\n",
                stderr
            )
        }
    }

    func prepareFrames(surfaceWidth: UInt32, surfaceHeight: UInt32) {
        for (key, subscriber) in subscribers {
            guard subscriber.isReceiving else {
                hasFrame[key] = false
                continue
            }
            ensureTexture(key: key, width: surfaceWidth, height: surfaceHeight)
            let width = textureWidths[key] ?? 0
            let height = textureHeights[key] ?? 0
            guard width > 0, height > 0, let texture = textures[key] else {
                hasFrame[key] = false
                continue
            }
            hasFrame[key] = subscriber.importLatestFrame(into: texture, width: width, height: height)
        }
    }

    func draw(serverName: String, layerAlpha: Float, pass: WGPURenderPassEncoder, surfaceWidth: UInt32, surfaceHeight: UInt32) {
        let key = serverName
        guard subscribers[key] != nil else { return }
        ensureTexture(key: key, width: surfaceWidth, height: surfaceHeight)
        guard hasFrame[key] == true, let texture = textures[key] else { return }
        guard let textureView = wgpuTextureCreateView(texture, nil) else { return }
        defer { wgpuTextureViewRelease(textureView) }

        writeUniforms(layerAlpha: layerAlpha)
        guard let bindGroup = makeBindGroup(textureView: textureView) else { return }
        defer { wgpuBindGroupRelease(bindGroup) }

        wgpuRenderPassEncoderSetPipeline(pass, pipeline)
        wgpuRenderPassEncoderSetBindGroup(pass, 0, bindGroup, 0, nil)
        wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0)
    }

    private func ensureTexture(key: String, width: UInt32, height: UInt32) {
        guard width > 0, height > 0 else { return }
        if textures[key] != nil,
           textureWidths[key] == width,
           textureHeights[key] == height
        {
            return
        }

        if let existing = textures[key] {
            wgpuTextureRelease(existing)
            textures[key] = nil
        }

        var descriptor = WGPUTextureDescriptor()
        descriptor.usage = WGPUTextureUsage_TextureBinding | WGPUTextureUsage_CopyDst
        descriptor.dimension = WGPUTextureDimension_2D
        descriptor.size = WGPUExtent3D(width: width, height: height, depthOrArrayLayers: 1)
        descriptor.format = Self.surfaceFormat
        descriptor.mipLevelCount = 1
        descriptor.sampleCount = 1
        textures[key] = wgpuDeviceCreateTexture(device, &descriptor)
        textureWidths[key] = width
        textureHeights[key] = height
        hasFrame[key] = false
    }

    private func releaseAllTextures() {
        for texture in textures.values {
            wgpuTextureRelease(texture)
        }
        textures.removeAll()
        textureWidths.removeAll()
        textureHeights.removeAll()
        hasFrame.removeAll()
    }

    private func writeUniforms(layerAlpha: Float) {
        let uniforms: (Float, Float, Float, Float) = (layerAlpha, 0, 0, 0)
        withUnsafeBytes(of: uniforms) { bytes in
            wgpuQueueWriteBuffer(queue, uniformBuffer, 0, bytes.baseAddress, Self.uniformStride)
        }
    }

    private func makeBindGroup(textureView: WGPUTextureView) -> WGPUBindGroup? {
        var entries: [WGPUBindGroupEntry] = []
        var uniformEntry = WGPUBindGroupEntry()
        uniformEntry.binding = 0
        uniformEntry.buffer = uniformBuffer
        uniformEntry.offset = 0
        uniformEntry.size = UInt64(Self.uniformStride)
        entries.append(uniformEntry)

        var textureEntry = WGPUBindGroupEntry()
        textureEntry.binding = 1
        textureEntry.textureView = textureView
        entries.append(textureEntry)

        var samplerEntry = WGPUBindGroupEntry()
        samplerEntry.binding = 2
        samplerEntry.sampler = sampler
        entries.append(samplerEntry)

        return entries.withUnsafeBufferPointer { entriesPointer in
            var descriptor = WGPUBindGroupDescriptor()
            descriptor.layout = bindGroupLayout
            descriptor.entryCount = entriesPointer.count
            descriptor.entries = entriesPointer.baseAddress
            return wgpuDeviceCreateBindGroup(device, &descriptor)
        }
    }

    private static let shaderSource = """
    struct InputUniforms {
        layerAlpha: f32,
    };

    @group(0) @binding(0) var<uniform> u: InputUniforms;
    @group(0) @binding(1) var inputTex: texture_2d<f32>;
    @group(0) @binding(2) var inputSampler: sampler;

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
        out.uv = vec2(pos.x * 0.5 + 0.5, 0.5 - pos.y * 0.5);
        return out;
    }

    @fragment
    fn fs(in: VertexOut) -> @location(0) vec4<f32> {
        let sample = textureSample(inputTex, inputSampler, in.uv);
        return vec4(sample.rgb, sample.a * u.layerAlpha);
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
        var entries: [WGPUBindGroupLayoutEntry] = []

        var uniform = WGPUBindGroupLayoutEntry()
        uniform.binding = 0
        uniform.visibility = WGPUShaderStage_Fragment
        uniform.buffer.type = WGPUBufferBindingType_Uniform
        uniform.buffer.minBindingSize = UInt64(uniformStride)
        entries.append(uniform)

        var texture = WGPUBindGroupLayoutEntry()
        texture.binding = 1
        texture.visibility = WGPUShaderStage_Fragment
        texture.texture.sampleType = WGPUTextureSampleType_Float
        texture.texture.viewDimension = WGPUTextureViewDimension_2D
        entries.append(texture)

        var samplerEntry = WGPUBindGroupLayoutEntry()
        samplerEntry.binding = 2
        samplerEntry.visibility = WGPUShaderStage_Fragment
        samplerEntry.sampler.type = WGPUSamplerBindingType_Filtering
        entries.append(samplerEntry)

        return entries.withUnsafeBufferPointer { entriesPointer in
            var descriptor = WGPUBindGroupLayoutDescriptor()
            descriptor.entryCount = entriesPointer.count
            descriptor.entries = entriesPointer.baseAddress
            return wgpuDeviceCreateBindGroupLayout(device, &descriptor)
        }
    }

    private static func makeSampler(device: WGPUDevice) -> WGPUSampler? {
        wgpuDeviceCreateSampler(device, nil)
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
                var blend = WGPUBlendState()
                blend.color.operation = WGPUBlendOperation_Add
                blend.color.srcFactor = WGPUBlendFactor_SrcAlpha
                blend.color.dstFactor = WGPUBlendFactor_OneMinusSrcAlpha
                blend.alpha.operation = WGPUBlendOperation_Add
                blend.alpha.srcFactor = WGPUBlendFactor_One
                blend.alpha.dstFactor = WGPUBlendFactor_OneMinusSrcAlpha
                return withUnsafePointer(to: &blend) { blendPointer in
                    var target = WGPUColorTargetState()
                    target.format = surfaceFormat
                    target.writeMask = WGPUColorWriteMask_All
                    target.blend = blendPointer
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
}
