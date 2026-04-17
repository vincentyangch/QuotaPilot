import Foundation
#if canImport(Security)
import Security
#endif

public protocol ClaudeKeychainCredentialProviding: Sendable {
    func readCredentialData() throws -> Data?
}

public struct ClaudeKeychainCredentialProvider: ClaudeKeychainCredentialProviding {
    public init() {}

    public func readCredentialData() throws -> Data? {
        #if canImport(Security)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
        ]

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
}
