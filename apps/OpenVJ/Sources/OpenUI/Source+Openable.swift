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
        switch descriptor.kind {
        case .localFile(let url):
            Video(path: url.path).render(in: &context)
        case .interAppInput(let serverName):
            InterAppTextureInput(serverName).render(in: &context)
        case .url, .captureDevice:
            EmptyView().render(in: &context)
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
        switch selection {
        case .none:
            EmptyView().render(in: &context)
        case .source(let descriptor):
            descriptor.opened().render(in: &context)
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
