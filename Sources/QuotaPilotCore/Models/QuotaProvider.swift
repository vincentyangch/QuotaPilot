import Foundation

public enum QuotaProvider: String, CaseIterable, Codable, Sendable {
    case codex
    case claude

    public var displayName: String {
        switch self {
        case .codex:
            "Codex"
        case .claude:
            "Claude"
        }
    }

    public var symbolName: String {
        switch self {
        case .codex:
            "bolt.horizontal.circle"
        case .claude:
            "brain.head.profile"
        }
    }
}
