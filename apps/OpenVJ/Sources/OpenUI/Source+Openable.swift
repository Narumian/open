import Foundation

/// Declarative leaf for one `SourceDescriptor` (`Video`, `InterAppTextureInput`, or no-op).
public struct OpenedSourceView: View {
    public let descriptor: SourceDescriptor

    public init(descriptor: SourceDescriptor) {
        self.descriptor = descriptor
    }

    public typealias Body = Never

    public var body: Never {
        fatalError("OpenedSourceView is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.render(node: flattenedNode())
    }
}

extension OpenedSourceView: ViewRepresentable {
    var viewNode: ViewNode {
        switch descriptor.kind {
        case .localFile(let url):
            return .video(fileURL: url.absoluteString)
        case .interAppInput(let serverName):
            return .interAppSubscribe(serverName: serverName)
        case .url, .captureDevice:
            return .empty
        }
    }
}

extension SourceDescriptor: Openable {
    public typealias Opened = OpenedSourceView

    @ViewBuilder
    public func opened() -> OpenedSourceView {
        OpenedSourceView(descriptor: self)
    }
}

/// Declarative leaf for `SourceSelection` (`.none` → `EmptyView`).
public struct OpenedSelectionView: View {
    public let selection: SourceSelection

    public init(selection: SourceSelection) {
        self.selection = selection
    }

    public typealias Body = Never

    public var body: Never {
        fatalError("OpenedSelectionView is a leaf")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        context.render(node: flattenedNode())
    }
}

extension OpenedSelectionView: ViewRepresentable {
    var viewNode: ViewNode {
        switch selection {
        case .none:
            return .empty
        case .source(let descriptor):
            return descriptor.opened().flattenedNode()
        }
    }
}

extension SourceSelection: Openable {
    public typealias Opened = OpenedSelectionView

    @ViewBuilder
    public func opened() -> OpenedSelectionView {
        OpenedSelectionView(selection: self)
    }
}
