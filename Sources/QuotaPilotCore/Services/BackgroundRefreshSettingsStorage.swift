import Foundation

public struct BackgroundRefreshSettingsStorage {
    private let key: String
    private let userDefaults: UserDefaults

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "quotapilot.background-refresh-settings"
    ) {
        self.key = key
        self.userDefaults = userDefaults
    }

    public func load() -> BackgroundRefreshSettings {
        guard let data = self.userDefaults.data(forKey: self.key),
              let settings = try? JSONDecoder().decode(BackgroundRefreshSettings.self, from: data)
        else {
            return .default
        }

        return settings
    }

    public func save(_ settings: BackgroundRefreshSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        self.userDefaults.set(data, forKey: self.key)
    }
}
