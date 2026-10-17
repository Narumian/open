import Foundation

@resultBuilder
public enum ViewBuilder {
    public static func buildExpression<V: View>(_ expression: V) -> V {
        expression
    }

    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    public static func buildBlock<C0: View>(_ c0: C0) -> C0 {
        c0
    }

    public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> TupleView2<C0, C1> {
        TupleView2(c0, c1)
    }

    public static func buildBlock<C0: View, C1: View, C2: View>(
        _ c0: C0, _ c1: C1, _ c2: C2
    ) -> TupleView3<C0, C1, C2> {
        TupleView3(c0, c1, c2)
    }

    public static func buildBlock<C0: View, C1: View, C2: View, C3: View>(
        _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3
    ) -> TupleView4<C0, C1, C2, C3> {
        TupleView4(c0, c1, c2, c3)
    }

    public static func buildOptional<C: View>(_ component: C?) -> OptionalView<C> {
        OptionalView(component)
    }

    public static func buildEither<C: View>(first: C) -> ConditionalView<C, EmptyView> {
        ConditionalView(storage: .trueContent(first))
    }

    public static func buildEither<C: View>(second: C) -> ConditionalView<EmptyView, C> {
        ConditionalView(storage: .falseContent(second))
    }

    public static func buildArray<C: View>(_ components: [C]) -> ArrayView<C> {
        ArrayView(components)
    }
}
