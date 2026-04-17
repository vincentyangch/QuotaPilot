import Foundation

public struct UsageWindow: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let remainingPercent: Int
    public let resetsAt: Date

    public init(id: String, title: String, remainingPercent: Int, resetsAt: Date) {
        self.id = id
        self.title = title
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
    }

    public func hoursUntilReset(from now: Date = .now) -> Int {
        max(0, Int(ceil(self.resetsAt.timeIntervalSince(now) / 3600)))
    }
}
