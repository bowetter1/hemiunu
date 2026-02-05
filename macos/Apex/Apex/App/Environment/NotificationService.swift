import Foundation
import UserNotifications
import AppKit

/// Handles macOS native notifications for generation events.
/// Implements UNUserNotificationCenterDelegate to allow banners even when the app is active.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private override init() {
        super.init()
    }

    /// Request notification permissions and register as delegate
    func requestPermission() {
        guard Bundle.main.bundleIdentifier != nil else {
            print("[Notify] Skipping — no bundle identifier available")
            return
        }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("[Notify] Permission granted: \(granted), error: \(String(describing: error))")
        }
    }

    /// Send a notification (works both in foreground and background)
    func notify(title: String, body: String, id: String = UUID().uuidString) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        print("[Notify] Sending: \(title) – \(body)")

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notify] Error adding notification: \(error)")
            } else {
                print("[Notify] Notification added successfully: \(title)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Allow notifications to display as banners even when the app is in the foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
