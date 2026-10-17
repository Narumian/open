import Foundation
import OpenVJ

public enum SyphonBackendRegistration {
    public static func registerIfNeeded() {
        guard !InterAppTextureRegistry.isBackendRegistered else { return }
        InterAppTextureRegistry.registerPublisherFactory { configuration in
            SyphonInterAppTexturePublisher(configuration: configuration)
        }
    }
}

public func openVJSyphonBootstrap() {
    SyphonBackendRegistration.registerIfNeeded()
}
