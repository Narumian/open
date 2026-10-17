import Foundation

/// Transparent container (like SwiftUI `Group`) — `body` forwards to builder content.
public struct GroupVisual<Content: Visual>: Visual {
    public let content: Content

    public init(@VisualBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Content { content }
}
