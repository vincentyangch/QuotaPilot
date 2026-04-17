import Foundation

public protocol StoredProfileSourceStoring {
    func loadSources() throws -> [StoredProfileSource]
    func saveSources(_ sources: [StoredProfileSource]) throws
}

private struct StoredProfileSourceFilePayload: Codable {
    let version: Int
    let sources: [StoredProfileSource]
}

public struct FileStoredProfileSourceStore: StoredProfileSourceStoring {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL = Self.defaultURL(), fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func loadSources() throws -> [StoredProfileSource] {
        guard self.fileManager.fileExists(atPath: self.fileURL.path) else { return [] }
        let data = try Data(contentsOf: self.fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(StoredProfileSourceFilePayload.self, from: data)
        guard payload.version == 1 else { return payload.sources }
        return payload.sources
    }

    public func saveSources(_ sources: [StoredProfileSource]) throws {
        let payload = StoredProfileSourceFilePayload(version: 1, sources: sources)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        let directory = self.fileURL.deletingLastPathComponent()
        if !self.fileManager.fileExists(atPath: directory.path) {
            try self.fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        try data.write(to: self.fileURL, options: [.atomic])

        #if os(macOS)
        try? self.fileManager.setAttributes([
            .posixPermissions: NSNumber(value: Int16(0o600)),
        ], ofItemAtPath: self.fileURL.path)
        #endif
    }

    public static func defaultURL(fileManager: FileManager = .default) -> URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        return root
            .appendingPathComponent("QuotaPilot", isDirectory: true)
            .appendingPathComponent("stored-profile-sources.json")
    }
}
