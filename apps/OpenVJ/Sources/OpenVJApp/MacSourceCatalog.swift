import Foundation
import OpenUI
import OpenVJ

/// macOS source list: media folder scan + inter-app input discovery.
final class MacSourceCatalog: SourceCatalog {
    let selectionState: SourceSelectionState

    private let lock = NSLock()
    private var _sources: [ListedSource] = []
    private var _mediaFolderURL: URL?

    init(selectionState: SourceSelectionState = .shared) {
        self.selectionState = selectionState
        _mediaFolderURL = selectionState.mediaFolderURL
        refresh()
    }

    var sources: [any Source] {
        lock.lock()
        defer { lock.unlock() }
        return _sources
    }

    var mediaFolderURL: URL? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _mediaFolderURL ?? selectionState.mediaFolderURL
        }
        set {
            lock.lock()
            _mediaFolderURL = newValue
            lock.unlock()
            selectionState.mediaFolderURL = newValue
            refresh()
        }
    }

    func refresh() {
        var next: [ListedSource] = []
        let folder = mediaFolderURL ?? Self.defaultMediaFolder()
        selectionState.mediaFolderURL = folder
        lock.lock()
        _mediaFolderURL = folder
        lock.unlock()

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
