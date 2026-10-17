import AVFoundation
import Foundation
import OpenUI

/// macOS host adapter: clip durations and `VideoPlayer` instances (AVFoundation stays in OpenVJ).
protocol PlaybackHost: AnyObject {
    func makeVideoPlayer(for fileURL: URL) -> VideoPlayer?
    func clipDurationSeconds(for fileURL: URL) -> Float?
}

final class AVPlaybackHost: PlaybackHost {
    private weak var videoRenderState: WGPUVideoRenderState?
    private let lock = NSLock()
    private var durationCache: [URL: Float] = [:]

    func attach(videoRenderState: WGPUVideoRenderState) {
        self.videoRenderState = videoRenderState
    }

    func makeVideoPlayer(for fileURL: URL) -> VideoPlayer? {
        videoRenderState?.player(for: fileURL)
    }

    func clipDurationSeconds(for fileURL: URL) -> Float? {
        if let videoRenderState, let duration = videoRenderState.player(for: fileURL)?.durationSeconds {
            cacheDuration(fileURL, duration)
            return duration
        }

        lock.lock()
        if let cached = durationCache[fileURL] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let asset = AVURLAsset(url: fileURL)
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite, seconds > 0 else { return nil }

        let value = Float(seconds)
        cacheDuration(fileURL, value)
        return value
    }

    private func cacheDuration(_ fileURL: URL, _ value: Float) {
        lock.lock()
        durationCache[fileURL] = value
        lock.unlock()
    }
}
