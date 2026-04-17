import XCTest
@testable import QuotaPilotCore

final class TrackedProfileLifecycleStatusBuilderTests: XCTestCase {
    func testMarksReadyWhenLiveUsageIsAvailable() {
        let status = TrackedProfileLifecycleStatusBuilder.makeStatus(
            liveAccount: QuotaAccount.codex(
                label: "Codex Work",
                remainingPercent: 72,
                resetHours: 2,
                priority: 80,
                isCurrent: true,
                profileRootPath: "/tmp/codex-work"
            ),
            failure: nil
        )

        XCTAssertEqual(status.state, .ready)
        XCTAssertEqual(status.title, "Ready")
    }

    func testMarksCredentialsMissingWhenFailureIsInvalidCredentials() {
        let status = TrackedProfileLifecycleStatusBuilder.makeStatus(
            liveAccount: nil,
            failure: AmbientUsageRefreshFailure(
                provider: .claude,
                profileLabel: "Claude Free",
                profileRootPath: "/tmp/claude-free",
                detail: "Invalid Claude credentials.",
                kind: .invalidCredentials
            )
        )

        XCTAssertEqual(status.state, .credentialsMissing)
        XCTAssertEqual(status.title, "Credentials Missing")
    }

    func testMarksAuthExpiredForUnauthorizedRequestFailure() {
        let status = TrackedProfileLifecycleStatusBuilder.makeStatus(
            liveAccount: nil,
            failure: AmbientUsageRefreshFailure(
                provider: .codex,
                profileLabel: "Codex Work",
                profileRootPath: "/tmp/codex-work",
                detail: "Codex usage request failed with HTTP 401.",
                kind: .requestFailed(statusCode: 401)
            )
        )

        XCTAssertEqual(status.state, .authExpired)
        XCTAssertEqual(status.title, "Auth Expired")
    }

    func testMarksSessionUnavailableWhenNoUsageWindowsAreReturned() {
        let status = TrackedProfileLifecycleStatusBuilder.makeStatus(
            liveAccount: nil,
            failure: AmbientUsageRefreshFailure(
                provider: .codex,
                profileLabel: "Codex Work",
                profileRootPath: "/tmp/codex-work",
                detail: "No live usage windows were returned.",
                kind: .noUsageData
            )
        )

        XCTAssertEqual(status.state, .sessionUnavailable)
        XCTAssertEqual(status.title, "Session Unavailable")
    }

    func testMarksAwaitingRefreshWhenNoUsageHasBeenLoadedYet() {
        let status = TrackedProfileLifecycleStatusBuilder.makeStatus(
            liveAccount: nil,
            failure: nil
        )

        XCTAssertEqual(status.state, .awaitingRefresh)
        XCTAssertEqual(status.title, "Awaiting Refresh")
    }
}
