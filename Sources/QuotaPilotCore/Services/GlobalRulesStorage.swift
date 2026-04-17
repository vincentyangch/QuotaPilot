import Foundation

public struct GlobalRulesStorage {
    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "quotapilot.global-rules"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func load() -> GlobalRules {
        guard let data = self.userDefaults.data(forKey: self.key) else {
            return .default
        }

        do {
            return try JSONDecoder().decode(GlobalRules.self, from: data)
        } catch {
            return .default
        }
    }

    public func save(_ rules: GlobalRules) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        self.userDefaults.set(data, forKey: self.key)
    }
}
