import Foundation

public struct TupleVisual2<C0: Visual, C1: Visual>: Visual {
    public let first: C0
    public let second: C1

    public init(_ first: C0, _ second: C1) {
        self.first = first
        self.second = second
    }

    public var body: Never {
        fatalError("TupleVisual2 is a composite container")
    }

    public func renderLeaf(in context: inout VisualRenderContext) {
        first.render(in: &context)
        second.render(in: &context)
    }
}

extension TupleVisual2: VisualRepresentable {
    var visualNode: VisualNode {
        .group([first.flattenedNode(), second.flattenedNode()])
    }
}

public struct TupleVisual3<C0: Visual, C1: Visual, C2: Visual>: Visual {
    public let first: C0
    public let second: C1
    public let third: C2

    public init(_ first: C0, _ second: C1, _ third: C2) {
        self.first = first
        self.second = second
        self.third = third
    }

    public var body: Never {
        fatalError("TupleVisual3 is a composite container")
    }

    public func renderLeaf(in context: inout VisualRenderContext) {
        first.render(in: &context)
        second.render(in: &context)
        third.render(in: &context)
    }
}

extension TupleVisual3: VisualRepresentable {
    var visualNode: VisualNode {
        .group([first.flattenedNode(), second.flattenedNode(), third.flattenedNode()])
    }
}

public struct TupleVisual4<C0: Visual, C1: Visual, C2: Visual, C3: Visual>: Visual {
    public let first: C0
    public let second: C1
    public let third: C2
    public let fourth: C3

    public init(_ first: C0, _ second: C1, _ third: C2, _ fourth: C3) {
        self.first = first
        self.second = second
        self.third = third
        self.fourth = fourth
    }

    public var body: Never {
        fatalError("TupleVisual4 is a composite container")
    }

    public func renderLeaf(in context: inout VisualRenderContext) {
        first.render(in: &context)
        second.render(in: &context)
        third.render(in: &context)
        fourth.render(in: &context)
    }
}

extension TupleVisual4: VisualRepresentable {
    var visualNode: VisualNode {
        .group([
            first.flattenedNode(),
            second.flattenedNode(),
            third.flattenedNode(),
            fourth.flattenedNode(),
        ])
    }
}

public struct OptionalVisual<C: Visual>: Visual {
    public let content: C?

    public init(_ content: C?) {
        self.content = content
    }

    public var body: Never {
        fatalError("OptionalVisual is a composite container")
    }

    public func renderLeaf(in context: inout VisualRenderContext) {
        content?.render(in: &context)
    }
}

extension OptionalVisual: VisualRepresentable {
    var visualNode: VisualNode {
        content?.flattenedNode() ?? .empty
    }
}

public struct ConditionalVisual<T: Visual, F: Visual>: Visual {
    public enum Storage {
        case trueContent(T)
        case falseContent(F)
    }

    public let storage: Storage

    public init(storage: Storage) {
        self.storage = storage
    }

    public var body: Never {
        fatalError("ConditionalVisual is a composite container")
    }

    public func renderLeaf(in context: inout VisualRenderContext) {
        switch storage {
        case .trueContent(let content):
            content.render(in: &context)
        case .falseContent(let content):
            content.render(in: &context)
        }
    }
}

extension ConditionalVisual: VisualRepresentable {
    var visualNode: VisualNode {
        switch storage {
        case .trueContent(let content):
            return content.flattenedNode()
        case .falseContent(let content):
            return content.flattenedNode()
        }
    }
}

public struct ArrayVisual<C: Visual>: Visual {
    public let elements: [C]

    public init(_ elements: [C]) {
        self.elements = elements
    }

    public var body: Never {
        fatalError("ArrayVisual is a composite container")
    }

    public func renderLeaf(in context: inout VisualRenderContext) {
        for element in elements {
            element.render(in: &context)
        }
    }
}

extension ArrayVisual: VisualRepresentable {
    var visualNode: VisualNode {
        .group(elements.map { $0.flattenedNode() })
    }
}
