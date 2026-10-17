import Foundation

@resultBuilder
public enum VisualBuilder {
    public static func buildExpression<V: Visual>(_ expression: V) -> V {
        expression
    }

    public static func buildBlock() -> EmptyVisual {
        EmptyVisual()
    }

    public static func buildBlock<C0: Visual>(_ c0: C0) -> C0 {
        c0
    }

    public static func buildBlock<C0: Visual, C1: Visual>(_ c0: C0, _ c1: C1) -> TupleVisual2<C0, C1> {
        TupleVisual2(c0, c1)
    }

    public static func buildBlock<C0: Visual, C1: Visual, C2: Visual>(
        _ c0: C0, _ c1: C1, _ c2: C2
    ) -> TupleVisual3<C0, C1, C2> {
        TupleVisual3(c0, c1, c2)
    }

    public static func buildBlock<C0: Visual, C1: Visual, C2: Visual, C3: Visual>(
        _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3
    ) -> TupleVisual4<C0, C1, C2, C3> {
        TupleVisual4(c0, c1, c2, c3)
    }

    public static func buildOptional<C: Visual>(_ component: C?) -> OptionalVisual<C> {
        OptionalVisual(component)
    }

    public static func buildEither<C: Visual>(first: C) -> ConditionalVisual<C, EmptyVisual> {
        ConditionalVisual(storage: .trueContent(first))
    }

    public static func buildEither<C: Visual>(second: C) -> ConditionalVisual<EmptyVisual, C> {
        ConditionalVisual(storage: .falseContent(second))
    }

    public static func buildArray<C: Visual>(_ components: [C]) -> ArrayVisual<C> {
        ArrayVisual(components)
    }
}
