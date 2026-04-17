import Foundation

public protocol CurrentProfileSelectionStoring {
    func loadSelections() throws -> [QuotaProvider: String]
    func saveSelections(_ selections: [QuotaProvider: String]) throws
}

private struct CurrentProfileSelectionPayload: Codable {
    let version: Int
    let selections: [String: String]
}

public struct FileCurrentProfileSelectionStore: CurrentProfileSelectionStoring {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL = Self.defaultURL(), fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func loadSelections() throws -> [QuotaProvider: String] {
        guard self.fileManager.fileExists(atPath: self.fileURL.path) else { return [:] }
        let data = try Data(contentsOf: self.fileURL)
        let payload = try JSONDecoder().decode(CurrentProfileSelectionPayload.self, from: data)
        var result: [QuotaProvider: String] = [:]
        for (key, value) in payload.selections {
            guard let provider = QuotaProvider(rawValue: key) else { continue }
            result[provider] = value
        }
        return result
    }

    public func saveSelections(_ selections: [QuotaProvider: String]) throws {
        let payload = CurrentProfileSelectionPayload(
            version: 1,
            selections: Dictionary(uniqueKeysWithValues: selections.map { ($0.key.rawValue, $0.value) })
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
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
            .appendingPathComponent("current-profile-selections.json")
    }
}
