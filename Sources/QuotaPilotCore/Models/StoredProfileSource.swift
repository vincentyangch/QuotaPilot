import Foundation

public struct StoredProfileSource: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let provider: QuotaProvider
    public let label: String
    public let profileRootPath: String
    public let isEnabled: Bool
    public let addedAt: Date

    public init(
        id: UUID,
        provider: QuotaProvider,
        label: String,
        profileRootPath: String,
        isEnabled: Bool,
        addedAt: Date
    ) {
        self.id = id
        self.provider = provider
        self.label = label
        self.profileRootPath = profileRootPath
        self.isEnabled = isEnabled
        self.addedAt = addedAt
    }

    public var profileRootURL: URL {
        URL(fileURLWithPath: self.profileRootPath, isDirectory: true)
    }
}
