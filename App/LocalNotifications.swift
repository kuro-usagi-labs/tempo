import Foundation
import UserNotifications

@MainActor
enum LocalNotifications {
    static func removeAll() { UNUserNotificationCenter.current().removeAllPendingNotificationRequests() }
    static func requestAndScheduleDailyPlan() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["tempo.daily-plan"])
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "TEMPO"
        content.body = "Rencana hari ini sudah siap."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "tempo.daily-plan", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
        try? await center.add(request)
    }
}
