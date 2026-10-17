import Foundation
import OpenUI

/// macOS media scan for headless `OpenVJRender` (no `OpenVJApp` shell).
final class HeadlessSourceCatalog: SourceCatalog {
    let selectionState: SourceSelectionState

    private let lock = NSLock()
    private var listed: [ListedSource] = []

    init(selectionState: SourceSelectionState = .shared) {
        self.selectionState = selectionState
        if selectionState.mediaFolderURL == nil {
            selectionState.mediaFolderURL = Self.defaultMediaFolder()
        }
        refresh()
        if selectionState.selection == .none, let first = listed.first {
            selectionState.selection = .source(first.descriptor)
        }
    }

    var sources: [any Source] {
        lock.lock()
        defer { lock.unlock() }
        return listed
    }

    func refresh() {
        let folder = selectionState.mediaFolderURL ?? Self.defaultMediaFolder()
        selectionState.mediaFolderURL = folder

        var next: [ListedSource] = []
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let videos = urls.filter { Self.isVideoFile($0) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in videos {
            next.append(ListedSource(displayName: url.lastPathComponent, kind: .localFile(url)))
        }

        if next.isEmpty {
            next.append(
                ListedSource(
                    displayName: "Demo Clip (placeholder)",
                    kind: .localFile(URL(fileURLWithPath: "/Movies/demo.mov"))
                )
            )
            next.append(
                ListedSource(
                    displayName: "Syphon Server (placeholder)",
                    kind: .interAppInput(serverName: "Demo Syphon")
                )
            )
        }

        lock.lock()
        listed = next
        lock.unlock()
    }

    private static func defaultMediaFolder() -> URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    private static func isVideoFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mov", "mp4", "m4v", "mkv", "avi", "webm"].contains(ext)
    }
}
