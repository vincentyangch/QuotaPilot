import XCTest
@testable import QuotaPilot
import QuotaPilotCore

@MainActor
final class AppModelRecommendationTests: XCTestCase {
    func testRefreshClearsStalePendingConfirmationWhenRecommendationDisappears() async throws {
        let root = try self.makeTemporaryDirectory(named: "app-model-recommendation")
        let currentRoot = root.appendingPathComponent("codex-current", isDirectory: true)
        let backupRoot = root.appendingPathComponent("codex-backup", isDirectory: true)

        try FileManager.default.createDirectory(at: currentRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        try self.writeCodexAuth(accessToken: "current-token", to: currentRoot.appendingPathComponent("auth.json"))
        try self.writeCodexAuth(accessToken: "backup-token", to: backupRoot.appendingPathComponent("auth.json"))

        let storedSources = [
            StoredProfileSource(
                id: UUID(),
                provider: .codex,
                label: "Codex Current",
                profileRootPath: currentRoot.standardizedFileURL.path,
                isEnabled: true,
                addedAt: .now,
                sourceKind: .stored,
                ownershipMode: .externalLocal
            ),
            StoredProfileSource(
                id: UUID(),
                provider: .codex,
                label: "Codex Backup",
                profileRootPath: backupRoot.standardizedFileURL.path,
                isEnabled: true,
                addedAt: .now,
                sourceKind: .stored,
                ownershipMode: .externalLocal
            ),
        ]

        let sourcesURL = root.appendingPathComponent("stored-profile-sources.json")
        try FileStoredProfileSourceStore(fileURL: sourcesURL).saveSources(storedSources)

        let selectionsURL = root.appendingPathComponent("current-profile-selections.json")
        try FileCurrentProfileSelectionStore(fileURL: selectionsURL).saveSelections([
            .codex: currentRoot.standardizedFileURL.path,
        ])

        let suiteName = "AppModelRecommendationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let network = SequenceRequestPerformer(responses: [
            Self.codexUsageResponse(usedPercent: 40),
            Self.codexUsageResponse(usedPercent: 50),
        ])

        let model = AppModel(
            activityLogStore: ActivityLogStore(fileURL: root.appendingPathComponent("activity-log.json")),
            accounts: [],
            ambientUsageLoader: AmbientUsageLoader(network: network),
            backgroundRefreshSettingsStorage: BackgroundRefreshSettingsStorage(
                userDefaults: defaults,
                key: "background-refresh"
            ),
            launchAtLoginController: SpyRecommendationLaunchAtLoginController(isEnabled: false),
            profileActivator: LocalProfileActivator(
                homeURL: root,
                backupRootURL: root.appendingPathComponent("backups", isDirectory: true),
                claudeKeychainManager: StubRecommendationClaudeKeychainCredentialManager(data: nil)
            ),
            profileDiscovery: LocalProfileDiscovery(),
            recommendationAlertNotifier: StubRecommendationAlertNotifier(),
            recommendationAlertSettingsStorage: RecommendationAlertSettingsStorage(
                userDefaults: defaults,
                key: "alerts"
            ),
            recommendationAlertStateStore: RecommendationAlertStateStore(
                fileURL: root.appendingPathComponent("recommendation-alert-state.json")
            ),
            startupBehaviorStorage: StartupBehaviorStorage(userDefaults: defaults, key: "startup-behavior"),
            switchActionModeStorage: SwitchActionModeStorage(
                userDefaults: defaults,
                key: "switch-mode"
            ),
            currentProfileSelectionStore: FileCurrentProfileSelectionStore(fileURL: selectionsURL),
            profileSourceStore: FileStoredProfileSourceStore(fileURL: sourcesURL),
            rulesStorage: GlobalRulesStorage(userDefaults: defaults, key: "rules"),
            widgetSnapshotStore: QuotaPilotWidgetSnapshotStore(
                fileURL: root.appendingPathComponent("widget-snapshot.json")
            ),
            homeURL: root
        )

        model.updateSwitchActionMode(SwitchActionMode.confirmBeforeActivatingLocalProfiles)
        model.pendingSwitchConfirmations[.codex] = RecommendationActivationOption(
            provider: .codex,
            accountID: UUID(),
            accountLabel: "Codex Backup",
            profileRootPath: backupRoot.standardizedFileURL.path,
            status: .activatable,
            reason: "Ready to activate the recommended profile."
        )

        await model.refreshLiveUsage()
        XCTAssertTrue(model.pendingSwitchConfirmations.isEmpty)
    }

    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeCodexAuth(accessToken: String, to url: URL) throws {
        let authJSON = """
        {
          "tokens": {
            "access_token": "\(accessToken)",
            "refresh_token": "refresh"
          }
        }
        """
        try authJSON.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func codexUsageResponse(usedPercent: Int) -> StubHTTPResponse {
        StubHTTPResponse(
            statusCode: 200,
            json: """
            {
              "rate_limit": {
                "primary_window": {
                  "used_percent": \(usedPercent),
                  "reset_at": 1893456000,
                  "limit_window_seconds": 300
                }
              }
            }
            """
        )
    }
}

private struct StubHTTPResponse {
    let statusCode: Int
    let json: String
}

private final class SequenceRequestPerformer: @unchecked Sendable, URLRequestPerforming {
    private var responses: [StubHTTPResponse]

    init(responses: [StubHTTPResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard !self.responses.isEmpty else {
            throw URLError(.badServerResponse)
        }

        let response = self.responses.removeFirst()
        let httpResponse = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(response.json.utf8), httpResponse)
    }
}

private final class SpyRecommendationLaunchAtLoginController: LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus

    init(isEnabled: Bool) {
        self.status = isEnabled ? .enabled : .disabled
    }

    var isEnabled: Bool {
        self.status != .disabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        self.status = isEnabled ? .enabled : .disabled
    }
}

private struct StubRecommendationAlertNotifier: RecommendationAlertNotifying {
    func deliver(_ candidate: RecommendationAlertCandidate) async -> Bool {
        false
    }
}

private final class StubRecommendationClaudeKeychainCredentialManager: @unchecked Sendable, ClaudeKeychainCredentialManaging {
    var data: Data?

    init(data: Data?) {
        self.data = data
    }

    func readCredentialData() throws -> Data? {
        self.data
    }

    func writeCredentialData(_ data: Data) throws {
        self.data = data
    }
}
