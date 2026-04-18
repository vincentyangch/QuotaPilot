import Foundation

public struct StartupBehaviorStorage {
    private let key: String
    private let userDefaults: UserDefaults

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "quotapilot.startup-behavior"
    ) {
        self.key = key
        self.userDefaults = userDefaults
    }

    public func load() -> StartupBehavior {
        guard let data = self.userDefaults.data(forKey: self.key),
              let behavior = try? JSONDecoder().decode(StartupBehavior.self, from: data)
        else {
            return .default
        }

        return behavior
    }

    public func save(_ behavior: StartupBehavior) {
        guard let data = try? JSONEncoder().encode(behavior) else { return }
        self.userDefaults.set(data, forKey: self.key)
    }
}
