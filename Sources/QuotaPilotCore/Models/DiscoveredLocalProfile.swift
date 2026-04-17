import Foundation

public struct DiscoveredLocalProfile: Identifiable, Equatable, Sendable {
    public let provider: QuotaProvider
    public let label: String
    public let email: String?
    public let plan: String?
    public let organizationLabel: String?
    public let workspaceLabel: String?
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
        organizationLabel: String? = nil,
        workspaceLabel: String? = nil,
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
        self.organizationLabel = organizationLabel
        self.workspaceLabel = workspaceLabel
        self.profileRootURL = profileRootURL
        self.credentialsURL = credentialsURL
        self.sourceDescription = sourceDescription
        self.sourceKind = sourceKind
        self.ownershipMode = ownershipMode
    }

    public var id: String {
        "\(self.provider.rawValue):\(self.profileRootURL.path)"
    }

    public var identitySummary: String? {
        let parts = [
            self.email,
            self.plan?.uppercased(),
            self.workspaceLabel ?? self.organizationLabel,
        ].compactMap { value in
            value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
    }

    public var sourceSummary: String {
        "\(self.sourceKind.displayLabel) • \(self.ownershipMode.displayLabel)"
    }
}
