import Foundation

/// Transparent container — `body` forwards to builder content.
public struct GroupView<Content: View>: View {
    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Content { content }
}
