import Foundation
#if canImport(Security)
import Security
#endif

public protocol ClaudeKeychainCredentialProviding: Sendable {
    func readCredentialData() throws -> Data?
}

public protocol ClaudeKeychainCredentialManaging: ClaudeKeychainCredentialProviding {
    func writeCredentialData(_ data: Data) throws
}

public struct ClaudeKeychainCredentialProvider: ClaudeKeychainCredentialManaging {
    public init() {}

    public func readCredentialData() throws -> Data? {
        #if canImport(Security)
        let query = Self.baseQuery(returnData: true)
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound, errSecInteractionNotAllowed:
            return nil
        default:
            return nil
        }
        #else
        return nil
        #endif
    }

    public func writeCredentialData(_ data: Data) throws {
        #if canImport(Security)
        let query = Self.baseQuery(returnData: false)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addItem = query
            addItem[kSecValueData as String] = data
            let addStatus = SecItemAdd(addItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw ClaudeKeychainCredentialProviderError.osStatus(addStatus)
            }
        default:
            throw ClaudeKeychainCredentialProviderError.osStatus(updateStatus)
        }
        #else
        _ = data
        #endif
    }

    #if canImport(Security)
    private static func baseQuery(returnData: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
        ]
        if returnData {
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            query[kSecReturnData as String] = true
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        }
        return query
    }
    #endif
}

public enum ClaudeKeychainCredentialProviderError: LocalizedError {
    case osStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case let .osStatus(status):
            return "Claude Keychain operation failed with OSStatus \(status)."
        }
    }
}
