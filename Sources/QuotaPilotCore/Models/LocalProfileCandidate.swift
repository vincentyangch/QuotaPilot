import Foundation

public struct LocalProfileCandidate: Equatable, Sendable {
    public let provider: QuotaProvider
    public let profileRootURL: URL
    public let credentialsURL: URL
    public let labelHint: String
    public let sourceDescription: String
    public let sourceKind: ProfileSourceKind
    public let ownershipMode: ProfileOwnershipMode

    public init(
        provider: QuotaProvider,
        profileRootURL: URL,
        credentialsURL: URL,
        labelHint: String,
        sourceDescription: String,
        sourceKind: ProfileSourceKind = .stored,
        ownershipMode: ProfileOwnershipMode = .externalLocal
    ) {
        self.provider = provider
        self.profileRootURL = profileRootURL
        self.credentialsURL = credentialsURL
        self.labelHint = labelHint
        self.sourceDescription = sourceDescription
        self.sourceKind = sourceKind
        self.ownershipMode = ownershipMode
    }
}

public extension LocalProfileCandidate {
    static func codex(
        profileRootURL: URL,
        labelHint: String,
        sourceDescription: String,
        sourceKind: ProfileSourceKind = .stored,
        ownershipMode: ProfileOwnershipMode = .externalLocal
    ) -> Self {
        LocalProfileCandidate(
            provider: .codex,
            profileRootURL: profileRootURL,
            credentialsURL: profileRootURL.appendingPathComponent("auth.json"),
            labelHint: labelHint,
            sourceDescription: sourceDescription,
            sourceKind: sourceKind,
            ownershipMode: ownershipMode
        )
    }

    static func claude(
        profileRootURL: URL,
        labelHint: String,
        sourceDescription: String,
        sourceKind: ProfileSourceKind = .stored,
        ownershipMode: ProfileOwnershipMode = .externalLocal
    ) -> Self {
        LocalProfileCandidate(
            provider: .claude,
            profileRootURL: profileRootURL,
            credentialsURL: profileRootURL.appendingPathComponent(".credentials.json"),
            labelHint: labelHint,
            sourceDescription: sourceDescription,
            sourceKind: sourceKind,
            ownershipMode: ownershipMode
        )
    }
}
