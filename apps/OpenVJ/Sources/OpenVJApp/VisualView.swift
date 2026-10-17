import AppKit
import OpenVJ
import QuartzCore

final class VisualView: NSView {
    private var renderer: WGPUVisualRenderer?
    private var timer: Timer?
    private var lastDrawableSize = CGSize.zero

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
        guard let renderer = WGPUVisualRenderer(metalLayer: layerPointer) else {
            fatalError("WebGPU renderer failed to initialize.")
        }
        self.renderer = renderer
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
}
