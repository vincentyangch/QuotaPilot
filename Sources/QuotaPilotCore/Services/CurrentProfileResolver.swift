import Foundation

public enum CurrentProfileResolver {
    public static func resolve(
        discoveredProfiles: [DiscoveredLocalProfile],
        preferredSelections: [QuotaProvider: String]
    ) -> [QuotaProvider: String] {
        var result: [QuotaProvider: String] = [:]

        for provider in QuotaProvider.allCases {
            let providerProfiles = discoveredProfiles.filter { $0.provider == provider }
            guard !providerProfiles.isEmpty else { continue }

            if let preferredPath = preferredSelections[provider],
               providerProfiles.contains(where: {
                   $0.profileRootURL.standardizedFileURL.path == URL(fileURLWithPath: preferredPath, isDirectory: true).standardizedFileURL.path
               })
            {
                result[provider] = URL(fileURLWithPath: preferredPath, isDirectory: true).standardizedFileURL.path
            } else {
                result[provider] = providerProfiles[0].profileRootURL.standardizedFileURL.path
            }
        }

        return result
    }
}
