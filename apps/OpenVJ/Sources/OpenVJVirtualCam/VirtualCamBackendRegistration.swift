import Foundation
import OpenVJ

public enum VirtualCamBackendRegistration {
    public static func registerIfNeeded() {
        guard !VirtualCameraRegistry.isBackendRegistered else { return }
        VirtualCameraRegistry.registerPublisherFactory { configuration in
            StubVirtualCameraPublisher(configuration: configuration)
        }
    }
}

public func openVJVirtualCamBootstrap() {
    VirtualCamBackendRegistration.registerIfNeeded()
}
