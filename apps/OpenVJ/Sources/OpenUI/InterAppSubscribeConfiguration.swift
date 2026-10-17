import Foundation

/// Backend-neutral configuration for inter-app texture subscribe during tree walk.
public struct InterAppSubscribeConfiguration: Sendable {
    public var serverName: String

    public init(serverName: String) {
        self.serverName = serverName
    }
}
