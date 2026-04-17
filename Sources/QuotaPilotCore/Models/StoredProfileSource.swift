import Foundation

public struct StoredProfileSource: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let provider: QuotaProvider
    public let label: String
    public let profileRootPath: String
    public let isEnabled: Bool
    public let addedAt: Date
    public let sourceKind: ProfileSourceKind
    public let ownershipMode: ProfileOwnershipMode

    public init(
        id: UUID,
        provider: QuotaProvider,
        label: String,
        profileRootPath: String,
        isEnabled: Bool,
        addedAt: Date,
        sourceKind: ProfileSourceKind = .stored,
        ownershipMode: ProfileOwnershipMode = .externalLocal
    ) {
        self.id = id
        self.provider = provider
        self.label = label
        self.profileRootPath = profileRootPath
        self.isEnabled = isEnabled
        self.addedAt = addedAt
        self.sourceKind = sourceKind
        self.ownershipMode = ownershipMode
    }

    public var profileRootURL: URL {
        URL(fileURLWithPath: self.profileRootPath, isDirectory: true)
    }

    public var sourceSummary: String {
        "\(self.sourceKind.displayLabel) • \(self.ownershipMode.displayLabel)"
    }
}

extension StoredProfileSource {
    enum CodingKeys: String, CodingKey {
        case id
        case provider
        case label
        case profileRootPath
        case isEnabled
        case addedAt
        case sourceKind
        case ownershipMode
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.provider = try container.decode(QuotaProvider.self, forKey: .provider)
        self.label = try container.decode(String.self, forKey: .label)
        self.profileRootPath = try container.decode(String.self, forKey: .profileRootPath)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.addedAt = try container.decode(Date.self, forKey: .addedAt)
        self.sourceKind = try container.decodeIfPresent(ProfileSourceKind.self, forKey: .sourceKind) ?? .stored
        self.ownershipMode = try container.decodeIfPresent(ProfileOwnershipMode.self, forKey: .ownershipMode) ?? .externalLocal
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.provider, forKey: .provider)
        try container.encode(self.label, forKey: .label)
        try container.encode(self.profileRootPath, forKey: .profileRootPath)
        try container.encode(self.isEnabled, forKey: .isEnabled)
        try container.encode(self.addedAt, forKey: .addedAt)
        try container.encode(self.sourceKind, forKey: .sourceKind)
        try container.encode(self.ownershipMode, forKey: .ownershipMode)
    }
}
