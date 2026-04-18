import XCTest
@testable import QuotaPilot
import QuotaPilotCore

@MainActor
final class AppModelLaunchSettingsTests: XCTestCase {
    func testUpdateStartupBehaviorPersistsValue() {
        let suiteName = "AppModelLaunchSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let storage = StartupBehaviorStorage(userDefaults: defaults, key: "startup-behavior")
        let controller = SpyLaunchAtLoginController(isEnabled: false)
        let model = self.makeModel(
            defaults: defaults,
            startupBehaviorStorage: storage,
            launchAtLoginController: controller
        )

        model.updateStartupBehavior(StartupBehavior(opensDashboardOnLaunch: false))

        XCTAssertEqual(model.startupBehavior, StartupBehavior(opensDashboardOnLaunch: false))
        XCTAssertEqual(storage.load(), StartupBehavior(opensDashboardOnLaunch: false))
    }

    func testUpdateLaunchAtLoginUsesControllerAndReflectsEnabledState() {
        let suiteName = "AppModelLaunchSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let controller = SpyLaunchAtLoginController(isEnabled: false)
        let model = self.makeModel(
            defaults: defaults,
            startupBehaviorStorage: StartupBehaviorStorage(userDefaults: defaults, key: "startup-behavior"),
            launchAtLoginController: controller
        )

        model.updateLaunchAtLoginEnabled(true)

        XCTAssertTrue(model.isLaunchAtLoginEnabled)
        XCTAssertEqual(model.launchAtLoginStatus, .enabled)
        XCTAssertEqual(controller.setEnabledCalls, [true])
    }

    func testUpdateLaunchAtLoginReportsApprovalWhenSystemStillRequiresIt() {
        let suiteName = "AppModelLaunchSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let controller = SpyLaunchAtLoginController(status: .requiresApproval)
        let model = self.makeModel(
            defaults: defaults,
            startupBehaviorStorage: StartupBehaviorStorage(userDefaults: defaults, key: "startup-behavior"),
            launchAtLoginController: controller
        )

        model.updateLaunchAtLoginEnabled(true)

        XCTAssertTrue(model.isLaunchAtLoginEnabled)
        XCTAssertEqual(model.launchAtLoginStatus, .requiresApproval)
        XCTAssertEqual(
            model.launchSettingsSummary,
            "Approve QuotaPilot in System Settings to finish enabling launch at login."
        )
    }

    private func makeModel(
        defaults: UserDefaults,
        startupBehaviorStorage: StartupBehaviorStorage,
        launchAtLoginController: LaunchAtLoginControlling
    ) -> AppModel {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return AppModel(
            activityLogStore: ActivityLogStore(fileURL: root.appendingPathComponent("activity-log.json")),
            accounts: [],
            ambientUsageLoader: AmbientUsageLoader(),
            backgroundRefreshSettingsStorage: BackgroundRefreshSettingsStorage(
                userDefaults: defaults,
                key: "background-refresh"
            ),
            launchAtLoginController: launchAtLoginController,
            profileActivator: LocalProfileActivator(
                homeURL: root,
                backupRootURL: root.appendingPathComponent("backups", isDirectory: true),
                claudeKeychainManager: StubLaunchClaudeKeychainCredentialManager(data: nil)
            ),
            profileDiscovery: LocalProfileDiscovery(),
            recommendationAlertNotifier: StubLaunchRecommendationAlertNotifier(),
            recommendationAlertSettingsStorage: RecommendationAlertSettingsStorage(
                userDefaults: defaults,
                key: "alerts"
            ),
            recommendationAlertStateStore: RecommendationAlertStateStore(
                fileURL: root.appendingPathComponent("recommendation-alert-state.json")
            ),
            startupBehaviorStorage: startupBehaviorStorage,
            switchActionModeStorage: SwitchActionModeStorage(
                userDefaults: defaults,
                key: "switch-mode"
            ),
            currentProfileSelectionStore: FileCurrentProfileSelectionStore(
                fileURL: root.appendingPathComponent("current-profile-selections.json")
            ),
            profileSourceStore: FileStoredProfileSourceStore(
                fileURL: root.appendingPathComponent("stored-profile-sources.json")
            ),
            rulesStorage: GlobalRulesStorage(userDefaults: defaults, key: "rules"),
            widgetSnapshotStore: QuotaPilotWidgetSnapshotStore(
                fileURL: root.appendingPathComponent("widget-snapshot.json")
            ),
            homeURL: root
        )
    }
}

private final class SpyLaunchAtLoginController: LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus
    var setEnabledCalls: [Bool] = []

    init(isEnabled: Bool) {
        self.status = isEnabled ? .enabled : .disabled
    }

    init(status: LaunchAtLoginStatus) {
        self.status = status
    }

    var isEnabled: Bool {
        self.status != .disabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            if self.status == .disabled {
                self.status = .enabled
            }
        } else {
            self.status = .disabled
        }
        self.setEnabledCalls.append(isEnabled)
    }
}

private struct StubLaunchRecommendationAlertNotifier: RecommendationAlertNotifying {
    func deliver(_ candidate: RecommendationAlertCandidate) async -> Bool {
        false
    }
}

private final class StubLaunchClaudeKeychainCredentialManager: @unchecked Sendable, ClaudeKeychainCredentialManaging {
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
