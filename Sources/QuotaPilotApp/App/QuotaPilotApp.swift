import SwiftUI

@main
struct QuotaPilotApp: App {
    @State private var model = AppModel()
    @NSApplicationDelegateAdaptor(QuotaPilotAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("QuotaPilot", id: "dashboard") {
            DashboardView(model: self.model)
                .frame(minWidth: 960, minHeight: 600)
                .task {
                    await self.model.performInitialLiveRefreshIfNeeded()
                }
        }

        MenuBarExtra("QuotaPilot", systemImage: "gauge.with.dots.needle.67percent") {
            StatusMenuView(model: self.model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            RulesSettingsView(model: self.model)
        }
    }
}
