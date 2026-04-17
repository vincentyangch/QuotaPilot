import Foundation

public struct SwitchActionModeStorage {
    private let key: String
    private let userDefaults: UserDefaults

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "quotapilot.switch-action-mode"
    ) {
        self.key = key
        self.userDefaults = userDefaults
    }

    public func load() -> SwitchActionMode {
        guard let rawValue = self.userDefaults.string(forKey: self.key),
              let mode = SwitchActionMode(rawValue: rawValue)
        else {
            return .recommendOnly
        }

        return mode
    }

    public func save(_ mode: SwitchActionMode) {
        self.userDefaults.set(mode.rawValue, forKey: self.key)
    }
}
