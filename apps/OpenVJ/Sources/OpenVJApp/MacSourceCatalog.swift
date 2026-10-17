import Foundation
import OpenUI
import OpenVJ

/// macOS source list: media folder scan + inter-app input discovery.
final class MacSourceCatalog: SourceCatalog {
    let selectionState: SourceSelectionState

    private let lock = NSLock()
    private var _sources: [ListedSource] = []

    init(selectionState: SourceSelectionState = .shared) {
        self.selectionState = selectionState
        if selectionState.mediaFolderURL == nil {
            selectionState.mediaFolderURL = Self.defaultMediaFolder()
        }
        refresh()
    }

    var sources: [any Source] {
        lock.lock()
        defer { lock.unlock() }
        return _sources
    }

    var mediaFolderURL: URL? {
        get { selectionState.mediaFolderURL }
        set {
            selectionState.mediaFolderURL = newValue
            refresh()
        }
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
            next.append(
                ListedSource(
                    displayName: url.lastPathComponent,
                    kind: .localFile(url)
                )
            )
        }

        for entry in InterAppTextureRegistry.Input.availableServers() {
            next.append(
                ListedSource(
                    displayName: entry.displayName,
                    kind: .interAppInput(serverName: entry.serverName)
                )
            )
        }

        lock.lock()
        _sources = next
        lock.unlock()
    }

    static func defaultMediaFolder() -> URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    private static func isVideoFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mov", "mp4", "m4v", "mkv", "avi", "webm"].contains(ext)
    }
}
