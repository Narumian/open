import Foundation

/// Named VJ decks (e.g. `SourceBrowser(deck: "A")`) with independent selection state.
public enum SourceDeckRegistry {
    private static let lock = NSLock()
    private static var states: [String: SourceSelectionState] = [:]

    public static func selectionState(for deckID: String) -> SourceSelectionState {
        lock.lock()
        defer { lock.unlock() }
        if let existing = states[deckID] {
            return existing
        }
        let created = SourceSelectionState()
        states[deckID] = created
        return created
    }

    /// Removes all deck states (tests / scene teardown).
    public static func reset() {
        lock.lock()
        states.removeAll()
        lock.unlock()
    }
}
