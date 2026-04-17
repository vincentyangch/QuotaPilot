import SwiftUI
import QuotaPilotCore

struct ActivityLogSectionView: View {
    let entries: [ActivityLogEntry]
    var maxEntries: Int = 8

    private var displayedEntries: [ActivityLogEntry] {
        Array(self.entries.prefix(self.maxEntries))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Activity")
                .font(.headline)

            if self.displayedEntries.isEmpty {
                Text("No activity recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(self.displayedEntries) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        if let provider = entry.provider {
                            ProviderIconView(provider: provider, size: 14)
                        } else {
                            Image(systemName: "clock.arrow.circlepath")
                                .frame(width: 14, height: 14)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .fontWeight(.semibold)
                            Text(entry.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Self.timestampFormatter.string(from: entry.timestamp))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
