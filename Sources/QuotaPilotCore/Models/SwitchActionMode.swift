import Foundation

public enum SwitchActionMode: String, Codable, CaseIterable, Equatable, Sendable {
    case recommendOnly
    case autoActivateLocalProfiles

    public var displayName: String {
        switch self {
        case .recommendOnly:
            "Recommend Only"
        case .autoActivateLocalProfiles:
            "Auto-Activate Local Profiles"
        }
    }

    public var summary: String {
        switch self {
        case .recommendOnly:
            "QuotaPilot will refresh and recommend, but it will not switch accounts automatically."
        case .autoActivateLocalProfiles:
            "QuotaPilot will automatically activate a better supported local profile after refresh when it can verify a local handoff path."
        }
    }
}
