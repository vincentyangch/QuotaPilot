import SwiftUI
import WidgetKit
import QuotaPilotCore

struct QuotaPilotEntry: TimelineEntry {
    let date: Date
    let decision: RecommendationDecision
    let recommendedAccount: QuotaAccount?
}

struct QuotaPilotProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuotaPilotEntry {
        let accounts = DemoAccountRepository.makeAccounts()
        let decision = RecommendationEngine().evaluate(accounts: accounts, rules: .default)

        return QuotaPilotEntry(
            date: .now,
            decision: decision,
            recommendedAccount: accounts.first(where: { $0.id == decision.recommendedAccountID })
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Best Next Account")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(self.entry.recommendedAccount?.label ?? "Unavailable")
                .font(.headline)
                .lineLimit(2)

            Text("\(self.entry.recommendedAccount?.primaryRemainingPercent ?? 0)% remaining")
                .font(.title3.bold())
                .foregroundStyle(.tint)

            Text(self.entry.decision.action == .recommendSwitch ? "Switch suggested" : "Stay on current")
                .font(.caption)
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
