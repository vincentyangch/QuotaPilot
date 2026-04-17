import Foundation

public struct RecommendationAlertSettingsStorage {
    private let key: String
    private let userDefaults: UserDefaults

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "quotapilot.recommendation-alert-settings"
    ) {
        self.key = key
        self.userDefaults = userDefaults
    }

    public func load() -> RecommendationAlertSettings {
        guard let data = self.userDefaults.data(forKey: self.key),
              let settings = try? JSONDecoder().decode(RecommendationAlertSettings.self, from: data)
        else {
            return .default
        }

        return settings
    }

    public func save(_ settings: RecommendationAlertSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.userDefaults.set(data, forKey: self.key)
    }
}
