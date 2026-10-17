import Foundation
import OpenVJ

public enum SyphonBackendRegistration {
    public static func registerIfNeeded() {
        guard !InterAppTexture.isBackendRegistered else { return }
        InterAppTexture.registerPublisherFactory { configuration in
            SyphonInterAppTexturePublisher(configuration: configuration)
        }
    }
}

public func openVJSyphonBootstrap() {
    SyphonBackendRegistration.registerIfNeeded()
}
