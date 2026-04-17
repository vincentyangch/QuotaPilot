import Foundation

public enum ProfileSourceCatalog {
    public static func makeCandidates(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        storedSources: [StoredProfileSource],
        preferredSelections: [QuotaProvider: String] = [:]
    ) -> [LocalProfileCandidate] {
        let ambientCandidates: [LocalProfileCandidate] = [
            .codex(
                profileRootURL: homeURL.appendingPathComponent(".codex", isDirectory: true),
                labelHint: "Codex Ambient",
                sourceDescription: "Ambient local profile",
                sourceKind: .ambient,
                ownershipMode: .externalLocal
            ),
            .claude(
                profileRootURL: homeURL.appendingPathComponent(".claude", isDirectory: true),
                labelHint: "Claude Ambient",
                sourceDescription: "Ambient local profile",
                sourceKind: .ambient,
                ownershipMode: .externalLocal
            ),
        ].filter { candidate in
            guard let preferredPath = preferredSelections[candidate.provider] else { return true }
            return URL(fileURLWithPath: preferredPath, isDirectory: true).standardizedFileURL.path
                == candidate.profileRootURL.standardizedFileURL.path
        }

        let storedCandidates: [LocalProfileCandidate] = storedSources.compactMap { source in
            guard source.isEnabled else { return nil }
            switch source.provider {
            case .codex:
                return .codex(
                    profileRootURL: source.profileRootURL,
                    labelHint: source.label,
                    sourceDescription: source.sourceKind == .backup ? "QuotaPilot backup profile" : "Stored profile source",
                    sourceKind: source.sourceKind,
                    ownershipMode: source.ownershipMode
                )
            case .claude:
                return .claude(
                    profileRootURL: source.profileRootURL,
                    labelHint: source.label,
                    sourceDescription: source.sourceKind == .backup ? "QuotaPilot backup profile" : "Stored profile source",
                    sourceKind: source.sourceKind,
                    ownershipMode: source.ownershipMode
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
