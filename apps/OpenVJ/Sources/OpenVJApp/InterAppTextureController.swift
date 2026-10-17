import Foundation
import OpenVJ
#if canImport(OpenVJSyphon)
import OpenVJSyphon
#endif

final class InterAppTextureController {
    weak var renderer: VisualRenderer?
    private var publisher: InterAppTexturePublisher?

    var isPublishing: Bool { publisher?.isEnabled ?? false }

    func bootstrapIfNeeded() {
        #if canImport(OpenVJSyphon)
        openVJSyphonBootstrap()
        #endif
        guard InterAppTextureSettings.syphonRequestedAtLaunch else { return }
        setPublishing(enabled: true)
    }

    func setPublishing(enabled: Bool) {
        InterAppTextureSettings.publishEnabled = enabled
        guard let renderer else { return }

        if enabled {
            #if canImport(OpenVJSyphon)
            if publisher == nil {
                publisher = InterAppTextureRegistry.makePublisher(configuration: .init(serverName: "OpenVJ", enabled: true))
            }
            publisher?.isEnabled = true
            renderer.setInterAppPublisher(publisher)
            #else
            fputs("[OpenVJ] Syphon publish requested but OpenVJSyphon is not linked. Run Scripts/fetch-syphon.sh and rebuild.\n", stderr)
            #endif
        } else {
            publisher?.isEnabled = false
            renderer.setInterAppPublisher(nil)
        }
    }
}
