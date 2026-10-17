import AppKit
import OpenUI
import OpenVJ
import QuartzCore

final class VisualView: NSView {
    private var renderer: VisualRenderer?
    private var timer: Timer?
    private var lastDrawableSize = CGSize.zero
    private let interAppController = InterAppTextureController()

    override func makeBackingLayer() -> CALayer { CAMetalLayer() }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
        if let metalLayer = layer as? CAMetalLayer {
            metalLayer.isOpaque = true
            metalLayer.backgroundColor = NSColor.black.cgColor
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    deinit {
        timer?.invalidate()
        renderer = nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopRendering()
        } else {
            startRenderingIfNeeded()
        }
    }

    override func layout() {
        super.layout()
        updateDrawableSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
    }

    private var metalLayer: CAMetalLayer? { layer as? CAMetalLayer }

    private func startRenderingIfNeeded() {
        guard let metalLayer, renderer == nil else { return }
        let layerPointer = Unmanaged.passUnretained(metalLayer).toOpaque()
        let attachment = VisualSurfaceAttachment(metalLayer: layerPointer)
        guard let renderer = VisualRender.makeRenderer(attachment: attachment) else {
            fatalError("Visual renderer failed to initialize.")
        }
        self.renderer = renderer
        interAppController.bootstrapIfNeeded()
        if InterAppTextureSettings.syphonRequestedAtLaunch, let wgpu = renderer as? WGPUVisualRenderer {
            wgpu.rootView = AnyView(OpenVJLiveScene())
            wgpu.sceneInterAppPublishSuppressed = false
        }
        updateDrawableSize()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.renderFrame()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopRendering() {
        timer?.invalidate()
        timer = nil
        renderer = nil
        lastDrawableSize = .zero
    }

    private func updateDrawableSize() {
        guard let metalLayer else { return }
        let scale = max(window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1, 1)
        let size = CGSize(
            width: max(1, (bounds.width * scale).rounded()),
            height: max(1, (bounds.height * scale).rounded())
        )
        metalLayer.contentsScale = scale
        metalLayer.drawableSize = size
        guard size != lastDrawableSize else { return }
        lastDrawableSize = size
        _ = renderer?.configure(width: UInt32(size.width), height: UInt32(size.height))
    }

    private func renderFrame() {
        guard window != nil, !isHidden, bounds.width > 0, bounds.height > 0 else { return }
        _ = renderer?.render()
    }

    func setInterAppPublishing(_ enabled: Bool) {
        InterAppTextureSettings.publishEnabled = enabled
        if let wgpu = renderer as? WGPUVisualRenderer {
            wgpu.sceneInterAppPublishSuppressed = !enabled
        }
    }

    var isInterAppPublishing: Bool {
        guard let wgpu = renderer as? WGPUVisualRenderer else { return false }
        return !wgpu.sceneInterAppPublishSuppressed
    }
}
