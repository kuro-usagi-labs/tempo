import SwiftUI
import UIKit
import UserNotifications

final class TempoAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let soundEnabled = UserDefaults.standard.bool(forKey: "notificationSoundsEnabled")
        Task { @MainActor in
            await LocalNotifications.handle(actionIdentifier: response.actionIdentifier, soundEnabled: soundEnabled)
            completionHandler()
        }
    }
}

@main
struct TempoApp: App {
    @UIApplicationDelegateAdaptor(TempoAppDelegate.self) private var appDelegate
    @State private var history = LocalHistory()
    var body: some Scene { WindowGroup { RootView().environment(history).preferredColorScheme(.dark) } }
}
