import Foundation
import AppKit
import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter`. Delivery requires a code-signed
/// app (ux-hig) — in unsigned dev builds this silently no-ops, which is fine
/// because the HUD toast is the primary feedback channel. Notifications add a
/// persistent "Show in Finder" receipt when the app is properly signed.
@MainActor
final class Notifier: NSObject {

    private let center = UNUserNotificationCenter.current()
    private var authorized = false

    private enum ID {
        static let saved = "saved"
        static let showInFinder = "showInFinder"
        static let category = "savedCategory"
        static let pathKey = "filePath"
    }

    override init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    /// Ask contextually (not at launch is ideal, but requesting here is cheap and
    /// the system only prompts once). Guarded so an unsigned build fails quietly.
    func requestAuthorizationIfNeeded() {
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in self?.authorized = granted }
        }
    }

    func notifySaved(name: String, at url: URL) {
        let content = UNMutableNotificationContent()
        content.title = "Saved \(name)"
        content.body = url.deletingLastPathComponent().path
        content.categoryIdentifier = ID.category
        content.userInfo = [ID.pathKey: url.path]

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        center.add(request, withCompletionHandler: nil)
    }

    private func registerCategories() {
        let reveal = UNNotificationAction(identifier: ID.showInFinder,
                                          title: "Show in Finder",
                                          options: [.foreground])
        let category = UNNotificationCategory(identifier: ID.category,
                                              actions: [reveal],
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        if let path = info[ID.pathKey] as? String {
            let url = URL(fileURLWithPath: path)
            Task { @MainActor in
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }
}
