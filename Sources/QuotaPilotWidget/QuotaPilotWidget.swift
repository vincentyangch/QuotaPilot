import SwiftUI
import WidgetKit
import QuotaPilotCore

struct QuotaPilotEntry: TimelineEntry {
    let date: Date
    let providerRecommendations: [RecommendationEngine.ProviderRecommendation]
}

struct QuotaPilotProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuotaPilotEntry {
        let accounts = DemoAccountRepository.makeAccounts()
        let recommendations = RecommendationEngine().recommendationsByProvider(accounts: accounts, rules: .default)

        return QuotaPilotEntry(
            date: .now,
            providerRecommendations: recommendations
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (QuotaPilotEntry) -> Void) {
        completion(self.placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaPilotEntry>) -> Void) {
        let entry = self.placeholder(in: context)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
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
                    Text(recommendation.provider.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

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
