import Foundation

public enum TrackedProfileLifecycleState: Equatable, Sendable {
    case awaitingRefresh
    case ready
    case credentialsMissing
    case authExpired
    case sessionUnavailable
    case usageReadFailed
}

public struct TrackedProfileLifecycleStatus: Equatable, Sendable {
    public let state: TrackedProfileLifecycleState
    public let title: String
    public let detail: String?
    public let nextAction: String

    public init(
        state: TrackedProfileLifecycleState,
        title: String,
        detail: String?,
        nextAction: String
    ) {
        self.state = state
        self.title = title
        self.detail = detail
        self.nextAction = nextAction
    }
}

public enum TrackedProfileLifecycleStatusBuilder {
    public static func makeStatus(
        liveAccount: QuotaAccount?,
        failure: AmbientUsageRefreshFailure?
    ) -> TrackedProfileLifecycleStatus {
        if liveAccount != nil {
            return TrackedProfileLifecycleStatus(
                state: .ready,
                title: "Ready",
                detail: "Live usage is available for this profile.",
                nextAction: "QuotaPilot will keep refreshing this profile automatically."
            )
        }

        guard let failure else {
            return TrackedProfileLifecycleStatus(
                state: .awaitingRefresh,
                title: "Awaiting Refresh",
                detail: "QuotaPilot has not loaded live usage for this profile yet.",
                nextAction: "Run Refresh Live Usage to evaluate this profile."
            )
        }

        switch failure.kind {
        case .invalidCredentials:
            return TrackedProfileLifecycleStatus(
                state: .credentialsMissing,
                title: "Credentials Missing",
                detail: failure.detail,
                nextAction: "Repair or restore the local credentials for this profile, then refresh."
            )
        case let .requestFailed(statusCode) where statusCode == 401 || statusCode == 403:
            return TrackedProfileLifecycleStatus(
                state: .authExpired,
                title: "Auth Expired",
                detail: failure.detail,
                nextAction: "Reauthenticate this provider locally, then refresh."
            )
        case .noUsageData:
            return TrackedProfileLifecycleStatus(
                state: .sessionUnavailable,
                title: "Session Unavailable",
                detail: failure.detail,
                nextAction: "Open the local app or CLI for this account to renew its session, then refresh."
            )
        case .requestFailed, .unexpected:
            return TrackedProfileLifecycleStatus(
                state: .usageReadFailed,
                title: "Usage Read Failed",
                detail: failure.detail,
                nextAction: "Retry refresh. If it keeps failing, check network access or provider availability."
            )
        }
    }
}
