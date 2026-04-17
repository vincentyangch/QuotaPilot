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
    let providerRecommendations: [RecommendationEngine.ProviderRecommendation]
}

struct QuotaPilotProvider: TimelineProvider {
    private let snapshotStore = QuotaPilotWidgetSnapshotStore()

    func placeholder(in context: Context) -> QuotaPilotEntry {
        let accounts = DemoAccountRepository.makeAccounts()
        let recommendations = RecommendationEngine().recommendationsByProvider(accounts: accounts, rules: .default)

        return QuotaPilotEntry(
            date: .now,
            providerRecommendations: recommendations
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

        let recommendations = RecommendationEngine().recommendationsByProvider(
            accounts: snapshot.accounts,
            rules: snapshot.rules,
            now: snapshot.generatedAt
        )

        guard !recommendations.isEmpty else { return nil }

        return QuotaPilotEntry(
            date: snapshot.generatedAt,
            providerRecommendations: recommendations
        )
    }
}

struct QuotaPilotWidgetView: View {
    let entry: QuotaPilotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Best Accounts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(self.entry.providerRecommendations) { recommendation in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        WidgetProviderIconView(provider: recommendation.provider)
                        Text(recommendation.provider.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Text(recommendation.recommendedAccount?.label ?? "Unavailable")
                        .font(.headline)
                        .lineLimit(1)

                    Text("\(recommendation.recommendedAccount?.primaryRemainingPercent ?? 0)% remaining")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
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
