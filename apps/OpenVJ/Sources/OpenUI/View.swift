import Foundation

/// SwiftUI-free declarative scene graph. Leaf types use `Body == Never` and draw via `renderLeaf`.
public protocol View {
    associatedtype Body: View

    @ViewBuilder var body: Body { get }
}

extension Never: View {
    @ViewBuilder public var body: Never {
        fatalError("Never is not a renderable view")
    }
}

extension View where Body == Never {
    /// Leaf views override this to issue draw commands.
    public func renderLeaf(in context: inout ViewRenderContext) {}
}

extension View {
    /// Walks `body` for composites, or `renderLeaf` for leaves.
    public func render(in context: inout ViewRenderContext) {
        _ViewRenderWalker.walk(self, in: &context)
    }
}

private enum _ViewRenderWalker {
    static func walk<V: View>(_ view: V, in context: inout ViewRenderContext) {
        renderLeafIfNeeded(view, in: &context)
    }

    static func renderLeafIfNeeded<V: View>(_ view: V, in context: inout ViewRenderContext)
    where V.Body == Never {
        view.renderLeaf(in: &context)
    }

    static func renderLeafIfNeeded<V: View>(_ view: V, in context: inout ViewRenderContext) {
        view.body.render(in: &context)
    }
}

/// Default scene: source browser + generative placeholder (`Some`), same shape as the app window.
public struct OpenVJDefaultScene: View {
    public init() {}

    public var body: Mixer<TupleView2<SourceBrowser, Some>> {
        Mixer {
            SourceBrowser()
            Some()
        }
    }
}

/// Example scene with an explicit time parameter (e.g. from your own clock).
public struct OpenVJTimedDemoScene: View {
    public let t: Float

    public init(time t: Float) {
        self.t = t
    }

    public var body: Add<TupleView2<SinBody, TanBody>> {
        Add {
            SinBody()
            TanBody().time(t)
        }
    }
}
