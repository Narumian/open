import AVFoundation
import CoreVideo
import Foundation

/// Decodes a local file with `AVPlayer` + `AVPlayerItemVideoOutput` (BGRA pixel buffers).
public final class VideoFrameSource {
    let fileURL: URL

    private let player: AVPlayer
    private let playerItem: AVPlayerItem
    private let videoOutput: AVPlayerItemVideoOutput
    private var didLogNonFileURL = false
    var loops = true

    public init?(fileURL: URL) {
        guard fileURL.isFileURL else { return nil }
        self.fileURL = fileURL

        let asset = AVURLAsset(url: fileURL)
        let item = AVPlayerItem(asset: asset)
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
        item.add(output)

        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .none

        playerItem = item
        videoOutput = output
        self.player = player

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loopToStart),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        player.play()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        player.pause()
    }

    var isPlaying: Bool { player.rate > 0 }

    var currentTimeSeconds: Float {
        Float(CMTimeGetSeconds(player.currentTime()))
    }

    public func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(toSeconds: Float) {
        let time = CMTime(seconds: Double(toSeconds), preferredTimescale: 600)
        player.seek(to: time)
    }

    @objc private func loopToStart() {
        guard loops else {
            player.pause()
            return
        }
        player.seek(to: .zero)
        player.play()
    }

    public func copyCurrentPixelBuffer() -> CVPixelBuffer? {
        guard fileURL.isFileURL else {
            if !didLogNonFileURL {
                didLogNonFileURL = true
                fputs("[OpenVJ] Video v0 supports local file URLs only.\n", stderr)
            }
            return nil
        }

        let itemTime = player.currentTime()
        return videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
    }
}
