import Foundation
import OpenVJ

public enum SyphonBackendRegistration {
    private static var didRegisterPublisher = false
    private static var didRegisterSubscriber = false

    public static func registerIfNeeded() {
        if !didRegisterPublisher {
            InterAppTextureRegistry.registerPublisherFactory { configuration in
                SyphonInterAppTexturePublisher(configuration: configuration)
            }
            didRegisterPublisher = true
        }
        if !didRegisterSubscriber {
            InterAppTextureRegistry.registerSubscriberFactory { configuration in
                SyphonInterAppTextureSubscriber(configuration: configuration)
            }
            didRegisterSubscriber = true
        }
    }
}

public func openVJSyphonBootstrap() {
    SyphonBackendRegistration.registerIfNeeded()
}
