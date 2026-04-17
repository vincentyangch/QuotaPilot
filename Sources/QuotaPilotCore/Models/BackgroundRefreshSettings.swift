import Foundation

public struct BackgroundRefreshSettings: Codable, Equatable, Sendable {
    public let isEnabled: Bool
    public let intervalMinutes: Int

    public init(isEnabled: Bool, intervalMinutes: Int) {
        self.isEnabled = isEnabled
        self.intervalMinutes = max(1, intervalMinutes)
    }

    public static let `default` = BackgroundRefreshSettings(isEnabled: true, intervalMinutes: 5)
}
