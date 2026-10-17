import AVFoundation
import CoreVideo
import Foundation
import OpenUI

/// macOS `VideoPlayer` — `AVPlayer` decode + WGPU upload via `WGPUVideoRenderState`.
final class AVVideoPlayer: VideoPlayer {
    let fileURL: URL
    var loops: Bool {
        get { source.loops }
        set { source.loops = newValue }
    }

    private let source: VideoFrameSource
    private let cachedDuration: Float?
    private weak var renderState: WGPUVideoRenderState?

    init?(fileURL: URL, renderState: WGPUVideoRenderState) {
        guard fileURL.isFileURL, let source = VideoFrameSource(fileURL: fileURL) else { return nil }
        self.fileURL = fileURL
        self.source = source
        self.renderState = renderState

        let asset = AVURLAsset(url: fileURL)
        let seconds = CMTimeGetSeconds(asset.duration)
        if seconds.isFinite, seconds > 0 {
            cachedDuration = Float(seconds)
        } else {
            cachedDuration = nil
        }
    }

    var isPlaying: Bool { source.isPlaying }

    var currentTimeSeconds: Float { source.currentTimeSeconds }

    var durationSeconds: Float? { cachedDuration }

    func play() { source.play() }

    func pause() { source.pause() }

    func seek(toSeconds: Float) { source.seek(toSeconds: toSeconds) }

    func drawCurrentFrame(layerAlpha: Float) {
        renderState?.drawCurrentFrame(player: self, layerAlpha: layerAlpha)
    }

    func copyCurrentPixelBuffer() -> CVPixelBuffer? {
        source.copyCurrentPixelBuffer()
    }
}
