import Foundation

/// Backend-neutral draw commands issued while traversing a `Visual` tree.
public struct VisualRenderContext {
    private let drawShader: () -> Void

    init(drawShader: @escaping () -> Void) {
        self.drawShader = drawShader
    }

    public func drawGenerativeShader() {
        drawShader()
    }

    /// Renders a flattened node tree using the same draw hooks as the declarative API.
    public func render(node: VisualNode) {
        switch node {
        case .empty:
            break
        case .generativeShader:
            drawGenerativeShader()
        case .group(let children):
            for child in children {
                render(node: child)
            }
        }
    }
}
