import AppKit
import SwiftUI

@MainActor
final class DashboardWindowController {
    private var windowController: NSWindowController?

    func show(model: AppModel) {
        let controller = self.windowController ?? self.makeWindowController(model: model)
        self.windowController = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindowController(model: AppModel) -> NSWindowController {
        let hostingController = NSHostingController(
            rootView: DashboardView(model: model)
                .frame(minWidth: 960, minHeight: 600)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "QuotaPilot"
        window.minSize = NSSize(width: 960, height: 600)
        window.setContentSize(NSSize(width: 960, height: 600))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setFrameAutosaveName("dashboard")
        window.isReleasedWhenClosed = false
        return NSWindowController(window: window)
    }
}
