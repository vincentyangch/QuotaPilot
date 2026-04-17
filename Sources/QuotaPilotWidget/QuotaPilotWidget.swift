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
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QuotaPilot")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if self.entry.projection.providerPanels.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No live profiles yet")
                        .font(.headline)

                    Text(self.entry.projection.emptyStateText ?? "Add a Codex or Claude profile in QuotaPilot Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(self.entry.projection.providerPanels.prefix(self.family == .systemSmall ? 1 : 2), id: \.provider) { panel in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            WidgetProviderIconView(provider: panel.provider)
                            Text(panel.provider.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            if panel.showsWarning {
                                Text("Low")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }

                        Text("Current: \(panel.currentLabel)")
                            .font(.caption)
                            .lineLimit(1)

                        Text("Best: \(panel.recommendedLabel)")
                            .font(.headline)
                            .lineLimit(1)

                        Text("\(panel.currentRemainingPercent)% now • \(panel.recommendedRemainingPercent)% best")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)

                        Text(panel.statusText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
        .description("Shows the currently recommended account.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
