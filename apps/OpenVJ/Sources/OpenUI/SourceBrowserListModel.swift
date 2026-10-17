import Foundation

/// Shared source-browser row list (AppKit picker and headless CPU chrome).
public enum SourceBrowserListModel {
    public struct Row: Equatable, Sendable {
        public let title: String
        public let selection: SourceSelection

        public init(title: String, selection: SourceSelection) {
            self.title = title
            self.selection = selection
        }
    }

    public static func rows(from catalog: any SourceCatalog) -> [Row] {
        var next: [Row] = [
            Row(title: "— None (generative only) —", selection: .none),
        ]
        for entry in catalog.sources {
            next.append(
                Row(
                    title: displayName(for: entry.descriptor),
                    selection: .source(entry.descriptor)
                )
            )
        }
        if case .source(let descriptor) = catalog.selectionState.selection,
           case .interAppInput(let name) = descriptor.kind,
           !catalog.sources.contains(where: { $0.id == descriptor.id })
        {
            next.append(
                Row(
                    title: "◎ Inter-app (manual): \(name)",
                    selection: .source(descriptor)
                )
            )
        }
        return next
    }

    public static func selectedRowIndex(in rows: [Row], selection: SourceSelection) -> Int {
        rows.firstIndex(where: { $0.selection == selection }) ?? 0
    }

    public static func displayName(for descriptor: SourceDescriptor) -> String {
        switch descriptor.kind {
        case .localFile:
            return "📁 \(descriptor.displayName)"
        case .interAppInput:
            return "◎ Inter-app: \(descriptor.displayName)"
        case .url, .captureDevice:
            return descriptor.displayName
        }
    }
}
