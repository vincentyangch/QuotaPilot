import Foundation

public enum ProfileSourceKind: String, Codable, Equatable, Sendable {
    case ambient
    case stored
    case backup
}

public enum ProfileOwnershipMode: String, Codable, Equatable, Sendable {
    case externalLocal
    case quotaPilotManaged
}

public extension ProfileSourceKind {
    var displayLabel: String {
        switch self {
        case .ambient:
            "Ambient"
        case .stored:
            "Stored"
        case .backup:
            "Backup"
        }
    }
}

public extension ProfileOwnershipMode {
    var displayLabel: String {
        switch self {
        case .externalLocal:
            "External"
        case .quotaPilotManaged:
            "Managed"
        }
    }
}
