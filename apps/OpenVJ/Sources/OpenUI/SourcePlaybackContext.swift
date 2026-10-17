import Foundation

/// Per-frame source catalog + playlist state carried on `ViewRenderContext`.
///
/// This is intentionally **not** SwiftUI `@Environment`: the host constructs one
/// `ViewRenderContext` per frame (or export step) and nested scopes such as `VJPlayer`
/// mutate `sourcePlayback` on that same value. Child views read/write selection and
/// sequence index through `context.sourcePlayback` during `render` / `renderLeaf`.
public struct SourcePlaybackContext {
    /// When nil, reads/writes go through `SourceCatalogRegistry.selectionState`.
    public var selectionState: SourceSelectionState?

    /// Active `SequencePlayer` state (clip index + local timeline). Nil when no sequence leaf bound.
    public var sequence: SequenceTransportState?

    /// Nesting depth for `VJPlayer` transport scopes (used to gate session clock writes).
    public var vjTransportDepth: Int = 0

    public static let defaultClipDurationSeconds: Float = 10

    public init(selectionState: SourceSelectionState? = nil) {
        self.selectionState = selectionState
    }

    public var resolvedSelectionState: SourceSelectionState {
        selectionState ?? SourceCatalogRegistry.selectionState
    }

    public var selection: SourceSelection {
        get { resolvedSelectionState.selection }
        set { resolvedSelectionState.selection = newValue }
    }

    public var mediaFolderURL: URL? {
        get { resolvedSelectionState.mediaFolderURL }
        set { resolvedSelectionState.mediaFolderURL = newValue }
    }

    /// `ObjectIdentifier` of the registered catalog when present (for logging / host adapters).
    public var catalogID: ObjectIdentifier? {
        SourceCatalogRegistry.current.map { ObjectIdentifier($0) }
    }

    /// Local file URL from the current browser selection, if any.
    public var selectedLocalFileURL: URL? {
        guard let descriptor = selection.descriptor else { return nil }
        if case .localFile(let url) = descriptor.kind {
            return url
        }
        return nil
    }

    public mutating func beginVJTransport(frameTime: Float) {
        vjTransportDepth += 1
        if vjTransportDepth == 1 {
            VJPlaybackSession.activeTime = frameTime
            VJPlaybackSession.isPlaying = true
        }
    }

    public mutating func endVJTransport() {
        vjTransportDepth = max(0, vjTransportDepth - 1)
    }

    public mutating func bindSequence(clips: [URL], loops: Bool) {
        if sequence?.clips == clips, sequence?.loops == loops {
            return
        }
        sequence = SequenceTransportState(clips: clips, loops: loops)
    }

    /// Advances the bound sequence using host-resolved durations (placeholder when unknown).
    public mutating func tickSequence(
        frameTime: Float,
        resolveDuration: (URL) -> Float?
    ) {
        guard var active = sequence, !active.clips.isEmpty else { return }

        let delta: Float
        if let last = active.lastFrameTime {
            delta = max(0, frameTime - last)
        } else {
            delta = 0
        }
        active.lastFrameTime = frameTime

        guard active.clips.indices.contains(active.clipIndex) else {
            sequence = active
            return
        }

        active.elapsedInClip += delta
        var duration = resolveDuration(active.clips[active.clipIndex]) ?? Self.defaultClipDurationSeconds
        if duration <= 0 {
            duration = Self.defaultClipDurationSeconds
        }

        while active.elapsedInClip >= duration {
            active.elapsedInClip -= duration
            let nextIndex = active.clipIndex + 1
            if nextIndex < active.clips.count {
                active.clipIndex = nextIndex
            } else if active.loops {
                active.clipIndex = 0
            } else {
                active.clipIndex = active.clips.count - 1
                active.elapsedInClip = duration
                break
            }
            duration = resolveDuration(active.clips[active.clipIndex]) ?? Self.defaultClipDurationSeconds
            if duration <= 0 {
                duration = Self.defaultClipDurationSeconds
            }
        }

        sequence = active
    }

    public func activeSequenceClipURL() -> URL? {
        guard let active = sequence, active.clips.indices.contains(active.clipIndex) else {
            return nil
        }
        return active.clips[active.clipIndex]
    }
}

/// Host-driven playlist index + local time (OpenUI only; durations come from host callbacks).
public struct SequenceTransportState: Equatable, Sendable {
    public var clips: [URL]
    public var loops: Bool
    public var clipIndex: Int
    public var elapsedInClip: Float
    public var lastFrameTime: Float?

    public init(clips: [URL], loops: Bool, clipIndex: Int = 0, elapsedInClip: Float = 0) {
        self.clips = clips
        self.loops = loops
        self.clipIndex = clipIndex
        self.elapsedInClip = elapsedInClip
    }
}
