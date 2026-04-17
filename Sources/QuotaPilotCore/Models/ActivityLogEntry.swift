import Foundation

public enum ActivityLogKind: String, Codable, Equatable, Sendable {
    case refreshSucceeded
    case refreshFailed
    case alertSent
    case confirmationQueued
    case confirmationApproved
    case confirmationDismissed
    case activationSucceeded
    case activationFailed
    case autoActivationQueued
    case verificationFailed
}

public struct ActivityLogEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: ActivityLogKind
    public let provider: QuotaProvider?
    public let title: String
    public let detail: String

    public init(
        id: UUID,
        timestamp: Date,
        kind: ActivityLogKind,
        provider: QuotaProvider?,
        title: String,
        detail: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.provider = provider
        self.title = title
        self.detail = detail
    }
}
