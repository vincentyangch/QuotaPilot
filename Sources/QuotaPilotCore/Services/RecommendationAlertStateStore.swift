import Foundation

private struct RecommendationAlertStatePayload: Codable {
    let version: Int
    let lastDeliveredByProvider: [String: String]
}

public struct RecommendationAlertStateStore {
    private let fileManager: FileManager
    private let fileURL: URL

    public init(
        fileURL: URL = Self.defaultURL(),
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL
    }

    public func loadState() throws -> [QuotaProvider: String] {
        guard self.fileManager.fileExists(atPath: self.fileURL.path) else { return [:] }
        let data = try Data(contentsOf: self.fileURL)
        let payload = try JSONDecoder().decode(RecommendationAlertStatePayload.self, from: data)
        return Dictionary(uniqueKeysWithValues: payload.lastDeliveredByProvider.compactMap { key, value in
            guard let provider = QuotaProvider(rawValue: key) else { return nil }
            return (provider, value)
        })
    }

    public func saveState(_ state: [QuotaProvider: String]) throws {
        let payload = RecommendationAlertStatePayload(
            version: 1,
            lastDeliveredByProvider: Dictionary(uniqueKeysWithValues: state.map { ($0.key.rawValue, $0.value) })
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
            .appendingPathComponent("recommendation-alert-state.json")
    }
}
