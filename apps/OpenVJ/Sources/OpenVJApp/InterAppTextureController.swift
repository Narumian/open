import Foundation
import OpenVJ
#if canImport(OpenVJSyphon)
import OpenVJSyphon
#endif

/// Registers optional inter-app texture backends when the app shell starts rendering.
final class InterAppTextureController {
    func bootstrapIfNeeded() {
        #if canImport(OpenVJSyphon)
        openVJSyphonBootstrap()
        #endif
    }
}
