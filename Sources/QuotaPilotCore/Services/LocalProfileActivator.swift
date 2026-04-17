import Foundation

public struct ProfileActivationResult: Sendable {
    public let provider: QuotaProvider
    public let activatedProfileRootPath: String
    public let createdBackupSource: StoredProfileSource?

    public init(
        provider: QuotaProvider,
        activatedProfileRootPath: String,
        createdBackupSource: StoredProfileSource?
    ) {
        self.provider = provider
        self.activatedProfileRootPath = activatedProfileRootPath
        self.createdBackupSource = createdBackupSource
    }
}

public enum LocalProfileActivatorError: LocalizedError {
    case missingSourceCredentials(provider: QuotaProvider)

    public var errorDescription: String? {
        switch self {
        case let .missingSourceCredentials(provider):
            return "Could not find usable \(provider.displayName) credentials for that profile."
        }
    }
}

public struct LocalProfileActivator {
    private let backupRootURL: URL
    private let claudeKeychainManager: ClaudeKeychainCredentialManaging
    private let fileManager: FileManager
    private let homeURL: URL

    public init(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        backupRootURL: URL = Self.defaultBackupRootURL(),
        claudeKeychainManager: ClaudeKeychainCredentialManaging = ClaudeKeychainCredentialProvider(),
        fileManager: FileManager = .default
    ) {
        self.backupRootURL = backupRootURL
        self.claudeKeychainManager = claudeKeychainManager
        self.fileManager = fileManager
        self.homeURL = homeURL
    }

    public func activate(profile: DiscoveredLocalProfile) throws -> ProfileActivationResult {
        let ambientRootURL = self.ambientRootURL(for: profile.provider)
        let standardizedTargetPath = profile.profileRootURL.standardizedFileURL.path
        let standardizedAmbientPath = ambientRootURL.standardizedFileURL.path

        if standardizedTargetPath == standardizedAmbientPath {
            return ProfileActivationResult(
                provider: profile.provider,
                activatedProfileRootPath: standardizedTargetPath,
                createdBackupSource: nil
            )
        }

        let backupSource = try self.backupAmbientCredentialsIfNeeded(for: profile.provider)
        let targetData = try self.loadCredentialData(from: profile)
        try self.writeAmbientCredentialData(
            targetData,
            provider: profile.provider,
            ambientRootURL: ambientRootURL
        )

        return ProfileActivationResult(
            provider: profile.provider,
            activatedProfileRootPath: standardizedTargetPath,
            createdBackupSource: backupSource
        )
    }

    private func ambientRootURL(for provider: QuotaProvider) -> URL {
        switch provider {
        case .codex:
            self.homeURL.appendingPathComponent(".codex", isDirectory: true)
        case .claude:
            self.homeURL.appendingPathComponent(".claude", isDirectory: true)
        }
    }

    private func credentialsURL(for provider: QuotaProvider, rootURL: URL) -> URL {
        switch provider {
        case .codex:
            rootURL.appendingPathComponent("auth.json")
        case .claude:
            rootURL.appendingPathComponent(".credentials.json")
        }
    }

    private func loadCredentialData(from profile: DiscoveredLocalProfile) throws -> Data {
        if self.fileManager.fileExists(atPath: profile.credentialsURL.path) {
            return try Data(contentsOf: profile.credentialsURL)
        }

        if profile.provider == .claude,
           let data = try self.claudeKeychainManager.readCredentialData()
        {
            return data
        }

        throw LocalProfileActivatorError.missingSourceCredentials(provider: profile.provider)
    }

    private func readAmbientCredentialData(for provider: QuotaProvider) throws -> Data? {
        let ambientRootURL = self.ambientRootURL(for: provider)
        let credentialsURL = self.credentialsURL(for: provider, rootURL: ambientRootURL)

        if self.fileManager.fileExists(atPath: credentialsURL.path) {
            return try Data(contentsOf: credentialsURL)
        }

        if provider == .claude {
            return try self.claudeKeychainManager.readCredentialData()
        }

        return nil
    }

    private func backupAmbientCredentialsIfNeeded(for provider: QuotaProvider) throws -> StoredProfileSource? {
        let backupRootURL = self.backupRootURL
            .appendingPathComponent(provider.rawValue, isDirectory: true)
            .appendingPathComponent("ambient-backup", isDirectory: true)
        let backupCredentialsURL = self.credentialsURL(for: provider, rootURL: backupRootURL)

        guard !self.fileManager.fileExists(atPath: backupCredentialsURL.path) else {
            return nil
        }

        guard let ambientData = try self.readAmbientCredentialData(for: provider) else {
            return nil
        }

        try self.writeCredentialData(ambientData, provider: provider, rootURL: backupRootURL)
        return StoredProfileSource(
            id: UUID(),
            provider: provider,
            label: "\(provider.displayName) Ambient Backup",
            profileRootPath: backupRootURL.standardizedFileURL.path,
            isEnabled: true,
            addedAt: Date()
        )
    }

    private func writeAmbientCredentialData(
        _ data: Data,
        provider: QuotaProvider,
        ambientRootURL: URL
    ) throws {
        try self.writeCredentialData(data, provider: provider, rootURL: ambientRootURL)
        if provider == .claude {
            try self.claudeKeychainManager.writeCredentialData(data)
        }
    }

    private func writeCredentialData(
        _ data: Data,
        provider: QuotaProvider,
        rootURL: URL
    ) throws {
        if !self.fileManager.fileExists(atPath: rootURL.path) {
            try self.fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }

        let credentialsURL = self.credentialsURL(for: provider, rootURL: rootURL)
        try data.write(to: credentialsURL, options: [.atomic])

        #if os(macOS)
        try? self.fileManager.setAttributes([
            .posixPermissions: NSNumber(value: Int16(0o600)),
        ], ofItemAtPath: credentialsURL.path)
        #endif
    }

    public static func defaultBackupRootURL(fileManager: FileManager = .default) -> URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        return root
            .appendingPathComponent("QuotaPilot", isDirectory: true)
            .appendingPathComponent("profile-backups", isDirectory: true)
    }
}
