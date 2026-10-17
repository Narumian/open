import Foundation

public enum SourceRendering {
    /// Renders the `Openable` view for the active browser selection.
    public static func draw(selection: SourceSelection, in context: inout ViewRenderContext) {
        context.render(node: selection.opened().flattenedNode())
    }
}
