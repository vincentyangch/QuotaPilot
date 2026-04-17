import Foundation

public enum TrackedProfileInventoryBuilder {
    public static func makeItems(
        discoveredProfiles: [DiscoveredLocalProfile],
        liveAccounts: [QuotaAccount],
        failures: [AmbientUsageRefreshFailure] = [],
        now: Date = .now,
        currentProfileRootPaths: [QuotaProvider: String]
    ) -> [TrackedProfileInventoryItem] {
        discoveredProfiles.map { profile in
            let standardizedProfilePath = profile.profileRootURL.standardizedFileURL.path
            let liveAccount = liveAccounts.first {
                $0.provider == profile.provider
                    && $0.profileRootPath.map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL.path } == standardizedProfilePath
            }
            let matchingFailure = failures.first {
                $0.provider == profile.provider
                    && $0.profileRootPath == standardizedProfilePath
            }
            let lifecycleStatus = TrackedProfileLifecycleStatusBuilder.makeStatus(
                liveAccount: liveAccount,
                failure: matchingFailure
            )
            let liveRemainingPercent = liveAccount?.primaryRemainingPercent
            let statusSummary = liveRemainingPercent.map { "\($0)% remaining" } ?? "Awaiting live refresh"
            let lastRefreshSummary = liveAccount?.lastSuccessfulRefreshAt.map {
                self.relativeRefreshText(from: $0, now: now)
            }
            let effectiveSourceKind = liveAccount?.sourceKind ?? profile.sourceKind
            let effectiveOwnershipMode = liveAccount?.ownershipMode ?? profile.ownershipMode
            let capabilitySummary = self.capabilitySummary(
                liveAccount: liveAccount,
                lifecycleState: lifecycleStatus.state,
                sourceKind: effectiveSourceKind,
                ownershipMode: effectiveOwnershipMode
            )
            let recoveryBackupCandidate = self.recoveryBackupCandidate(
                for: profile,
                lifecycleState: lifecycleStatus.state,
                discoveredProfiles: discoveredProfiles,
                liveAccounts: liveAccounts,
                failures: failures,
                currentProfileRootPaths: currentProfileRootPaths
            )

            return TrackedProfileInventoryItem(
                provider: profile.provider,
                label: profile.label,
                email: profile.email,
                plan: profile.plan,
                identitySummary: liveAccount?.identitySummary ?? self.identitySummary(
                    email: profile.email,
                    plan: profile.plan,
                    organizationLabel: profile.organizationLabel,
                    workspaceLabel: profile.workspaceLabel
                ),
                profileRootPath: standardizedProfilePath,
                sourceDescription: profile.sourceDescription,
                sourceKind: effectiveSourceKind,
                ownershipMode: effectiveOwnershipMode,
                sourceSummary: self.sourceSummary(
                    sourceKind: effectiveSourceKind,
                    ownershipMode: effectiveOwnershipMode
                ),
                isCurrentSelection: currentProfileRootPaths[profile.provider] == standardizedProfilePath,
                hasLiveUsage: liveAccount != nil,
                liveRemainingPercent: liveRemainingPercent,
                lifecycleState: lifecycleStatus.state,
                lifecycleTitle: lifecycleStatus.title,
                lifecycleDetail: lifecycleStatus.detail,
                lifecycleNextAction: lifecycleStatus.nextAction,
                capabilitySummary: capabilitySummary,
                lastRefreshSummary: lastRefreshSummary,
                lastErrorDetail: matchingFailure?.detail,
                statusSummary: statusSummary,
                recoveryActionTargetProfileRootPath: recoveryBackupCandidate?.profileRootURL.standardizedFileURL.path,
                recoveryActionBackupLabel: recoveryBackupCandidate?.label
            )
        }
    }

    private static func recoveryBackupCandidate(
        for profile: DiscoveredLocalProfile,
        lifecycleState: TrackedProfileLifecycleState,
        discoveredProfiles: [DiscoveredLocalProfile],
        liveAccounts: [QuotaAccount],
        failures: [AmbientUsageRefreshFailure],
        currentProfileRootPaths: [QuotaProvider: String]
    ) -> DiscoveredLocalProfile? {
        guard currentProfileRootPaths[profile.provider] == profile.profileRootURL.standardizedFileURL.path else {
            return nil
        }

        switch lifecycleState {
        case .credentialsMissing, .authExpired, .sessionUnavailable, .usageReadFailed:
            break
        case .awaitingRefresh, .ready:
            return nil
        }

        return discoveredProfiles
            .filter { candidate in
                candidate.provider == profile.provider
                    && candidate.sourceKind == .backup
                    && candidate.ownershipMode == .quotaPilotManaged
                    && candidate.profileRootURL.standardizedFileURL.path != profile.profileRootURL.standardizedFileURL.path
                    && !failures.contains(where: {
                        $0.provider == candidate.provider
                            && $0.profileRootPath == candidate.profileRootURL.standardizedFileURL.path
                    })
            }
            .sorted { lhs, rhs in
                let lhsHasLiveUsage = liveAccounts.contains {
                    $0.provider == lhs.provider
                        && $0.profileRootPath == lhs.profileRootURL.standardizedFileURL.path
                }
                let rhsHasLiveUsage = liveAccounts.contains {
                    $0.provider == rhs.provider
                        && $0.profileRootPath == rhs.profileRootURL.standardizedFileURL.path
                }
                if lhsHasLiveUsage != rhsHasLiveUsage {
                    return lhsHasLiveUsage && !rhsHasLiveUsage
                }
                return lhs.label < rhs.label
            }
            .first
    }

    private static func identitySummary(
        email: String?,
        plan: String?,
        organizationLabel: String?,
        workspaceLabel: String?
    ) -> String? {
        let parts = [
            email,
            plan?.uppercased(),
            workspaceLabel ?? organizationLabel,
        ].compactMap { value in
            value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
    }

    private static func capabilitySummary(
        liveAccount: QuotaAccount?,
        lifecycleState: TrackedProfileLifecycleState,
        sourceKind: ProfileSourceKind,
        ownershipMode: ProfileOwnershipMode
    ) -> String {
        if let liveAccount {
            return self.capabilitySummary(for: liveAccount.capabilities)
        }

        switch lifecycleState {
        case .awaitingRefresh:
            var labels: [String] = []
            if sourceKind == .stored || sourceKind == .backup || ownershipMode == .quotaPilotManaged {
                labels.append("Auto-Switch")
            }
            labels.append("Desktop Handoff")
            return labels.joined(separator: ", ")
        case .ready:
            return self.capabilitySummary(for: .localProfile)
        case .credentialsMissing, .authExpired, .sessionUnavailable, .usageReadFailed:
            return "Desktop Handoff"
        }
    }

    private static func capabilitySummary(for capabilities: QuotaAccountCapabilities) -> String {
        var labels: [String] = []
        if capabilities.canReadUsage {
            labels.append("Usage")
        }
        if capabilities.canRecommend {
            labels.append("Recommend")
        }
        if capabilities.canAutoActivateLocalProfile {
            labels.append("Auto-Switch")
        }
        if capabilities.canGuideDesktopHandoff {
            labels.append("Desktop Handoff")
        }
        return labels.joined(separator: ", ")
    }

    private static func sourceSummary(
        sourceKind: ProfileSourceKind,
        ownershipMode: ProfileOwnershipMode
    ) -> String {
        "\(sourceKind.displayLabel) • \(ownershipMode.displayLabel)"
    }

    private static func relativeRefreshText(from refreshedAt: Date, now: Date) -> String {
        let elapsedMinutes = max(0, Int(now.timeIntervalSince(refreshedAt) / 60.0))
        if elapsedMinutes < 1 {
            return "Updated just now"
        }
        if elapsedMinutes == 1 {
            return "Updated 1 min ago"
        }
        return "Updated \(elapsedMinutes) min ago"
    }
}
