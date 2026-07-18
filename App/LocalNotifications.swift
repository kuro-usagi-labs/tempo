import Foundation
import UserNotifications

@MainActor
enum LocalNotifications {
    static func removeAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    static func removeDailyPlan() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: (0..<7).map { "tempo.daily-plan.\($0)" } + ["tempo.daily-plan"]) }
    static func requestAndScheduleDailyPlan(hour: Int = 9, soundEnabled: Bool = false) async {
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
            content.sound = soundEnabled ? .default : nil
            content.categoryIdentifier = "DAILY_PLAN"
            let request = UNNotificationRequest(identifier: "tempo.daily-plan.\(offset)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }

    static func handle(actionIdentifier: String, soundEnabled: Bool) async {
        guard actionIdentifier == "TEMPO_REMIND_LATER" else { return }
        let content = UNMutableNotificationContent()
        content.title = "TEMPO"
        content.body = "Rencana hari ini masih tersedia."
        content.sound = soundEnabled ? .default : nil
        content.categoryIdentifier = "DAILY_PLAN"
        let calendar = Calendar.current
        let proposed = Date.now.addingTimeInterval(3_600)
        let fireDate: Date
        if calendar.component(.hour, from: proposed) >= 22 || calendar.component(.hour, from: proposed) < 8 {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: .now) ?? proposed
            fireDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: nextDay) ?? proposed
        } else {
            fireDate = proposed
        }
        let delay = max(60, fireDate.timeIntervalSinceNow)
        let request = UNNotificationRequest(identifier: "tempo.remind-later", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
    }
}
