import Foundation

public enum ProfileSourceCatalog {
    public static func makeCandidates(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        storedSources: [StoredProfileSource]
    ) -> [LocalProfileCandidate] {
        let ambientCandidates: [LocalProfileCandidate] = [
            .codex(
                profileRootURL: homeURL.appendingPathComponent(".codex", isDirectory: true),
                labelHint: "Codex Ambient",
                sourceDescription: "Ambient local profile"
            ),
            .claude(
                profileRootURL: homeURL.appendingPathComponent(".claude", isDirectory: true),
                labelHint: "Claude Ambient",
                sourceDescription: "Ambient local profile"
            ),
        ]

        let storedCandidates: [LocalProfileCandidate] = storedSources.compactMap { source in
            guard source.isEnabled else { return nil }
            switch source.provider {
            case .codex:
                return .codex(
                    profileRootURL: source.profileRootURL,
                    labelHint: source.label,
                    sourceDescription: "Stored profile source"
                )
            case .claude:
                return .claude(
                    profileRootURL: source.profileRootURL,
                    labelHint: source.label,
                    sourceDescription: "Stored profile source"
                )
            }
        }

        var seen: Set<String> = []
        return (ambientCandidates + storedCandidates).filter { candidate in
            let key = "\(candidate.provider.rawValue):\(candidate.profileRootURL.standardizedFileURL.path)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
}
