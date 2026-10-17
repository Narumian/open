import Foundation

/// Composes multiple visuals in **tree order** within the same render pass (stack semantics).
///
/// v0: each child issues a full-screen draw using the shared wave-body pipeline.
/// The first child is drawn at full opacity; each later child uses ~55% alpha so stacked leaves
/// (e.g. `SinBody` + `TanBody`) stay visible on top. This is sequential layering, not equal mix —
/// use `Mixer` when you want every layer weighted the same (`1 / N`).
public struct Add<Content: Visual>: Visual {
    public let content: Content

    public init(@VisualBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Content { content }
}
