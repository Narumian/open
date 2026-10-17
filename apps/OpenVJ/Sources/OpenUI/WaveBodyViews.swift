import Foundation

/// Frame time written by `WGPUVisualRenderer` before traversing the view tree.
/// Use with `TanBody().time(OpenVJSceneTime.current)` when the scene graph is built each frame.
public enum OpenVJSceneTime {
    public static var current: Float = 0
}

public enum WaveMode: Float, Sendable {
    case sin = 0
    case tan = 1
}

/// Sin-domain warp generative leaf (`Body == Never`).
public struct SinBody: View {
    public typealias Body = Never

    public init() {}

    public var body: Never {
        fatalError("SinBody is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.drawWaveBody(mode: .sin, time: nil)
    }
}

extension SinBody: ViewRepresentable {
    var viewNode: ViewNode { .waveBody(.sin, explicitTime: nil) }
}

/// Tan-domain warp generative leaf. Optional fixed time via `.time(_:)`.
public struct TanBody: View {
    public typealias Body = Never

    public var explicitTime: Float?

    public init() {
        explicitTime = nil
    }

    init(explicitTime: Float?) {
        self.explicitTime = explicitTime
    }

    public var body: Never {
        fatalError("TanBody is a leaf")
    }

    public func time(_ t: Float) -> TanBody {
        TanBody(explicitTime: t)
    }

    public func time(_ t: CFTimeInterval) -> TanBody {
        time(Float(t))
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.drawWaveBody(mode: .tan, time: explicitTime)
    }
}

extension TanBody: ViewRepresentable {
    var viewNode: ViewNode {
        .waveBody(.tan, explicitTime: explicitTime)
    }
}
