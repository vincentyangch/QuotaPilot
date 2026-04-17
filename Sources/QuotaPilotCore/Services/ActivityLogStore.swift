import Foundation

private struct ActivityLogPayload: Codable {
    let version: Int
    let entries: [ActivityLogEntry]
}

public struct ActivityLogStore {
    private let fileManager: FileManager
    private let fileURL: URL

    public init(
        fileURL: URL = Self.defaultURL(),
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL
    }

    public func loadEntries() throws -> [ActivityLogEntry] {
        guard self.fileManager.fileExists(atPath: self.fileURL.path) else { return [] }
        let data = try Data(contentsOf: self.fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ActivityLogPayload.self, from: data)
        return payload.entries
    }

    public func saveEntries(_ entries: [ActivityLogEntry], maxEntries: Int = 200) throws {
        let trimmedEntries = Array(entries.suffix(maxEntries))
        let payload = ActivityLogPayload(version: 1, entries: trimmedEntries)
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
            .appendingPathComponent("activity-log.json")
    }
}
