import Foundation

/// Maps a catalog value to the declarative leaf that draws it.
public protocol Openable {
    associatedtype Opened: View
    @ViewBuilder func opened() -> Opened
}
