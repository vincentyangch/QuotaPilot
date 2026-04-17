import Foundation

public enum DemoAccountRepository {
    public static func makeAccounts(now: Date = .now) -> [QuotaAccount] {
        let makeResetDate: (Int) -> Date = { now.addingTimeInterval(Double($0) * 3600) }

        return [
            QuotaAccount(
                id: UUID(uuidString: "4E86D898-7D59-4B41-A28F-B4AF0F36A001") ?? UUID(),
                provider: .codex,
                label: "Codex Personal",
                priority: 75,
                isCurrent: true,
                windows: [
                    UsageWindow(id: "session", title: "Session", remainingPercent: 58, resetsAt: makeResetDate(2)),
                    UsageWindow(id: "weekly", title: "Weekly", remainingPercent: 41, resetsAt: makeResetDate(50)),
                ]
            ),
            QuotaAccount(
                id: UUID(uuidString: "4E86D898-7D59-4B41-A28F-B4AF0F36A002") ?? UUID(),
                provider: .codex,
                label: "Codex Work",
                priority: 60,
                isCurrent: false,
                windows: [
                    UsageWindow(id: "session", title: "Session", remainingPercent: 14, resetsAt: makeResetDate(5)),
                    UsageWindow(id: "weekly", title: "Weekly", remainingPercent: 22, resetsAt: makeResetDate(54)),
                ]
            ),
            QuotaAccount(
                id: UUID(uuidString: "4E86D898-7D59-4B41-A28F-B4AF0F36A003") ?? UUID(),
                provider: .claude,
                label: "Claude Max",
                priority: 85,
                isCurrent: false,
                windows: [
                    UsageWindow(id: "weekly", title: "Weekly", remainingPercent: 73, resetsAt: makeResetDate(1)),
                ]
            ),
            QuotaAccount(
                id: UUID(uuidString: "4E86D898-7D59-4B41-A28F-B4AF0F36A004") ?? UUID(),
                provider: .claude,
                label: "Claude Team",
                priority: 65,
                isCurrent: true,
                windows: [
                    UsageWindow(id: "weekly", title: "Weekly", remainingPercent: 32, resetsAt: makeResetDate(6)),
                ]
            ),
        ]
    }
}
