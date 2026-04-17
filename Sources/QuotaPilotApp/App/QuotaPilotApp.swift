import SwiftUI

@main
struct QuotaPilotApp: App {
    @State private var model = AppModel()
    @NSApplicationDelegateAdaptor(QuotaPilotAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("QuotaPilot", id: "dashboard") {
            DashboardView(model: self.model)
                .frame(minWidth: 960, minHeight: 600)
        }

        MenuBarExtra("QuotaPilot", systemImage: "gauge.with.dots.needle.67percent") {
            StatusMenuView(model: self.model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            VStack(alignment: .leading, spacing: 10) {
                Text("QuotaPilot")
                    .font(.title2.weight(.semibold))
                Text("Settings and live provider configuration arrive in the next slice.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
        }
    }
}
