import Foundation

public struct RecommendationAlertSettings: Codable, Equatable, Sendable {
    public let isEnabled: Bool

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    public static let `default` = RecommendationAlertSettings(isEnabled: false)
}
