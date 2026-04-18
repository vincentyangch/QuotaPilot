import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case disabled
    case enabled
    case requiresApproval
}

protocol LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus { get }
    var isEnabled: Bool { get }
    func setEnabled(_ isEnabled: Bool) throws
}

struct LaunchAtLoginController: LaunchAtLoginControlling {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var status: LaunchAtLoginStatus {
        switch self.service.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound, .notRegistered:
            return .disabled
        @unknown default:
            return .disabled
        }
    }

    var isEnabled: Bool {
        self.status != .disabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            if self.status == .disabled {
                try self.service.register()
            }
        } else if self.status != .disabled {
            try self.service.unregister()
        }
    }
}
