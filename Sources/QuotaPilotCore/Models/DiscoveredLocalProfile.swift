import Foundation

public struct DiscoveredLocalProfile: Identifiable, Equatable, Sendable {
    public let provider: QuotaProvider
    public let label: String
    public let email: String?
    public let plan: String?
    public let profileRootURL: URL
    public let credentialsURL: URL
    public let sourceDescription: String
    public let sourceKind: ProfileSourceKind
    public let ownershipMode: ProfileOwnershipMode

    public init(
        provider: QuotaProvider,
        label: String,
        email: String?,
        plan: String?,
        profileRootURL: URL,
        credentialsURL: URL,
        sourceDescription: String,
        sourceKind: ProfileSourceKind = .stored,
        ownershipMode: ProfileOwnershipMode = .externalLocal
    ) {
        self.provider = provider
        self.label = label
        self.email = email
        self.plan = plan
        self.profileRootURL = profileRootURL
        self.credentialsURL = credentialsURL
        self.sourceDescription = sourceDescription
        self.sourceKind = sourceKind
        self.ownershipMode = ownershipMode
    }

    public var id: String {
        "\(self.provider.rawValue):\(self.profileRootURL.path)"
    }
}
