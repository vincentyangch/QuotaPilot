import AppKit
import UserNotifications

final class QuotaPilotAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var didFinishLaunching = false
    var onDidFinishLaunching: (() -> Void)?

    func registerOnDidFinishLaunching(_ handler: @escaping () -> Void) {
        self.onDidFinishLaunching = handler
        if self.didFinishLaunching {
            handler()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.didFinishLaunching = true
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        UNUserNotificationCenter.current().delegate = self
        self.onDidFinishLaunching?()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
