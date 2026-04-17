import Foundation

public struct QuotaAccount: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let provider: QuotaProvider
    public let label: String
    public let priority: Int
    public let isCurrent: Bool
    public let windows: [UsageWindow]

    public init(
        id: UUID,
        provider: QuotaProvider,
        label: String,
        priority: Int,
        isCurrent: Bool,
        windows: [UsageWindow]
    ) {
        self.id = id
        self.provider = provider
        self.label = label
        self.priority = priority
        self.isCurrent = isCurrent
        self.windows = windows
    }

    public var primaryWindow: UsageWindow? {
        self.windows.first
    }

    public var primaryRemainingPercent: Int {
        self.primaryWindow?.remainingPercent ?? 0
    }

    public func primaryResetHours(from now: Date = .now) -> Int {
        self.primaryWindow?.hoursUntilReset(from: now) ?? Int.max
    }
}

public extension QuotaAccount {
    static func codex(
        label: String,
        remainingPercent: Int,
        resetHours: Int,
        priority: Int,
        isCurrent: Bool
    ) -> Self {
        QuotaAccount(
            id: UUID(),
            provider: .codex,
            label: label,
            priority: priority,
            isCurrent: isCurrent,
            windows: [
                UsageWindow(
                    id: "session",
                    title: "Session",
                    remainingPercent: remainingPercent,
                    resetsAt: .now.addingTimeInterval(Double(resetHours) * 3600)
                ),
                UsageWindow(
                    id: "weekly",
                    title: "Weekly",
                    remainingPercent: max(remainingPercent - 10, 0),
                    resetsAt: .now.addingTimeInterval(Double(resetHours + 48) * 3600)
                ),
            ]
        )
    }

    static func claude(
        label: String,
        remainingPercent: Int,
        resetHours: Int,
        priority: Int,
        isCurrent: Bool
    ) -> Self {
        QuotaAccount(
            id: UUID(),
            provider: .claude,
            label: label,
            priority: priority,
            isCurrent: isCurrent,
            windows: [
                UsageWindow(
                    id: "weekly",
                    title: "Weekly",
                    remainingPercent: remainingPercent,
                    resetsAt: .now.addingTimeInterval(Double(resetHours) * 3600)
                ),
            ]
        )
    }
}
