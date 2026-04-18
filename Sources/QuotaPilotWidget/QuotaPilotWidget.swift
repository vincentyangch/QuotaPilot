import SwiftUI
import WidgetKit
import QuotaPilotCore

struct WidgetProviderIconView: View {
    let provider: QuotaProvider

    var body: some View {
        Group {
            if let image = ProviderBrandAsset.iconImage(for: self.provider, size: 12) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: self.provider.symbolName)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 12, height: 12)
        .foregroundStyle(.secondary)
    }
}

struct QuotaPilotEntry: TimelineEntry {
    let date: Date
    let projection: QuotaPilotWidgetProjectionResult
}

struct QuotaPilotProvider: TimelineProvider {
    private let snapshotStore = QuotaPilotWidgetSnapshotStore()

    func placeholder(in context: Context) -> QuotaPilotEntry {
        let accounts = DemoAccountRepository.makeAccounts()
        let snapshot = QuotaPilotWidgetSnapshot(
            generatedAt: .now,
            accounts: accounts,
            rules: .default,
            lastUsageRefreshSummary: "Demo data"
        )
        let projection = QuotaPilotWidgetProjection.make(snapshot: snapshot)

        return QuotaPilotEntry(
            date: .now,
            projection: projection
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (QuotaPilotEntry) -> Void) {
        completion(self.loadEntry() ?? self.placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaPilotEntry>) -> Void) {
        let entry = self.loadEntry() ?? self.placeholder(in: context)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }

    private func loadEntry() -> QuotaPilotEntry? {
        guard let snapshot = try? self.snapshotStore.load() else {
            return nil
        }

        let projection = QuotaPilotWidgetProjection.make(snapshot: snapshot)

        return QuotaPilotEntry(
            date: snapshot.generatedAt,
            projection: projection
        )
    }
}

struct QuotaPilotWidgetView: View {
    let entry: QuotaPilotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QuotaPilot")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let panel = self.entry.projection.globalRecommendationPanel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(panel.statusText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        if panel.showsWarning {
                            Text("Low")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            WidgetProviderIconView(provider: panel.currentProvider)
                            Text("Current")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        Text(panel.currentLabel)
                            .font(.headline)
                            .lineLimit(1)

                        Text("\(panel.currentRemainingPercent)% remaining")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            WidgetProviderIconView(provider: panel.recommendedProvider)
                            Text("Best Next")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        Text(panel.recommendedLabel)
                            .font(.headline)
                            .lineLimit(1)

                        Text("\(panel.recommendedRemainingPercent)% available")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No live profiles yet")
                        .font(.headline)

                    Text(self.entry.projection.emptyStateText ?? "Add a Codex or Claude profile in QuotaPilot Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Text(self.entry.projection.lastRefreshText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct QuotaPilotWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuotaPilotWidget", provider: QuotaPilotProvider()) { entry in
            QuotaPilotWidgetView(entry: entry)
        }
        .configurationDisplayName("QuotaPilot")
        .description("Shows the current active account and the best next option.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
