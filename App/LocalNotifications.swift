import Foundation
import UserNotifications

extension Notification.Name {
    static let tempoSkipTodayPlan = Notification.Name("tempo.skip-today-plan")
    static let tempoPlanDidChange = Notification.Name("tempo.plan-did-change")
}

/// Keeps cancellation deterministic across plan mutations, including older
/// reminder identifiers that may have been created by a previous app version.
/// This stays independent from `UserNotifications` so its retention policy is
/// directly covered by unit tests.
enum LocalNotificationPlanSync {
    static let legacyRequestIdentifiers = Set(
        (0..<7).map { "tempo.daily-plan.\($0)" } + [
            "tempo.daily-plan",
            "tempo.remind-later"
        ]
    )

    static func cancellationRequestIdentifiers(indexed: [String]) -> [String] {
        Array(legacyRequestIdentifiers.union(indexed)).sorted()
    }
}

@MainActor
enum LocalNotifications {
    private static let planRequestIndexKey = "tempo.plan-reminder-index.v2"
    static func removeAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UserDefaults.standard.removeObject(forKey: planRequestIndexKey)
    }
    static func removeDailyPlan() {
        let indexed = UserDefaults.standard.stringArray(forKey: planRequestIndexKey) ?? []
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: LocalNotificationPlanSync.cancellationRequestIdentifiers(indexed: indexed)
        )
        UserDefaults.standard.removeObject(forKey: planRequestIndexKey)
    }
    static func requestAndScheduleDailyPlan(hour: Int = 9, soundEnabled: Bool = false) async {
        let center = UNUserNotificationCenter.current()
        // Remove an old schedule even if the permission request is declined or
        // has since been revoked, so a stale plan can never keep notifying.
        removeDailyPlan()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }
        let remindLater = UNNotificationAction(identifier: "TEMPO_REMIND_LATER", title: "Ingatkan nanti")
        let skipToday = UNNotificationAction(identifier: "TEMPO_SKIP_TODAY", title: "Lewati hari ini")
        center.setNotificationCategories([UNNotificationCategory(identifier: "DAILY_PLAN", actions: [remindLater, skipToday], intentIdentifiers: [])])
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

    /// Syncs neutral local reminders with persisted plan items. Stable item IDs
    /// deduplicate a reschedule and stale requests are explicitly cancelled.
    static func requestAndSyncPlan(_ plan: [LocalPlanDay], fallbackHour: Int = 9, windowEndHour: Int = 21, soundEnabled: Bool = false) async {
        let center = UNUserNotificationCenter.current()
        let previous = UserDefaults.standard.stringArray(forKey: planRequestIndexKey) ?? []
        // Cancellation intentionally precedes authorization. If notifications
        // are later denied, changed, skipped, or adapted items must not leave
        // their previous reminder behind.
        center.removePendingNotificationRequests(
            withIdentifiers: LocalNotificationPlanSync.cancellationRequestIdentifiers(indexed: previous)
        )
        UserDefaults.standard.removeObject(forKey: planRequestIndexKey)
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }
        let remindLater = UNNotificationAction(identifier: "TEMPO_REMIND_LATER", title: "Ingatkan nanti")
        let skipToday = UNNotificationAction(identifier: "TEMPO_SKIP_TODAY", title: "Lewati hari ini")
        center.setNotificationCategories([UNNotificationCategory(identifier: "DAILY_PLAN", actions: [remindLater, skipToday], intentIdentifiers: [])])

        let calendar = Calendar.current
        let startHour = min(21, max(8, fallbackHour))
        let endHour = min(22, max(startHour, windowEndHour))
        let upcoming = plan
            .filter { $0.status.isActionable && $0.status != .recovery && $0.scheduleDate > .now }
            .sorted { $0.scheduleDate < $1.scheduleDate }
        var requestIDs: [String] = []
        for item in upcoming {
            let scheduled = item.scheduledAt ?? calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: item.date) ?? item.date
            let hour = calendar.component(.hour, from: scheduled)
            let fireDate: Date
            if hour < startHour || hour > endHour {
                fireDate = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: scheduled) ?? scheduled
            } else {
                fireDate = scheduled
            }
            guard fireDate > .now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "TEMPO"
            content.body = item.kind == .review ? "Tinjauan privatmu tersedia." : "Langkah privatmu tersedia saat kamu siap."
            content.sound = soundEnabled ? .default : nil
            content.categoryIdentifier = "DAILY_PLAN"
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let identifier = "tempo.plan.\(item.id.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do {
                try await center.add(request)
                requestIDs.append(identifier)
            } catch {
                continue
            }
        }
        UserDefaults.standard.set(requestIDs, forKey: planRequestIndexKey)
    }

    static func handle(actionIdentifier: String, soundEnabled: Bool) async {
        if actionIdentifier == "TEMPO_SKIP_TODAY" {
            UserDefaults.standard.set(Date.now, forKey: "tempo.pending-skip-plan-date")
            NotificationCenter.default.post(name: .tempoSkipTodayPlan, object: nil)
            return
        }
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
