import Foundation

public struct TupleView2<C0: View, C1: View>: View {
    public let first: C0
    public let second: C1

    public init(_ first: C0, _ second: C1) {
        self.first = first
        self.second = second
    }

    public var body: Never {
        fatalError("TupleView2 is a composite container")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        first.render(in: &context)
        second.render(in: &context)
    }
}

extension TupleView2: ViewRepresentable {
    var viewNode: ViewNode {
        .group([first.flattenedNode(), second.flattenedNode()])
    }
}

public struct TupleView3<C0: View, C1: View, C2: View>: View {
    public let first: C0
    public let second: C1
    public let third: C2

    public init(_ first: C0, _ second: C1, _ third: C2) {
        self.first = first
        self.second = second
        self.third = third
    }

    public var body: Never {
        fatalError("TupleView3 is a composite container")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        first.render(in: &context)
        second.render(in: &context)
        third.render(in: &context)
    }
}

extension TupleView3: ViewRepresentable {
    var viewNode: ViewNode {
        .group([first.flattenedNode(), second.flattenedNode(), third.flattenedNode()])
    }
}

public struct TupleView4<C0: View, C1: View, C2: View, C3: View>: View {
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
        fatalError("TupleView4 is a composite container")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        first.render(in: &context)
        second.render(in: &context)
        third.render(in: &context)
        fourth.render(in: &context)
    }
}

extension TupleView4: ViewRepresentable {
    var viewNode: ViewNode {
        .group([
            first.flattenedNode(),
            second.flattenedNode(),
            third.flattenedNode(),
            fourth.flattenedNode(),
        ])
    }
}

public struct OptionalView<C: View>: View {
    public let content: C?

    public init(_ content: C?) {
        self.content = content
    }

    public var body: Never {
        fatalError("OptionalView is a composite container")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        content?.render(in: &context)
    }
}

extension OptionalView: ViewRepresentable {
    var viewNode: ViewNode {
        content?.flattenedNode() ?? .empty
    }
}

public struct ConditionalView<T: View, F: View>: View {
    public enum Storage {
        case trueContent(T)
        case falseContent(F)
    }

    public let storage: Storage

    public init(storage: Storage) {
        self.storage = storage
    }

    public var body: Never {
        fatalError("ConditionalView is a composite container")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        switch storage {
        case .trueContent(let content):
            content.render(in: &context)
        case .falseContent(let content):
            content.render(in: &context)
        }
    }
}

extension ConditionalView: ViewRepresentable {
    var viewNode: ViewNode {
        switch storage {
        case .trueContent(let content):
            return content.flattenedNode()
        case .falseContent(let content):
            return content.flattenedNode()
        }
    }
}

public struct ArrayView<C: View>: View {
    public let elements: [C]

    public init(_ elements: [C]) {
        self.elements = elements
    }

    public var body: Never {
        fatalError("ArrayView is a composite container")
    }

    public func renderLeaf(in context: inout ViewRenderContext) {
        for element in elements {
            element.render(in: &context)
        }
    }
}

extension ArrayView: ViewRepresentable {
    var viewNode: ViewNode {
        .group(elements.map { $0.flattenedNode() })
    }
}
