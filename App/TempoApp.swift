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
    @State private var history: LocalHistory

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-tempo-ui-testing-reset") {
            _ = ProtectedFileStore.removeAll()
            _ = SecureLocalStore.removeAll()
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
        }
        let localHistory = LocalHistory()
        if arguments.contains("-tempo-ui-testing-multiple-safety-holds") {
            let baseline = LocalBaseline(
                completedAt: .now,
                onset: "Bertahap",
                difficultyContext: "Keduanya",
                perceivedControl: 5,
                anxiety: 5,
                sleepHours: 7,
                activityLevel: "Ringan",
                weeklyMovementMinutes: 60,
                canWalkTwentyMinutes: true,
                hasExerciseRestriction: false,
                hasSafeActivitySpace: true,
                preferredActivity: ActivityPreference.walking.legacyDisplayValue,
                activityPreference: .walking,
                rushedHabit: false,
                highStimulusPattern: false,
                hasSafetySymptoms: false,
                rulesetVersion: RulesetVersion.current.rawValue,
                adultConfirmed: true
            )
            _ = localHistory.saveBaseline(baseline)
            _ = localHistory.recordSafetyHold(
                reasonCode: "safety.daily-readiness-pain",
                severity: RecommendationSeverity.medical.rawValue,
                source: "ui-test"
            )
            _ = localHistory.recordSafetyHold(
                reasonCode: "safety.daily-readiness-urinary-discharge",
                severity: RecommendationSeverity.medical.rawValue,
                source: "ui-test"
            )
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        }
        _history = State(initialValue: localHistory)
    }

    var body: some Scene { WindowGroup { TempoV2AppShell().environment(history).preferredColorScheme(.dark) } }
}
