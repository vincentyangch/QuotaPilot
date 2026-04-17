import Foundation
import QuotaPilotCore
import UserNotifications

@MainActor
protocol RecommendationAlertNotifying {
    func deliver(_ candidate: RecommendationAlertCandidate) async -> Bool
}

@MainActor
struct UserNotificationRecommendationAlertNotifier: RecommendationAlertNotifying {
    func deliver(_ candidate: RecommendationAlertCandidate) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let authorizationStatus = await self.authorizationStatus(for: center)

        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined:
            let granted = await self.requestAuthorization(for: center)
            guard granted else { return false }
        default:
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = candidate.title
        content.body = candidate.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: candidate.identifier,
            content: content,
            trigger: nil
        )

        return await self.add(request: request, to: center)
    }

    private func authorizationStatus(for center: UNUserNotificationCenter) async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func requestAuthorization(for center: UNUserNotificationCenter) async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func add(request: UNNotificationRequest, to center: UNUserNotificationCenter) async -> Bool {
        await withCheckedContinuation { continuation in
            center.add(request) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }
}
