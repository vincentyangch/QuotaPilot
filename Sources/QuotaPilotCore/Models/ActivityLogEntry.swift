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

public struct ActivityLogProfileReference: Codable, Equatable, Sendable {
    public let label: String
    public let profileRootPath: String

    public init(label: String, profileRootPath: String) {
        self.label = label
        self.profileRootPath = profileRootPath
    }
}

public struct ActivityLogRestoreProvenance: Codable, Equatable, Sendable {
    public let sourceProfile: ActivityLogProfileReference
    public let replacedProfile: ActivityLogProfileReference?

    public init(
        sourceProfile: ActivityLogProfileReference,
        replacedProfile: ActivityLogProfileReference?
    ) {
        self.sourceProfile = sourceProfile
        self.replacedProfile = replacedProfile
    }
}

public struct ActivityLogEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: ActivityLogKind
    public let provider: QuotaProvider?
    public let title: String
    public let detail: String
    public let restoreProvenance: ActivityLogRestoreProvenance?

    public init(
        id: UUID,
        timestamp: Date,
        kind: ActivityLogKind,
        provider: QuotaProvider?,
        title: String,
        detail: String,
        restoreProvenance: ActivityLogRestoreProvenance? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.provider = provider
        self.title = title
        self.detail = detail
        self.restoreProvenance = restoreProvenance
    }

    public var isBackupRestore: Bool {
        self.restoreProvenance != nil
            || (self.kind == .activationSucceeded && self.title == "Restored backup")
    }
}
