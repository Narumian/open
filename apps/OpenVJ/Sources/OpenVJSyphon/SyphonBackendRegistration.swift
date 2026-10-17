import Foundation
import OpenVJ

public enum SyphonBackendRegistration {
    private static var didRegisterPublisher = false
    private static var didRegisterSubscriber = false
    private static var didRegisterDiscovery = false
    private static var announceObserver: NSObjectProtocol?

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
        if !didRegisterDiscovery {
            InterAppTextureRegistry.registerInputServerDiscovery {
                SyphonServerListing.inputServers()
            }
            let center = NotificationCenter.default
            announceObserver = center.addObserver(
                forName: NSNotification.Name.SyphonServerAnnounce,
                object: nil,
                queue: .main
            ) { _ in
                InterAppTextureRegistry.notifyInputServersDidChange()
            }
            didRegisterDiscovery = true
        }
    }
}

public func openVJSyphonBootstrap() {
    SyphonBackendRegistration.registerIfNeeded()
}
