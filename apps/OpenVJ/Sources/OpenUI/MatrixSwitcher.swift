import Foundation

/// Mutable active bus index for `MatrixSwitcher` (SwiftUI-free shared state).
public final class MatrixSwitcherBus: @unchecked Sendable {
    public var activeIndex: Int

    public init(activeIndex: Int = 0) {
        self.activeIndex = activeIndex
    }
}

/// VJ matrix / bus switcher: **one active input** at a time (v0 hard cut).
///
/// Children are full-screen inputs (e.g. `Video`, `SinBody`, `InterAppTextureInput`).
/// Only the selected bus is drawn each frame — unlike `Mixer` (blend all at `1/N`) or
/// `Add` (stack with decreasing opacity).
///
/// ```swift
/// MatrixSwitcher {
///     Video(path: "a.mov")
///     SinBody()
///     InterAppTextureInput("Resolume")
/// }
/// ```
///
/// Drive the bus from app code with `MatrixSwitcherBus` or a fixed `activeIndex`.
public struct MatrixSwitcher<Content: View>: View {
    public let content: Content
    /// When non-nil, reads/writes `activeIndex` on this object each frame.
    public var selection: MatrixSwitcherBus?
    /// Used when `selection` is nil (default bus 0).
    public var activeIndex: Int

    public init(activeIndex: Int = 0, @ViewBuilder content: () -> Content) {
        selection = nil
        self.activeIndex = activeIndex
        self.content = content()
    }

    public init(selection: MatrixSwitcherBus, @ViewBuilder content: () -> Content) {
        self.selection = selection
        activeIndex = 0
        self.content = content()
    }

    public var body: Never {
        fatalError("MatrixSwitcher is a composite container")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        let children = Self.childNodes(of: content)
        guard !children.isEmpty else { return }
        let index = Self.clampedIndex(
            Self.resolvedActiveIndex(selection: selection, activeIndex: activeIndex),
            childCount: children.count
        )
        context.render(node: children[index])
    }
}

extension MatrixSwitcher: ViewRepresentable {
    var viewNode: ViewNode {
        let children = Self.childNodes(of: content)
        let index = Self.clampedIndex(
            Self.resolvedActiveIndex(selection: selection, activeIndex: activeIndex),
            childCount: max(1, children.count)
        )
        return .matrixSwitcher(children, activeIndex: index)
    }
}

extension MatrixSwitcher {
    static func childNodes(of view: some View) -> [ViewNode] {
        switch view.flattenedNode() {
        case .group(let children), .mixer(let children), .matrixSwitcher(let children, _):
            return children
        case .empty:
            return []
        default:
            return [view.flattenedNode()]
        }
    }

    static func resolvedActiveIndex(selection: MatrixSwitcherBus?, activeIndex: Int) -> Int {
        selection?.activeIndex ?? activeIndex
    }

    static func clampedIndex(_ index: Int, childCount: Int) -> Int {
        guard childCount > 0 else { return 0 }
        return min(max(0, index), childCount - 1)
    }
}
