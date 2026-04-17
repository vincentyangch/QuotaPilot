import Foundation

public struct QuotaPilotWidgetSnapshotStore {
    private let fileManager: FileManager
    private let fileURL: URL

    public init(
        fileURL: URL = Self.defaultURL(),
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL
    }

    public func load() throws -> QuotaPilotWidgetSnapshot? {
        guard self.fileManager.fileExists(atPath: self.fileURL.path) else { return nil }
        let data = try Data(contentsOf: self.fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(QuotaPilotWidgetSnapshot.self, from: data)
    }

    public func save(_ snapshot: QuotaPilotWidgetSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

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
            .appendingPathComponent("widget-snapshot.json")
    }
}
