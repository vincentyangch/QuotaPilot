import Foundation

public struct DiscoveredLocalProfile: Identifiable, Equatable, Sendable {
    public let provider: QuotaProvider
    public let label: String
    public let email: String?
    public let plan: String?
    public let profileRootURL: URL
    public let credentialsURL: URL
    public let sourceDescription: String

    public init(
        provider: QuotaProvider,
        label: String,
        email: String?,
        plan: String?,
        profileRootURL: URL,
        credentialsURL: URL,
        sourceDescription: String
    ) {
        self.provider = provider
        self.label = label
        self.email = email
        self.plan = plan
        self.profileRootURL = profileRootURL
        self.credentialsURL = credentialsURL
        self.sourceDescription = sourceDescription
    }

    public var id: String {
        "\(self.provider.rawValue):\(self.profileRootURL.path)"
    }
}
