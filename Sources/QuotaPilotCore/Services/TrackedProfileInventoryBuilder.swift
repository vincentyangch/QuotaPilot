import Foundation

public enum TrackedProfileInventoryBuilder {
    public static func makeItems(
        discoveredProfiles: [DiscoveredLocalProfile],
        liveAccounts: [QuotaAccount],
        currentProfileRootPaths: [QuotaProvider: String]
    ) -> [TrackedProfileInventoryItem] {
        discoveredProfiles.map { profile in
            let standardizedProfilePath = profile.profileRootURL.standardizedFileURL.path
            let liveAccount = liveAccounts.first {
                $0.provider == profile.provider
                    && $0.profileRootPath.map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL.path } == standardizedProfilePath
            }
            let liveRemainingPercent = liveAccount?.primaryRemainingPercent
            let statusSummary = liveRemainingPercent.map { "\($0)% remaining" } ?? "Awaiting live refresh"

            return TrackedProfileInventoryItem(
                provider: profile.provider,
                label: profile.label,
                email: profile.email,
                plan: profile.plan,
                profileRootPath: standardizedProfilePath,
                sourceDescription: profile.sourceDescription,
                isCurrentSelection: currentProfileRootPaths[profile.provider] == standardizedProfilePath,
                hasLiveUsage: liveAccount != nil,
                liveRemainingPercent: liveRemainingPercent,
                statusSummary: statusSummary
            )
        }
    }
}
