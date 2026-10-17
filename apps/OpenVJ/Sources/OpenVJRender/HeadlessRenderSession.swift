import Foundation
import OpenUI

/// Registers a headless `SourceCatalog` when exporting the source-browser-mixer scene.
final class HeadlessRenderSession {
    let sourceCatalog: HeadlessSourceCatalog?

    init(sceneName: String?) {
        if Self.isSourceBrowserMixerScene(sceneName) {
            let catalog = HeadlessSourceCatalog()
            SourceCatalogRegistry.register(catalog)
            sourceCatalog = catalog
        } else {
            sourceCatalog = nil
        }
    }

    private static func isSourceBrowserMixerScene(_ name: String?) -> Bool {
        switch name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "source-browser-mixer", "source_browser_mixer":
            return true
        default:
            return false
        }
    }
}
