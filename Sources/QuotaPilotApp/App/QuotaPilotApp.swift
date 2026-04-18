import AppKit
import SwiftUI

@main
struct QuotaPilotApp: App {
    @State private var model = AppModel()
    @State private var dashboardWindowController = DashboardWindowController()
    @NSApplicationDelegateAdaptor(QuotaPilotAppDelegate.self) private var appDelegate

    var body: some Scene {
        let _ = self.appDelegate.registerOnDidFinishLaunching {
            Task {
                await self.model.startAppServicesIfNeeded()
            }
            if self.model.startupBehavior.opensDashboardOnLaunch {
                self.dashboardWindowController.show(model: self.model)
            }
        }

        MenuBarExtra("QuotaPilot", systemImage: "gauge.with.dots.needle.67percent") {
            StatusMenuView(model: self.model) {
                self.dashboardWindowController.show(model: self.model)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            RulesSettingsView(model: self.model)
        }
    }
}
