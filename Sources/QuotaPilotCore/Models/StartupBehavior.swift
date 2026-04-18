import Foundation

public struct StartupBehavior: Codable, Equatable, Sendable {
    public let opensDashboardOnLaunch: Bool

    public init(opensDashboardOnLaunch: Bool) {
        self.opensDashboardOnLaunch = opensDashboardOnLaunch
    }

    public static let `default` = StartupBehavior(opensDashboardOnLaunch: true)
}
