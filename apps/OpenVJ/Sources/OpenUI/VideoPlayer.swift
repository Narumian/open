import Foundation

/// Backend-neutral local clip playback. Decode, loop policy, and frame sampling are implemented
/// by the host (`OpenVJ` / browser); OpenUI only binds URLs and issues draw commands.
public protocol VideoPlayer: AnyObject {
    var fileURL: URL { get }
    var loops: Bool { get set }
    var isPlaying: Bool { get }
    var currentTimeSeconds: Float { get }
    var durationSeconds: Float? { get }

    func play()
    func pause()
    func seek(toSeconds: Float)

    /// Sample the decoder at the current timeline and composite (host GPU / canvas path).
    func drawCurrentFrame(layerAlpha: Float)
}
