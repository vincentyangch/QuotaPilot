import Foundation

public struct NormalizedProfileSourceInput: Equatable, Sendable {
    public let provider: QuotaProvider
    public let label: String
    public let normalizedPath: String

    public init(provider: QuotaProvider, label: String, normalizedPath: String) {
        self.provider = provider
        self.label = label
        self.normalizedPath = normalizedPath
    }
}

public enum ProfileSourceInputNormalizer {
    public static func normalize(
        provider: QuotaProvider,
        label: String,
        path: String
    ) -> NormalizedProfileSourceInput? {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        let normalizedURL = URL(fileURLWithPath: trimmedPath, isDirectory: true).standardizedFileURL
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLabel = trimmedLabel.isEmpty ? normalizedURL.lastPathComponent : trimmedLabel

        return NormalizedProfileSourceInput(
            provider: provider,
            label: finalLabel,
            normalizedPath: normalizedURL.path
        )
    }
}
