import Foundation

/// Composes multiple visuals in **tree order** within the same render pass.
///
/// v0: each child issues a full-screen draw using the shared wave-body pipeline.
/// Later draws use alpha blending so stacked leaves (e.g. `SinBody` + `TanBody`) remain visible.
/// This is not a GPU additive blend mode yet — it is sequential layering with partial opacity.
public struct Add<Content: Visual>: Visual {
    public let content: Content

    public init(@VisualBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Content { content }
}
