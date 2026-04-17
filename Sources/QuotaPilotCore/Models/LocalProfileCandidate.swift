import Foundation

public struct LocalProfileCandidate: Equatable, Sendable {
    public let provider: QuotaProvider
    public let profileRootURL: URL
    public let credentialsURL: URL
    public let labelHint: String
    public let sourceDescription: String

    public init(
        provider: QuotaProvider,
        profileRootURL: URL,
        credentialsURL: URL,
        labelHint: String,
        sourceDescription: String
    ) {
        self.provider = provider
        self.profileRootURL = profileRootURL
        self.credentialsURL = credentialsURL
        self.labelHint = labelHint
        self.sourceDescription = sourceDescription
    }
}

public extension LocalProfileCandidate {
    static func codex(
        profileRootURL: URL,
        labelHint: String,
        sourceDescription: String
    ) -> Self {
        LocalProfileCandidate(
            provider: .codex,
            profileRootURL: profileRootURL,
            credentialsURL: profileRootURL.appendingPathComponent("auth.json"),
            labelHint: labelHint,
            sourceDescription: sourceDescription
        )
    }

    static func claude(
        profileRootURL: URL,
        labelHint: String,
        sourceDescription: String
    ) -> Self {
        LocalProfileCandidate(
            provider: .claude,
            profileRootURL: profileRootURL,
            credentialsURL: profileRootURL.appendingPathComponent(".credentials.json"),
            labelHint: labelHint,
            sourceDescription: sourceDescription
        )
    }
}
