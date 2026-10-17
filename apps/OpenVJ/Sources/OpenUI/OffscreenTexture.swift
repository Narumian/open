import Foundation

/// Renders `content` into a named GPU texture bus, then presents it to the swapchain.
///
/// v0: WGPU draws `content` directly (same pass). XRenderer lowers this to an X3D
/// offscreen pass + blit via `OpenUIXSceneCompiler`.
public struct OffscreenTexture<Content: View>: View {
    public let name: String
    public let content: Content

    public init(_ name: String, @ViewBuilder content: () -> Content) {
        self.name = name
        self.content = content()
    }

    public var body: Never {
        fatalError("OffscreenTexture is a composite container")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.beginOffscreenTexture(name: name)
        content.render(in: &context)
        context.endOffscreenTexture()
    }
}

extension OffscreenTexture: ViewRepresentable {
    var viewNode: ViewNode {
        .offscreenTexture(name: name, content: content.flattenedNode())
    }
}
