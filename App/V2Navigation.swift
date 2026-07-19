import SwiftUI
import Observation

enum TempoTab: Hashable {
    case today
    case program
    case progress
    case profile
}

enum TempoRoute: Hashable {
    case plan(UUID)
    case immediateAction(Int)
    case guided(UUID?)
    case privateSession([ImmediateActionAdvisory])
    case guidedUnavailable(GuidedEligibilityReason, String, Date?)
    case cardio(UUID?)
    case strength(UUID?)
    case breathing(UUID?, String, Int)
    case lesson(UUID?, String)
    case healthCheck
    case weeklyReview
}

@Observable
@MainActor
final class TempoCoordinator {
    var selectedTab: TempoTab = .today
    var path: [TempoRoute] = []

    func open(_ route: TempoRoute, tab: TempoTab? = nil) {
        if let tab { selectedTab = tab }
        path.append(route)
    }

    func popToRoot() { path.removeAll() }
}

struct TempoV2AppShell: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(LocalHistory.self) private var history
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false
    @AppStorage("dailyPlanRemindersEnabled") private var remindersEnabled = false
    @AppStorage("dailyPlanReminderHour") private var reminderHour = 9
    @AppStorage("notificationSoundsEnabled") private var notificationSoundsEnabled = false
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var coordinator = TempoCoordinator()
    @State private var privacyCovered = false
    @State private var isUnlocked = false
    @AccessibilityFocusState private var unlockFocused: Bool

    private var isLocked: Bool { onboardingCompleted && biometricLockEnabled && !isUnlocked }

    var body: some View {
        @Bindable var coordinator = coordinator
        ZStack {
            Group {
                if onboardingCompleted, history.baseline != nil {
                    NavigationStack(path: $coordinator.path) {
                        TabView(selection: $coordinator.selectedTab) {
                            TempoTodayScreen().tag(TempoTab.today)
                                .tabItem { Label("Hari Ini", systemImage: "sparkles") }
                            TempoProgramScreen().tag(TempoTab.program)
                                .tabItem { Label("Program", systemImage: "calendar") }
                            TempoProgressScreen().tag(TempoTab.progress)
                                .tabItem { Label("Progres", systemImage: "chart.line.uptrend.xyaxis") }
                            TempoProfileScreen().tag(TempoTab.profile)
                                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                        }
                        .tint(TempoDesign.Palette.accent)
                        .navigationDestination(for: TempoRoute.self) { TempoRouteDestination(route: $0) }
                    }
                } else {
                    TempoV2Onboarding()
                }
            }
            .environment(coordinator)
            .allowsHitTesting(!isLocked && !privacyCovered)
            .accessibilityHidden(isLocked || privacyCovered)

            if isLocked && !privacyCovered { unlockCover }
            if privacyCovered { privateCover }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
        .onChange(of: biometricLockEnabled) { _, enabled in
            if enabled && scenePhase == .active { isUnlocked = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tempoSkipTodayPlan)) { _ in
            history.applyPendingPlanActions()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tempoPlanDidChange)) { _ in
            guard remindersEnabled else {
                LocalNotifications.removeDailyPlan()
                return
            }
            Task {
                await LocalNotifications.requestAndSyncPlan(
                    history.upcomingPlan,
                    fallbackHour: reminderHour,
                    windowEndHour: history.baseline?.reminderEndHour ?? 21,
                    soundEnabled: notificationSoundsEnabled
                )
            }
        }
    }

    private var unlockCover: some View {
        VStack(spacing: TempoDesign.Spacing.lg) {
            Image(systemName: "lock.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(TempoDesign.Palette.accentSoft)
            Text("TEMPO terkunci").font(TempoDesign.Typography.pageTitle)
            Text("Gunakan biometrik atau kode perangkat untuk kembali.")
                .font(TempoDesign.Typography.supporting)
                .foregroundStyle(TempoDesign.Palette.textSecondary)
                .multilineTextAlignment(.center)
            TempoPrimaryButton("Buka", icon: "faceid") {
                Task { isUnlocked = await PrivacyLock.authenticate() }
            }
            .accessibilityFocused($unlockFocused)
        }
        .padding(TempoDesign.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TempoDesign.Palette.canvas.ignoresSafeArea())
        .onAppear { unlockFocused = true }
    }

    private var privateCover: some View {
        ZStack {
            TempoDesign.Palette.canvas.ignoresSafeArea()
            VStack(spacing: TempoDesign.Spacing.sm) {
                Image(systemName: "circle.fill").font(.system(size: 30)).foregroundStyle(TempoDesign.Palette.accent)
                Text("TEMPO").font(TempoDesign.Typography.cardTitle)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Layar privat TEMPO")
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        if phase != .active {
            privacyCovered = true
            if biometricLockEnabled { isUnlocked = false }
            return
        }
        privacyCovered = false
        _ = history.refreshPlan()
        history.applyPendingPlanActions()
        if biometricLockEnabled && !PrivacyLock.isAvailable {
            biometricLockEnabled = false
            isUnlocked = true
        }
        if remindersEnabled {
            Task { await LocalNotifications.requestAndSyncPlan(history.upcomingPlan, fallbackHour: reminderHour, windowEndHour: history.baseline?.reminderEndHour ?? 21, soundEnabled: notificationSoundsEnabled) }
        }
    }
}

struct TempoRouteDestination: View {
    let route: TempoRoute

    @ViewBuilder
    var body: some View {
        switch route {
        case let .plan(id): TempoPlanDetailScreen(planID: id)
        case let .immediateAction(initialIntensity): TempoImmediateActionScreen(initialIntensity: initialIntensity)
        case let .guided(id): TempoGuidedSessionScreen(plannedDayID: id)
        case let .privateSession(advisories): TempoPrivateSessionTimerScreen(advisories: advisories)
        case let .guidedUnavailable(reason, message, nextAvailableAt):
            TempoGuidedUnavailableScreen(reason: reason, message: message, nextAvailableAt: nextAvailableAt)
        case let .cardio(id): TempoCardioSessionScreen(plannedDayID: id)
        case let .strength(id): TempoStrengthCircuitScreen(plannedDayID: id)
        case let .breathing(id, title, seconds): TempoBreathingSessionScreen(plannedDayID: id, title: title, duration: seconds)
        case let .lesson(id, topic): TempoLessonScreen(plannedDayID: id, topic: topic)
        case .healthCheck: TempoHealthCheckScreen()
        case .weeklyReview: TempoWeeklyReviewScreen()
        }
    }
}
