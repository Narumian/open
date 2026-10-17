import Foundation

/// Groups export sinks for the composited frame (GPU texture bus, virtual camera, encoders, etc.).
///
/// Output leaves do not draw; they register backends during the view-tree walk. Visual content
/// belongs in sibling `Add` / `Mixer` blocks.
public struct Output<Content: View>: View {
    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Content { content }
}

extension Output: ViewRepresentable {
    var viewNode: ViewNode {
        let child = content.flattenedNode()
        switch child {
        case .group(let children), .output(let children):
            return .output(children)
        default:
            return .output([child])
        }
    }
}

// MARK: - Stream output stubs (registry / backend TBD)

public enum VideoEncodePreset: String, Sendable {
    case h264
    case hevc
}

/// Stub: H.264/HEVC encoded stream (future `VideoEncoderStream` / VTCompressionSession).
public struct EncodedStream: View {
    public typealias Body = Never

    public let preset: VideoEncodePreset

    public init(preset: VideoEncodePreset = .h264) {
        self.preset = preset
    }

    public var body: Never {
        fatalError("EncodedStream is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.registerStreamOutput(.encodedVideo(preset: preset))
    }
}

extension EncodedStream: ViewRepresentable {
    var viewNode: ViewNode { .encodedStream(preset: preset) }
}

/// Stub: muxed broadcast (RTMP/SRT/WebRTC — future `MuxedBroadcastStream`).
public struct MuxedBroadcastStream: View {
    public typealias Body = Never

    public let endpointLabel: String

    public init(_ endpointLabel: String) {
        self.endpointLabel = endpointLabel
    }

    public var body: Never {
        fatalError("MuxedBroadcastStream is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.registerStreamOutput(.muxedBroadcast(endpointLabel: endpointLabel))
    }
}

extension MuxedBroadcastStream: ViewRepresentable {
    var viewNode: ViewNode { .muxedBroadcast(endpointLabel: endpointLabel) }
}

/// Stub: disk recording (future `FileRecording` sink).
public struct FileRecording: View {
    public typealias Body = Never

    public let destinationLabel: String

    public init(_ destinationLabel: String) {
        self.destinationLabel = destinationLabel
    }

    public var body: Never {
        fatalError("FileRecording is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.registerStreamOutput(.fileRecording(destinationLabel: destinationLabel))
    }
}

extension FileRecording: ViewRepresentable {
    var viewNode: ViewNode { .fileRecording(destinationLabel: destinationLabel) }
}

/// Stub: raw sample buffer tap (future CPU `RawSampleBuffer` path).
public struct RawSampleBuffer: View {
    public typealias Body = Never

    public init() {}

    public var body: Never {
        fatalError("RawSampleBuffer is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.registerStreamOutput(.rawSampleBuffer)
    }
}

extension RawSampleBuffer: ViewRepresentable {
    var viewNode: ViewNode { .rawSampleBuffer }
}
