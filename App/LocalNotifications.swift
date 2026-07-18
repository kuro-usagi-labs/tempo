import Foundation
import UserNotifications

@MainActor
enum LocalNotifications {
    static func removeAll() { UNUserNotificationCenter.current().removeAllPendingNotificationRequests() }
    static func removeDailyPlan() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: (0..<7).map { "tempo.daily-plan.\($0)" } + ["tempo.daily-plan"]) }
    static func requestAndScheduleDailyPlan(hour: Int = 9) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }
        let remindLater = UNNotificationAction(identifier: "TEMPO_REMIND_LATER", title: "Ingatkan nanti")
        let skipToday = UNNotificationAction(identifier: "TEMPO_SKIP_TODAY", title: "Lewati hari ini")
        center.setNotificationCategories([UNNotificationCategory(identifier: "DAILY_PLAN", actions: [remindLater, skipToday], intentIdentifiers: [])])
        removeDailyPlan()
        let safeHour = min(21, max(8, hour))
        let calendar = Calendar.current
        let startOffset = calendar.component(.hour, from: .now) >= safeHour ? 1 : 0
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset + startOffset, to: .now) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = safeHour
            components.minute = 0
            let content = UNMutableNotificationContent()
            content.title = "TEMPO"
            content.body = offset == 6 ? "Tinjauan mingguanmu sudah siap." : "Rencana hari ini sudah siap."
            content.sound = .default
            content.categoryIdentifier = "DAILY_PLAN"
            let request = UNNotificationRequest(identifier: "tempo.daily-plan.\(offset)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }
}
