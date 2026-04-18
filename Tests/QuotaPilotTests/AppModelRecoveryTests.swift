import XCTest
@testable import QuotaPilot
import QuotaPilotCore

@MainActor
final class AppModelRecoveryTests: XCTestCase {
    func testRecordsRestoreProvenanceWhenRestoringManagedBackupProfile() async throws {
        let root = try self.makeTemporaryDirectory(named: "app-model-recovery")
        let homeURL = root.appendingPathComponent("home", isDirectory: true)
        let backupRoot = root.appendingPathComponent("backups", isDirectory: true)
        let currentRoot = root.appendingPathComponent("codex-work", isDirectory: true)
        let backupProfileRoot = backupRoot
            .appendingPathComponent("codex", isDirectory: true)
            .appendingPathComponent("ambient-backup", isDirectory: true)

        try FileManager.default.createDirectory(at: homeURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: currentRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: backupProfileRoot, withIntermediateDirectories: true)
        try self.writeCodexAuth(
            email: "work@example.com",
            plan: "pro",
            to: currentRoot.appendingPathComponent("auth.json")
        )
        try self.writeCodexAuth(
            email: "backup@example.com",
            plan: "plus",
            to: backupProfileRoot.appendingPathComponent("auth.json")
        )

        let storedSources = [
            StoredProfileSource(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000101") ?? UUID(),
                provider: .codex,
                label: "Codex Work",
                profileRootPath: currentRoot.standardizedFileURL.path,
                isEnabled: true,
                addedAt: Date(timeIntervalSince1970: 100),
                sourceKind: .stored,
                ownershipMode: .externalLocal
            ),
            StoredProfileSource(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000102") ?? UUID(),
                provider: .codex,
                label: "Codex Ambient Backup",
                profileRootPath: backupProfileRoot.standardizedFileURL.path,
                isEnabled: true,
                addedAt: Date(timeIntervalSince1970: 200),
                sourceKind: .backup,
                ownershipMode: .quotaPilotManaged
            ),
        ]

        let sourcesURL = root.appendingPathComponent("stored-profile-sources.json")
        try FileStoredProfileSourceStore(fileURL: sourcesURL).saveSources(storedSources)

        let selectionsURL = root.appendingPathComponent("current-profile-selections.json")
        try FileCurrentProfileSelectionStore(fileURL: selectionsURL).saveSelections([
            .codex: currentRoot.standardizedFileURL.path,
        ])

        let suiteName = "AppModelRecoveryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let model = AppModel(
            activityLogStore: ActivityLogStore(fileURL: root.appendingPathComponent("activity-log.json")),
            accounts: [],
            ambientUsageLoader: AmbientUsageLoader(network: StubRequestPerformer { request in
                try Self.makeHTTPResponse(
                    url: request.url!,
                    statusCode: 200,
                    json: """
                    {
                      "rate_limit": {
                        "primary_window": {
                          "used_percent": 35,
                          "reset_at": 1893456000,
                          "limit_window_seconds": 300
                        }
                      }
                    }
                    """
                )
            }),
            backgroundRefreshSettingsStorage: BackgroundRefreshSettingsStorage(
                userDefaults: defaults,
                key: "background-refresh"
            ),
            profileActivator: LocalProfileActivator(
                homeURL: homeURL,
                backupRootURL: backupRoot,
                claudeKeychainManager: StubClaudeKeychainCredentialManager(data: nil)
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
            homeURL: homeURL
        )

        let backupProfile = try XCTUnwrap(model.discoveredProfiles.first(where: \.isManagedBackup))

        await model.activateProfile(backupProfile)

        let restoreEntry = try XCTUnwrap(model.activityLogEntries.first(where: \.isBackupRestore))
        let provenance = try XCTUnwrap(restoreEntry.restoreProvenance)

        XCTAssertEqual(provenance.sourceProfile.label, "Codex Ambient Backup")
        XCTAssertEqual(provenance.sourceProfile.profileRootPath, backupProfileRoot.standardizedFileURL.path)
        XCTAssertEqual(provenance.replacedProfile?.label, "Codex Work")
        XCTAssertEqual(provenance.replacedProfile?.profileRootPath, currentRoot.standardizedFileURL.path)
    }

    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeCodexAuth(email: String, plan: String, to url: URL) throws {
        let payload = """
        {
          "email": "\(email)",
          "https://api.openai.com/auth": {
            "chatgpt_plan_type": "\(plan)"
          }
        }
        """
        let jwt = self.makeJWT(payloadJSON: payload)
        let authJSON = """
        {
          "tokens": {
            "access_token": "access",
            "refresh_token": "refresh",
            "id_token": "\(jwt)"
          }
        }
        """
        try authJSON.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeJWT(payloadJSON: String) -> String {
        let header = #"{"alg":"none","typ":"JWT"}"#
        return [
            self.base64url(header),
            self.base64url(payloadJSON),
            "signature",
        ].joined(separator: ".")
    }

    private func base64url(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    nonisolated private static func makeHTTPResponse(
        url: URL,
        statusCode: Int,
        json: String
    ) throws -> (Data, HTTPURLResponse) {
        let response = try XCTUnwrap(
            HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
        )
        return (Data(json.utf8), response)
    }
}

private struct StubRequestPerformer: URLRequestPerforming {
    let handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try self.handler(request)
    }
}

private struct StubRecommendationAlertNotifier: RecommendationAlertNotifying {
    func deliver(_ candidate: RecommendationAlertCandidate) async -> Bool {
        false
    }
}

private final class StubClaudeKeychainCredentialManager: @unchecked Sendable, ClaudeKeychainCredentialManaging {
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
