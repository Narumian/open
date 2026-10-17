import AVFoundation
import Foundation
import OpenUI

/// macOS host adapter: clip durations and decode/loop stay in OpenVJ (not OpenUI).
protocol PlaybackHost: AnyObject {
    func clipDurationSeconds(for fileURL: URL) -> Float?
}

final class AVPlaybackHost: PlaybackHost {
    private let lock = NSLock()
    private var cache: [URL: Float] = [:]

    func clipDurationSeconds(for fileURL: URL) -> Float? {
        lock.lock()
        if let cached = cache[fileURL] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let asset = AVURLAsset(url: fileURL)
        // Sync probe for v0 transport; decode path uses AVPlayer end notifications separately.
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite, seconds > 0 else { return nil }

        let value = Float(seconds)
        lock.lock()
        cache[fileURL] = value
        lock.unlock()
        return value
    }
}
