import Foundation
import Observation

struct LocalCheckIn: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let intensity: Int
    let trigger: String
    let intent: String
    let action: String
    let blocksTraining: Bool
}

extension LocalPlanStatus {
    init(_ status: ProgramPlanStatus) {
        switch status {
        case .scheduled: self = .planned
        case .completed: self = .completed
        case .skipped: self = .skipped
        case .adapted: self = .adapted
        case .recovery: self = .recovery
        }
    }
}

private extension ProgramPlanStatus {
    init(_ status: LocalPlanStatus) {
        switch status {
        case .planned: self = .scheduled
        case .completed: self = .completed
        case .skipped: self = .skipped
        case .adapted: self = .adapted
        case .recovery: self = .recovery
        }
    }
}

extension ProgramPlanItem {
    init(localDay: LocalPlanDay) {
        let reasons = (localDay.reasonCodes ?? []).compactMap(PlanReason.init(rawValue:))
        let adaptationReasons = (localDay.adaptationReasonCodes ?? []).compactMap(PlanReason.init(rawValue:))
        let original = localDay.originalKind ?? localDay.kind
        let adaptation: PlanAdaptation?
        if localDay.originalKind != nil || !adaptationReasons.isEmpty {
            adaptation = PlanAdaptation(
                adaptedAt: localDay.adaptedAt ?? localDay.generatedAt,
                originalKind: original,
                replacementKind: localDay.kind,
                reasons: adaptationReasons,
                rescheduledFromID: localDay.rescheduledFromID
            )
        } else {
            adaptation = nil
        }
        let execution = localDay.completedAt.map {
            ProgramActivityExecution(completedAt: $0, performedKind: localDay.performedKind ?? localDay.kind)
        }
        self.init(
            id: localDay.id,
            scheduledAt: localDay.scheduleDate,
            prescribedKind: localDay.originalKind ?? localDay.kind,
            estimatedMinutes: localDay.estimatedMinutes ?? 5,
            phase: localDay.phase,
            reasons: reasons.isEmpty ? [.legacyImported] : reasons,
            rulesetVersion: RulesetVersion(rawValue: localDay.rulesetVersion),
            revision: localDay.revision ?? 1,
            status: ProgramPlanStatus(localDay.status),
            adaptation: adaptation,
            execution: execution
        )
    }
}

struct LocalUrgeOutcome: Codable, Identifiable {
    let id: UUID
    let completedAt: Date
    let initialIntensity: Int
    let finalIntensity: Int
}

struct LocalArousalEvent: Codable {
    let timestampOffset: Int
    let level: Int
    let eventType: String
}

struct LocalPauseCycle: Codable {
    let index: Int
    let startOffset: Int
    let endOffset: Int
    let arousalBefore: Int
    let arousalAfter: Int
    let lateStop: Bool
    let successful: Bool
}

struct LocalSession: Codable, Identifiable {
    let id: UUID
    let startedAt: Date?
    let completedAt: Date
    let cycles: Int
    let terminalState: String
    let targetCycles: Int?
    let pauseThreshold: Int?
    let maximumDurationSeconds: Int?
    let preAnxiety: Int?
    let durationSeconds: Int?
    let lateStopOccurred: Bool?
    let postAnxiety: Int?
    let postTension: Int?
    let painAfter: Bool?
    let irritationAfter: Bool?
    let outcome: String?
    let note: String?
    let arousalEvents: [LocalArousalEvent]?
    let pauseCycles: [LocalPauseCycle]?
    /// `nil` is a migrated V1 guided session. Private sessions are persisted
    /// separately so they never enter guided-session scoring.
    let sessionType: String?
    let activeSeconds: Int?
    let recoverySeconds: Int?
    let rulesetVersion: String?

    init(
        id: UUID,
        startedAt: Date?,
        completedAt: Date,
        cycles: Int,
        terminalState: String,
        targetCycles: Int?,
        pauseThreshold: Int?,
        maximumDurationSeconds: Int?,
        preAnxiety: Int?,
        durationSeconds: Int?,
        lateStopOccurred: Bool?,
        postAnxiety: Int?,
        postTension: Int?,
        painAfter: Bool?,
        irritationAfter: Bool?,
        outcome: String?,
        note: String?,
        arousalEvents: [LocalArousalEvent]?,
        pauseCycles: [LocalPauseCycle]?,
        sessionType: String? = nil,
        activeSeconds: Int? = nil,
        recoverySeconds: Int? = nil,
        rulesetVersion: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.cycles = cycles
        self.terminalState = terminalState
        self.targetCycles = targetCycles
        self.pauseThreshold = pauseThreshold
        self.maximumDurationSeconds = maximumDurationSeconds
        self.preAnxiety = preAnxiety
        self.durationSeconds = durationSeconds
        self.lateStopOccurred = lateStopOccurred
        self.postAnxiety = postAnxiety
        self.postTension = postTension
        self.painAfter = painAfter
        self.irritationAfter = irritationAfter
        self.outcome = outcome
        self.note = note
        self.arousalEvents = arousalEvents
        self.pauseCycles = pauseCycles
        self.sessionType = sessionType
        self.activeSeconds = activeSeconds
        self.recoverySeconds = recoverySeconds
        self.rulesetVersion = rulesetVersion
    }
}

struct LocalPrivateSession: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    let completedAt: Date
    let elapsedSeconds: Int
    let pauseCount: Int
    /// Detail is intentionally optional; users can keep only the recovery marker.
    let outcome: String?
    let note: String?
    let detailWasSaved: Bool
    let rulesetVersion: String
    let activeSeconds: Int?
    let totalRecoverySeconds: Int?
    let manualPauseCount: Int?
    let emergencyPauseCount: Int?
    let completedCycles: Int?
    let terminalState: String?
    let assistanceEnabled: Bool?
    let tooFast: Bool?
    let stoppedIntentionally: Bool?
    let painAfter: Bool?
    let irritationAfter: Bool?

    init(
        id: UUID,
        startedAt: Date,
        completedAt: Date,
        elapsedSeconds: Int,
        pauseCount: Int,
        outcome: String?,
        note: String?,
        detailWasSaved: Bool,
        rulesetVersion: String,
        activeSeconds: Int? = nil,
        totalRecoverySeconds: Int? = nil,
        manualPauseCount: Int? = nil,
        emergencyPauseCount: Int? = nil,
        completedCycles: Int? = nil,
        terminalState: String? = nil,
        assistanceEnabled: Bool? = nil,
        tooFast: Bool? = nil,
        stoppedIntentionally: Bool? = nil,
        painAfter: Bool? = nil,
        irritationAfter: Bool? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.elapsedSeconds = elapsedSeconds
        self.pauseCount = pauseCount
        self.outcome = outcome
        self.note = note
        self.detailWasSaved = detailWasSaved
        self.rulesetVersion = rulesetVersion
        self.activeSeconds = activeSeconds
        self.totalRecoverySeconds = totalRecoverySeconds
        self.manualPauseCount = manualPauseCount
        self.emergencyPauseCount = emergencyPauseCount
        self.completedCycles = completedCycles
        self.terminalState = terminalState
        self.assistanceEnabled = assistanceEnabled
        self.tooFast = tooFast
        self.stoppedIntentionally = stoppedIntentionally
        self.painAfter = painAfter
        self.irritationAfter = irritationAfter
    }
}

struct LocalExerciseLog: Codable, Identifiable {
    let id: UUID
    let completedAt: Date
    let kind: String
    let durationMinutes: Int
    let perceivedDifficulty: Int?
    let painReported: Bool?
    let activityKind: ActivityKind?

    init(id: UUID, completedAt: Date, kind: String, durationMinutes: Int, perceivedDifficulty: Int?, painReported: Bool?, activityKind: ActivityKind? = nil) {
        self.id = id
        self.completedAt = completedAt
        self.kind = kind
        self.durationMinutes = durationMinutes
        self.perceivedDifficulty = perceivedDifficulty
        self.painReported = painReported
        self.activityKind = activityKind
    }
}

enum LocalPlanStatus: String, Codable { case planned, completed, skipped, adapted, recovery
    var isTerminal: Bool { self == .completed || self == .skipped }
    var isActionable: Bool { !isTerminal }
}

struct LocalPlanDay: Codable, Identifiable {
    let id: UUID
    let date: Date
    let kind: ActivityKind
    var status: LocalPlanStatus
    let phase: ProgramPhase
    let generatedAt: Date
    let rulesetVersion: String
    /// V2 keeps the original prescription intact whenever a plan is adapted.
    let originalKind: ActivityKind?
    let scheduledAt: Date?
    let estimatedMinutes: Int?
    let reasonCodes: [String]?
    let adaptationReasonCodes: [String]?
    let adaptedAt: Date?
    let rescheduledFromID: UUID?
    let revision: Int?
    let completedAt: Date?
    let performedKind: ActivityKind?

    init(
        id: UUID,
        date: Date,
        kind: ActivityKind,
        status: LocalPlanStatus,
        phase: ProgramPhase,
        generatedAt: Date,
        rulesetVersion: String,
        originalKind: ActivityKind? = nil,
        scheduledAt: Date? = nil,
        estimatedMinutes: Int? = nil,
        reasonCodes: [String]? = nil,
        adaptationReasonCodes: [String]? = nil,
        adaptedAt: Date? = nil,
        rescheduledFromID: UUID? = nil,
        revision: Int? = nil,
        completedAt: Date? = nil,
        performedKind: ActivityKind? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.status = status
        self.phase = phase
        self.generatedAt = generatedAt
        self.rulesetVersion = rulesetVersion
        self.originalKind = originalKind
        self.scheduledAt = scheduledAt
        self.estimatedMinutes = estimatedMinutes
        self.reasonCodes = reasonCodes
        self.adaptationReasonCodes = adaptationReasonCodes
        self.adaptedAt = adaptedAt
        self.rescheduledFromID = rescheduledFromID
        self.revision = revision
        self.completedAt = completedAt
        self.performedKind = performedKind
    }

    var effectiveKind: ActivityKind { kind }
    var scheduleDate: Date { scheduledAt ?? date }
}

struct LocalBaseline: Codable {
    let completedAt: Date
    let onset: String
    let difficultyContext: String
    let perceivedControl: Int
    let anxiety: Int
    let sleepHours: Int
    let activityLevel: String
    let weeklyMovementMinutes: Int?
    let canWalkTwentyMinutes: Bool?
    let hasExerciseRestriction: Bool?
    let hasSafeActivitySpace: Bool?
    let preferredActivity: String?
    let rushedHabit: Bool
    let highStimulusPattern: Bool
    let hasSafetySymptoms: Bool
    let rulesetVersion: String
    let reminderStartHour: Int?
    let reminderEndHour: Int?
    let adultConfirmed: Bool?

    init(
        completedAt: Date,
        onset: String,
        difficultyContext: String,
        perceivedControl: Int,
        anxiety: Int,
        sleepHours: Int,
        activityLevel: String,
        weeklyMovementMinutes: Int?,
        canWalkTwentyMinutes: Bool?,
        hasExerciseRestriction: Bool?,
        hasSafeActivitySpace: Bool?,
        preferredActivity: String?,
        rushedHabit: Bool,
        highStimulusPattern: Bool,
        hasSafetySymptoms: Bool,
        rulesetVersion: String,
        reminderStartHour: Int? = nil,
        reminderEndHour: Int? = nil,
        adultConfirmed: Bool? = nil
    ) {
        self.completedAt = completedAt
        self.onset = onset
        self.difficultyContext = difficultyContext
        self.perceivedControl = perceivedControl
        self.anxiety = anxiety
        self.sleepHours = sleepHours
        self.activityLevel = activityLevel
        self.weeklyMovementMinutes = weeklyMovementMinutes
        self.canWalkTwentyMinutes = canWalkTwentyMinutes
        self.hasExerciseRestriction = hasExerciseRestriction
        self.hasSafeActivitySpace = hasSafeActivitySpace
        self.preferredActivity = preferredActivity
        self.rushedHabit = rushedHabit
        self.highStimulusPattern = highStimulusPattern
        self.hasSafetySymptoms = hasSafetySymptoms
        self.rulesetVersion = rulesetVersion
        self.reminderStartHour = reminderStartHour
        self.reminderEndHour = reminderEndHour
        self.adultConfirmed = adultConfirmed
    }
}

struct LocalSafetyHold: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let reasonCode: String
    let severity: String
    let source: String
    let recheckNotBefore: Date?
    var resolvedAt: Date?
}

private struct LocalProfileState: Codable {
    var schemaVersion = 2
    var baseline: LocalBaseline?
    var safetyHolds: [LocalSafetyHold] = []
    var programPhase: ProgramPhase = .awareness
}

private struct LocalExportSnapshot: Codable {
    let exportedAt: Date
    let rulesetVersion: String
    let profile: LocalProfileState
    let checkIns: [LocalCheckIn]
    let urgeOutcomes: [LocalUrgeOutcome]
    let sessions: [LocalSession]
    let privateSessions: [LocalPrivateSession]
    let exercises: [LocalExerciseLog]
    let plan: [LocalPlanDay]
}

@Observable
@MainActor
final class LocalHistory {
    private(set) var checkIns: [LocalCheckIn] = []
    private(set) var urgeOutcomes: [LocalUrgeOutcome] = []
    private(set) var sessions: [LocalSession] = []
    private(set) var privateSessions: [LocalPrivateSession] = []
    private(set) var exercises: [LocalExerciseLog] = []
    private(set) var plannedDays: [LocalPlanDay] = []
    private var profile = LocalProfileState()
    private(set) var hasPendingSafetyWrite = false
    private let storageKey = "tempo.local.checkins.v1"
    private let sessionStorageKey = "tempo.local.sessions.v1"
    private let urgeOutcomeStorageKey = "tempo.local.urge-outcomes.v1"
    private let profileStorageKey = "tempo.local.profile.v1"
    private let exerciseStorageKey = "tempo.local.exercises.v1"
    private let planStorageKey = "tempo.local.plan.v1"
    private let privateSessionStorageKey = "tempo.local.private-sessions.v2"
    private let pendingSafetyStorageKey = "tempo.pending-safety-lock.v1"
    private let planRepository = LocalPlanRepository()
    private let privateSessionRepository = LocalPrivateSessionRepository()

    var baseline: LocalBaseline? { profile.baseline }
    var safetyHoldCount: Int { profile.safetyHolds.count }
    var activeSafetyHold: LocalSafetyHold? { profile.safetyHolds.last { $0.resolvedAt == nil } }
    var hasSafetyBlock: Bool { activeSafetyHold != nil || hasPendingSafetyWrite }
    var currentWeekPlan: [LocalPlanDay] {
        let start = weekStart(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        return plannedDays.filter { $0.date >= start && $0.date < end }.sorted { $0.date < $1.date }
    }
    var upcomingPlan: [LocalPlanDay] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 14, to: start) ?? start
        return plannedDays.filter { $0.scheduleDate >= start && $0.scheduleDate < end }.sorted { $0.scheduleDate < $1.scheduleDate }
    }
    var todayPrimaryPlan: LocalPlanDay? {
        let calendar = Calendar.current
        let items = plannedDays.filter { calendar.isDateInToday($0.scheduleDate) }
        return items.sorted { lhs, rhs in
            let lhsActionable = lhs.status.isActionable
            let rhsActionable = rhs.status.isActionable
            if lhsActionable != rhsActionable { return lhsActionable }
            let lhsIncomplete = lhs.status != .completed && lhs.status != .skipped
            let rhsIncomplete = rhs.status != .completed && rhs.status != .skipped
            if lhsIncomplete != rhsIncomplete { return lhsIncomplete }
            let lhsDistance = abs(lhs.scheduleDate.timeIntervalSinceNow)
            let rhsDistance = abs(rhs.scheduleDate.timeIntervalSinceNow)
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            let lhsRescheduled = lhs.rescheduledFromID != nil
            let rhsRescheduled = rhs.rescheduledFromID != nil
            if lhsRescheduled != rhsRescheduled { return lhsRescheduled }
            return lhs.scheduleDate < rhs.scheduleDate
        }.first
    }
    var todayPlan: LocalPlanDay? { todayPrimaryPlan }
    var tomorrowPlan: LocalPlanDay? {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) else { return nil }
        return upcomingPlan.first { Calendar.current.isDate($0.scheduleDate, inSameDayAs: tomorrow) }
    }
    var programContext: ProgramContext {
        ProgramContext(
            phase: effectiveProgramPhase,
            baselineCompleted: baseline != nil,
            anxiety: Int((currentAnxiety ?? Double(baseline?.anxiety ?? 5)).rounded()),
            sleepHours: baseline.map { Double($0.sleepHours) },
            exerciseRestricted: baseline?.hasExerciseRestriction == true,
            canWalkTwentyMinutes: baseline?.canWalkTwentyMinutes ?? true,
            hasSafeActivitySpace: baseline?.hasSafeActivitySpace ?? true,
            rushedHabit: baseline?.rushedHabit ?? false,
            highStimulusPattern: baseline?.highStimulusPattern ?? false,
            hasSafetyHold: hasSafetyBlock,
            hoursSinceLastGuidedSession: hoursSinceLastSession,
            hoursSinceLastPrivateSession: hoursSinceLastPrivateSession,
            guidedSessionsLast7Days: guidedSessionsLast7Days,
            lateStopsLast3Sessions: lateStopsLast3Sessions,
            perceivedControl: baseline?.perceivedControl,
            weeklyMovementMinutes: baseline?.weeklyMovementMinutes,
            activityLevel: baseline?.activityLevel,
            preferredActivity: baseline?.preferredActivity,
            programWeek: max(1, programWeek)
        )
    }
    var guidedEligibility: GuidedEligibility {
        EligibilityEngine().guidedEligibility(for: programContext)
    }
    func guidedEligibility(at date: Date) -> GuidedEligibility {
        var context = programContext
        context.hoursSinceLastGuidedSession = projectedHours(since: trainingSessions.map(\.completedAt), at: date)
        context.hoursSinceLastPrivateSession = projectedHours(since: privateSessions.map(\.completedAt), at: date)
        let cutoff = date.addingTimeInterval(-7 * 86_400)
        context.guidedSessionsLast7Days = trainingSessions.filter { $0.completedAt >= cutoff && $0.completedAt < date }.count
        return EligibilityEngine().guidedEligibility(for: context)
    }
    var guidedNextAvailableAt: Date? {
        switch guidedEligibility.reason {
        case .privateRecoveryWindow:
            return privateSessions.first?.completedAt.addingTimeInterval(24 * 3_600)
        case .recoveryWindow:
            return trainingSessions.first?.completedAt.addingTimeInterval(24 * 3_600 + 1)
        case .weeklyLimit:
            return trainingSessions
                .filter { $0.completedAt >= Date.now.addingTimeInterval(-7 * 86_400) }
                .map { $0.completedAt.addingTimeInterval(7 * 86_400) }
                .min()
        case .ready, .baselineRequired, .safetyHold:
            return nil
        }
    }
    var effectiveProgramPhase: ProgramPhase {
        if hasSafetyBlock { return .safetyHold }
        if baseline == nil { return .assessmentRequired }
        let valid = trainingSessions
        if programWeek <= 2 || valid.count < 3 { return .awareness }
        if programWeek <= 4 || valid.filter({ $0.cycles >= 3 }).count < 2 { return .basicControl }
        if programWeek <= 8 || valid.filter({ $0.cycles >= 2 }).prefix(3).count < 3 { return .stability }
        if programWeek <= 10 { return .transfer }
        return .independence
    }
    var programWeek: Int {
        guard let completedAt = baseline?.completedAt else { return 0 }
        return min(12, max(1, Int(Date.now.timeIntervalSince(completedAt) / (7 * 86_400)) + 1))
    }
    var targetCycles: Int {
        switch effectiveProgramPhase {
        case .awareness, .assessmentRequired, .safetyHold: 2
        case .basicControl: 3
        case .stability, .transfer: 4
        case .independence: 3
        }
    }
    var adaptivePauseThreshold: Int {
        let recent = Array(trainingSessions.prefix(3))
        let lateStops = recent.filter { $0.lateStopOccurred == true }.count
        let earlyBeforePause = recent.filter { $0.terminalState == GuidedSessionState.earlyCompletion.rawValue && $0.cycles == 0 }.count
        return lateStops >= 2 || earlyBeforePause >= 2 ? 6 : 7
    }
    var independenceLevel: Int {
        switch effectiveProgramPhase {
        case .assessmentRequired, .safetyHold, .awareness: 0
        case .basicControl: 1
        case .stability: 2
        case .transfer: 3
        case .independence: 4
        }
    }
    var currentAnxiety: Double? {
        let values = trainingSessions.prefix(5).compactMap(\.postAnxiety)
        guard !values.isEmpty else { return baseline.map { Double($0.anxiety) } }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
    var currentTension: Double? {
        let values = trainingSessions.prefix(5).compactMap(\.postTension)
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
    var isHighStress: Bool { (currentAnxiety ?? Double(baseline?.anxiety ?? 0)) >= 8 }
    var canResolveActiveSafetyHold: Bool {
        guard let hold = activeSafetyHold else { return true }
        guard let notBefore = hold.recheckNotBefore else { return true }
        return Date.now >= notBefore
    }
    var safetyHoldRemainingHours: Int? {
        guard let date = activeSafetyHold?.recheckNotBefore, date > .now else { return nil }
        return max(1, Int(ceil(date.timeIntervalSinceNow / 3_600)))
    }
    var hoursSinceLastSession: Double? { trainingSessions.first.map { Date.now.timeIntervalSince($0.completedAt) / 3_600 } }
    var hoursSinceLastPrivateSession: Double? { privateSessions.first.map { Date.now.timeIntervalSince($0.completedAt) / 3_600 } }
    var guidedSessionsLast7Days: Int { trainingSessions.filter { $0.completedAt >= Date.now.addingTimeInterval(-7 * 86_400) }.count }
    var lateStopsLast3Sessions: Int { trainingSessions.prefix(3).filter { $0.lateStopOccurred == true }.count }
    var sessionPrescription: SessionPrescription { SessionPrescriptionEngine().prescription(for: programContext) }
    var todayPrescription: DailyPrescription {
        let items = upcomingPlan.map(ProgramPlanItem.init(localDay:))
        return DailyRecommendationEngine().prescription(for: .now, items: items, context: programContext)
    }
    var progressPresentation: ProgressPresentationState { ProgressEngine().presentation(sessionCount: trainingSessions.count, scores: scoreSnapshot) }
    private var trainingSessions: [LocalSession] {
        sessions.filter {
            $0.sessionType != "private" && [GuidedSessionState.completed.rawValue, GuidedSessionState.earlyCompletion.rawValue, GuidedSessionState.timeLimitReached.rawValue].contains($0.terminalState)
        }
    }
    var scoreSnapshot: ScoreSnapshot {
        let recent = Array(trainingSessions.prefix(10).reversed())
        func ewma(_ values: [Double], alpha: Double = 0.35) -> Double {
            guard var result = values.first else { return 0 }
            for value in values.dropFirst() { result = alpha * value + (1 - alpha) * result }
            return result
        }
        let completed = ewma(recent.map { $0.terminalState == GuidedSessionState.completed.rawValue ? 1 : 0 })
        let recovered = ewma(recent.map { $0.cycles > 0 ? 1 : 0 })
        let earlyAwareness = ewma(recent.map { $0.cycles > 0 && $0.lateStopOccurred != true ? 1 : 0 })
        let logging = ewma(recent.map { ($0.arousalEvents?.isEmpty == false) ? 1 : 0 })
        let reflection = ewma(recent.map { $0.postTension == nil ? 0 : 1 })
        let thresholdCompliance = ewma(recent.map { $0.lateStopOccurred == true ? 0 : 1 })
        let calmValues = recent.compactMap { session -> Double? in
            guard let before = session.preAnxiety, let after = session.postAnxiety else { return nil }
            return max(0, min(1, 0.5 + Double(before - after) / 10.0))
        }
        let calm = ewma(calmValues)
        let cutoff = Date.now.addingTimeInterval(-7 * 86_400)
        let duePlanItems = plannedDays.filter { $0.scheduleDate >= cutoff && $0.scheduleDate <= .now && $0.status != .recovery }
        let completedPlanItems = duePlanItems.filter { $0.status == .completed }
        let adherenceBase = duePlanItems.isEmpty ? 0 : Double(completedPlanItems.count) / Double(duePlanItems.count)
        return ScoreCalculator().calculate(ScoreInputs(earlyPauseRate: earlyAwareness, loggingCompleteness: logging, tensionRecognitionRate: reflection, escalationPredictionRate: thresholdCompliance, successfulCycleRatio: recovered, controlledCompletionRatio: completed, thresholdCompliance: thresholdCompliance, recoveryCompletionRatio: recovered, calmRate: calm, adherenceRate: adherenceBase))
    }

    func makeExportData() -> Data? {
        try? JSONEncoder().encode(LocalExportSnapshot(exportedAt: .now, rulesetVersion: RuleEngine.rulesetVersion, profile: profile, checkIns: checkIns, urgeOutcomes: urgeOutcomes, sessions: sessions, privateSessions: privateSessions, exercises: exercises, plan: plannedDays))
    }

    init() {
        hasPendingSafetyWrite = UserDefaults.standard.bool(forKey: pendingSafetyStorageKey)
        load()
        migrateLegacyPlanMetadataIfNeeded()
        refreshPlan()
    }

    @discardableResult
    func add(intensity: Int, trigger: UrgeTrigger, intent: UrgeIntent, recommendation: Recommendation) -> Bool {
        if recommendation.blocksGuidedTraining && recommendation.reasonCode.hasPrefix("safety.") {
            guard recordSafetyHold(reasonCode: recommendation.reasonCode, severity: recommendation.severity.rawValue, source: "urge-check-in") else { return false }
        }
        var updated = checkIns
        updated.insert(LocalCheckIn(id: UUID(), createdAt: .now, intensity: intensity, trigger: trigger.rawValue, intent: intent.rawValue, action: recommendation.action.rawValue, blocksTraining: recommendation.blocksGuidedTraining), at: 0)
        updated = Array(updated.prefix(100))
        guard save(updated, for: storageKey) else { return false }
        checkIns = updated
        return true
    }

    @discardableResult
    func addUrgeOutcome(initialIntensity: Int, finalIntensity: Int) -> Bool {
        var updated = urgeOutcomes
        updated.insert(LocalUrgeOutcome(id: UUID(), completedAt: .now, initialIntensity: initialIntensity, finalIntensity: finalIntensity), at: 0)
        updated = Array(updated.prefix(100))
        guard save(updated, for: urgeOutcomeStorageKey) else { return false }
        urgeOutcomes = updated
        return true
    }

    @discardableResult
    func addSession(startedAt: Date? = nil, cycles: Int, terminalState: GuidedSessionState, targetCycles: Int? = nil, pauseThreshold: Int? = nil, maximumDurationSeconds: Int? = nil, preAnxiety: Int? = nil, durationSeconds: Int? = nil, lateStopOccurred: Bool? = nil, postAnxiety: Int? = nil, postTension: Int? = nil, painAfter: Bool? = nil, irritationAfter: Bool? = nil, outcome: String? = nil, note: String? = nil, arousalEvents: [LocalArousalEvent]? = nil, pauseCycles: [LocalPauseCycle]? = nil, activeSeconds: Int? = nil, recoverySeconds: Int? = nil) -> Bool {
        if painAfter == true {
            guard recordSafetyHold(reasonCode: "safety.post-session-pain", severity: RecommendationSeverity.urgent.rawValue, source: "guided-session") else { return false }
        } else if irritationAfter == true {
            guard recordSafetyHold(reasonCode: "safety.post-session-irritation", severity: RecommendationSeverity.caution.rawValue, source: "guided-session") else { return false }
        }
        var updated = sessions
        updated.insert(LocalSession(id: UUID(), startedAt: startedAt, completedAt: .now, cycles: cycles, terminalState: terminalState.rawValue, targetCycles: targetCycles, pauseThreshold: pauseThreshold, maximumDurationSeconds: maximumDurationSeconds, preAnxiety: preAnxiety, durationSeconds: durationSeconds, lateStopOccurred: lateStopOccurred, postAnxiety: postAnxiety, postTension: postTension, painAfter: painAfter, irritationAfter: irritationAfter, outcome: outcome, note: note, arousalEvents: arousalEvents, pauseCycles: pauseCycles, sessionType: "guided", activeSeconds: activeSeconds, recoverySeconds: recoverySeconds, rulesetVersion: RulesetVersion.current.rawValue), at: 0)
        let rawEventCutoff = Date.now.addingTimeInterval(-90 * 86_400)
        updated = updated.map { $0.completedAt < rawEventCutoff ? sessionDroppingRawEvents($0) : $0 }
        updated = Array(updated.prefix(520))
        guard save(updated, for: sessionStorageKey) else { return false }
        sessions = updated
        refreshPlan(force: true)
        return true
    }

    /// Records a private session as a minimal recovery marker. Turning off
    /// details removes outcome and note but still lets the schedule protect recovery.
    @discardableResult
    func addPrivateSession(
        startedAt: Date,
        elapsedSeconds: Int,
        pauseCount: Int,
        outcome: String?,
        note: String?,
        saveDetails: Bool,
        activeSeconds: Int,
        totalRecoverySeconds: Int,
        manualPauseCount: Int,
        emergencyPauseCount: Int,
        completedCycles: Int,
        terminalState: String,
        assistanceEnabled: Bool,
        tooFast: Bool,
        stoppedIntentionally: Bool,
        painAfter: Bool,
        irritationAfter: Bool
    ) -> Bool {
        var updated = privateSessions
        updated.insert(
            LocalPrivateSession(
                id: UUID(), startedAt: startedAt, completedAt: .now,
                elapsedSeconds: max(0, elapsedSeconds), pauseCount: max(0, pauseCount),
                outcome: outcome, note: saveDetails ? note : nil,
                detailWasSaved: saveDetails, rulesetVersion: RulesetVersion.current.rawValue,
                activeSeconds: max(0, activeSeconds), totalRecoverySeconds: max(0, totalRecoverySeconds),
                manualPauseCount: max(0, manualPauseCount), emergencyPauseCount: max(0, emergencyPauseCount),
                completedCycles: max(0, completedCycles), terminalState: terminalState,
                assistanceEnabled: assistanceEnabled, tooFast: tooFast,
                stoppedIntentionally: stoppedIntentionally, painAfter: painAfter,
                irritationAfter: irritationAfter
            ),
            at: 0
        )
        updated = Array(updated.prefix(180))
        guard privateSessionRepository.write(updated) else { return false }
        privateSessions = updated
        return refreshPlan(force: true)
    }

    @discardableResult
    func addExercise(kind: String, activityKind: ActivityKind, durationMinutes: Int, perceivedDifficulty: Int? = nil, painReported: Bool? = nil) -> Bool {
        var updated = exercises
        updated.insert(LocalExerciseLog(id: UUID(), completedAt: .now, kind: kind, durationMinutes: durationMinutes, perceivedDifficulty: perceivedDifficulty, painReported: painReported, activityKind: activityKind), at: 0)
        updated = Array(updated.prefix(100))
        guard save(updated, for: exerciseStorageKey) else { return false }
        exercises = updated
        return true
    }

    func recentExerciseDifficulty(for activityKind: ActivityKind) -> Int? {
        exercises.first { log in
            if let storedKind = log.activityKind { return storedKind == activityKind }
            if activityKind == .strength { return log.kind.localizedCaseInsensitiveContains("kekuatan") }
            if activityKind == .cardio { return !log.kind.localizedCaseInsensitiveContains("kekuatan") }
            return false
        }?.perceivedDifficulty
    }

    @discardableResult
    func saveBaseline(_ baseline: LocalBaseline, safetyReasonCode: String? = nil, safetySeverity: String? = nil) -> Bool {
        var updated = profile
        updated.baseline = baseline
        if baseline.hasSafetySymptoms {
            let reason = safetyReasonCode ?? "safety.baseline"
            let severity = safetySeverity ?? RecommendationSeverity.medical.rawValue
            let notBefore = severity == RecommendationSeverity.caution.rawValue || reason.contains("irritation") ? Date.now.addingTimeInterval(48 * 3_600) : nil
            updated.safetyHolds.append(LocalSafetyHold(id: UUID(), createdAt: .now, reasonCode: reason, severity: severity, source: "baseline", recheckNotBefore: notBefore, resolvedAt: nil))
        }
        guard persistProfile(updated) else {
            if baseline.hasSafetySymptoms { markPendingSafetyWrite() }
            return false
        }
        profile = updated
        if baseline.hasSafetySymptoms { clearPendingSafetyWrite() }
        refreshPlan(force: true)
        return true
    }

    @discardableResult
    func recordSafetyHold(reasonCode: String, severity: String, source: String) -> Bool {
        var updated = profile
        let isIrritation = severity == RecommendationSeverity.caution.rawValue || reasonCode.contains("irritation")
        let notBefore = isIrritation ? Date.now.addingTimeInterval(48 * 3_600) : nil
        if let active = activeSafetyHold, active.reasonCode == reasonCode,
           let index = updated.safetyHolds.firstIndex(where: { $0.id == active.id }) {
            if isIrritation {
                updated.safetyHolds[index] = LocalSafetyHold(id: active.id, createdAt: active.createdAt, reasonCode: active.reasonCode, severity: severity, source: source, recheckNotBefore: notBefore, resolvedAt: nil)
                guard persistProfile(updated) else { markPendingSafetyWrite(); return false }
                profile = updated
                clearPendingSafetyWrite()
                refreshPlan(force: true)
            }
            return true
        }
        updated.safetyHolds.append(LocalSafetyHold(id: UUID(), createdAt: .now, reasonCode: reasonCode, severity: severity, source: source, recheckNotBefore: notBefore, resolvedAt: nil))
        guard persistProfile(updated) else { markPendingSafetyWrite(); return false }
        profile = updated
        clearPendingSafetyWrite()
        refreshPlan(force: true)
        return true
    }

    @discardableResult
    func resolveActiveSafetyHoldAfterClearRecheck() -> Bool {
        if hasPendingSafetyWrite {
            return recordSafetyHold(reasonCode: "safety.pending-write-recovery", severity: RecommendationSeverity.medical.rawValue, source: "recovery")
        }
        guard canResolveActiveSafetyHold else { return false }
        var updated = profile
        let now = Date.now
        if let activeID = activeSafetyHold?.id,
           let index = updated.safetyHolds.firstIndex(where: { $0.id == activeID }) {
            updated.safetyHolds[index].resolvedAt = now
        }
        guard persistProfile(updated) else { return false }
        profile = updated
        refreshPlan(force: true)
        return true
    }

    @discardableResult
    func deleteAll() -> Bool {
        guard ProtectedFileStore.removeAll(), SecureLocalStore.removeAll() else { return false }
        [storageKey, sessionStorageKey, urgeOutcomeStorageKey, profileStorageKey, exerciseStorageKey, planStorageKey, privateSessionStorageKey].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        checkIns = []
        urgeOutcomes = []
        sessions = []
        privateSessions = []
        profile = LocalProfileState()
        exercises = []
        plannedDays = []
        hasPendingSafetyWrite = false
        UserDefaults.standard.removeObject(forKey: pendingSafetyStorageKey)
        return true
    }

    @discardableResult
    func deleteAllNotes() -> Bool {
        let updated = sessions.map { value in
            LocalSession(id: value.id, startedAt: value.startedAt, completedAt: value.completedAt, cycles: value.cycles, terminalState: value.terminalState, targetCycles: value.targetCycles, pauseThreshold: value.pauseThreshold, maximumDurationSeconds: value.maximumDurationSeconds, preAnxiety: value.preAnxiety, durationSeconds: value.durationSeconds, lateStopOccurred: value.lateStopOccurred, postAnxiety: value.postAnxiety, postTension: value.postTension, painAfter: value.painAfter, irritationAfter: value.irritationAfter, outcome: value.outcome, note: nil, arousalEvents: value.arousalEvents, pauseCycles: value.pauseCycles, sessionType: value.sessionType, activeSeconds: value.activeSeconds, recoverySeconds: value.recoverySeconds, rulesetVersion: value.rulesetVersion)
        }
        let updatedPrivate = privateSessions.map { value in
            LocalPrivateSession(
                id: value.id, startedAt: value.startedAt, completedAt: value.completedAt,
                elapsedSeconds: value.elapsedSeconds, pauseCount: value.pauseCount,
                outcome: value.outcome, note: nil, detailWasSaved: value.detailWasSaved,
                rulesetVersion: value.rulesetVersion, activeSeconds: value.activeSeconds,
                totalRecoverySeconds: value.totalRecoverySeconds, manualPauseCount: value.manualPauseCount,
                emergencyPauseCount: value.emergencyPauseCount, completedCycles: value.completedCycles,
                terminalState: value.terminalState, assistanceEnabled: value.assistanceEnabled,
                tooFast: value.tooFast, stoppedIntentionally: value.stoppedIntentionally,
                painAfter: value.painAfter, irritationAfter: value.irritationAfter
            )
        }
        guard privateSessionRepository.write(updatedPrivate) else { return false }
        guard save(updated, for: sessionStorageKey) else { return false }
        sessions = updated
        privateSessions = updatedPrivate
        return true
    }

    @discardableResult
    func refreshPlan(force: Bool = false) -> Bool {
        let calendar = Calendar.current
        let start = weekStart(for: .now)
        let end = calendar.date(byAdding: .day, value: 14, to: start) ?? start
        let existing = plannedDays.filter { $0.scheduleDate >= start && $0.scheduleDate < end }
        let baseExisting = existing.filter { $0.rescheduledFromID == nil }
        let carriedReschedules = existing.filter { $0.rescheduledFromID != nil }
        let scheduleHistory = ProgramScheduleHistory(
            guidedSessionDates: trainingSessions.map(\.completedAt),
            privateSessionDates: privateSessions.map(\.completedAt),
            scheduledGuidedDates: carriedReschedules
                .filter { $0.effectiveKind == .guided && $0.status.isActionable }
                .map(\.scheduleDate)
        )
        let generated = WeeklyPlanGenerator().generate(
            weekStarting: start,
            weeks: 2,
            context: programContext,
            scheduleHistory: scheduleHistory,
            referenceDate: .now,
            calendar: calendar
        )
        let refreshPolicy = PlanRefreshPolicy()
        var updatedWindow = generated.map { item -> LocalPlanDay in
            let day = calendar.startOfDay(for: item.scheduledAt)
            let retained = baseExisting.first { calendar.isDate($0.scheduleDate, inSameDayAs: day) }
            if let retained,
               refreshPolicy.shouldRetainExisting(ProgramPlanItem(localDay: retained), now: .now, force: force) {
                return retained
            }
            return LocalPlanDay(
                id: retained?.id ?? item.id,
                date: day,
                kind: item.effectiveKind,
                status: LocalPlanStatus(item.status),
                phase: item.phase,
                generatedAt: retained?.generatedAt ?? .now,
                rulesetVersion: item.rulesetVersion.rawValue,
                originalKind: item.adaptation?.originalKind ?? retained?.originalKind,
                scheduledAt: item.scheduledAt,
                estimatedMinutes: item.estimatedMinutes,
                reasonCodes: item.reasons.map(\.rawValue),
                adaptationReasonCodes: item.adaptation?.reasons.map(\.rawValue),
                adaptedAt: item.adaptation?.adaptedAt,
                rescheduledFromID: item.adaptation?.rescheduledFromID,
                revision: item.revision,
                completedAt: retained?.completedAt,
                performedKind: retained?.performedKind
            )
        }
        updatedWindow.append(contentsOf: carriedReschedules)
        let today = calendar.startOfDay(for: .now)
        for index in updatedWindow.indices where updatedWindow[index].scheduleDate < today && updatedWindow[index].status.isActionable {
            let current = updatedWindow[index]
            updatedWindow[index] = LocalPlanDay(
                id: current.id, date: current.date, kind: current.kind, status: .skipped, phase: current.phase,
                generatedAt: current.generatedAt, rulesetVersion: current.rulesetVersion, originalKind: current.originalKind,
                scheduledAt: current.scheduledAt, estimatedMinutes: current.estimatedMinutes, reasonCodes: current.reasonCodes,
                adaptationReasonCodes: current.adaptationReasonCodes ?? [PlanReason.missedActivity.rawValue], adaptedAt: current.adaptedAt,
                rescheduledFromID: current.rescheduledFromID, revision: current.revision, completedAt: current.completedAt, performedKind: current.performedKind
            )
        }
        let otherWeeks = plannedDays.filter { $0.scheduleDate < start || $0.scheduleDate >= end }
        let updated = (otherWeeks + updatedWindow).sorted { $0.scheduleDate < $1.scheduleDate }
        guard planRepository.write(updated) else { return false }
        plannedDays = updated
        publishPlanChanged()
        return true
    }

    @discardableResult
    func completePrimaryPlanItem(performedKind: ActivityKind, completedAt: Date = .now) -> Bool {
        guard let item = todayPrimaryPlan else { return false }
        return completePlanItem(id: item.id, performedKind: performedKind, completedAt: completedAt)
    }

    @discardableResult
    func completePlanItem(id: UUID, performedKind: ActivityKind, completedAt: Date = .now) -> Bool {
        let calendar = Calendar.current
        guard let index = plannedDays.firstIndex(where: { $0.id == id }),
              calendar.isDate(plannedDays[index].scheduleDate, inSameDayAs: completedAt),
              plannedDays[index].status.isActionable
        else { return false }
        var updated = plannedDays
        let current = updated[index]
        updated[index] = LocalPlanDay(
            id: current.id,
            date: current.date,
            kind: current.kind,
            status: .completed,
            phase: current.phase,
            generatedAt: current.generatedAt,
            rulesetVersion: current.rulesetVersion,
            originalKind: current.originalKind,
            scheduledAt: current.scheduledAt,
            estimatedMinutes: current.estimatedMinutes,
            reasonCodes: current.reasonCodes,
            adaptationReasonCodes: current.adaptationReasonCodes,
            adaptedAt: current.adaptedAt,
            rescheduledFromID: current.rescheduledFromID,
            revision: current.revision,
            completedAt: completedAt,
            performedKind: performedKind
        )
        guard planRepository.write(updated) else { return false }
        plannedDays = updated
        publishPlanChanged()
        return true
    }

    @discardableResult
    func skipTodayPlan() -> Bool {
        updateTodayPlan(kind: nil, status: .skipped)
    }

    /// Replaces a still-actionable item with recovery while preserving its original prescription and why it changed.
    @discardableResult
    func markPlanUnavailable(id: UUID) -> Bool {
        guard let index = plannedDays.firstIndex(where: { $0.id == id }), plannedDays[index].status.isActionable else { return false }
        var updated = plannedDays
        let current = updated[index]
        updated[index] = LocalPlanDay(
            id: current.id, date: current.date, kind: .recovery, status: .recovery, phase: current.phase,
            generatedAt: current.generatedAt, rulesetVersion: current.rulesetVersion,
            originalKind: current.originalKind ?? current.kind, scheduledAt: current.scheduledAt,
            estimatedMinutes: min(8, current.estimatedMinutes ?? 5), reasonCodes: current.reasonCodes,
            adaptationReasonCodes: [PlanReason.unavailable.rawValue], adaptedAt: .now,
            rescheduledFromID: current.rescheduledFromID, revision: (current.revision ?? 1) + 1,
            completedAt: nil, performedKind: nil
        )
        guard planRepository.write(updated) else { return false }
        plannedDays = updated
        publishPlanChanged()
        return true
    }

    /// Defers an item only to a day that still respects guided-session spacing. The source remains visible as postponed.
    @discardableResult
    func postponePlan(id: UUID) -> Bool {
        guard let index = plannedDays.firstIndex(where: { $0.id == id }), plannedDays[index].status.isActionable else { return false }
        let current = plannedDays[index]
        let domainItems = plannedDays.map(ProgramPlanItem.init(localDay:))
        guard let targetDay = AdaptationPolicy().safeRescheduleDate(for: ProgramPlanItem(localDay: current), after: .now, items: domainItems) else { return false }
        let calendar = Calendar.current
        let originalTime = current.scheduledAt ?? current.date
        let components = calendar.dateComponents([.hour, .minute], from: originalTime)
        let scheduled = calendar.date(bySettingHour: components.hour ?? 18, minute: components.minute ?? 0, second: 0, of: targetDay) ?? targetDay
        var updated = plannedDays
        updated[index] = LocalPlanDay(
            id: current.id, date: current.date, kind: current.kind, status: .skipped, phase: current.phase,
            generatedAt: current.generatedAt, rulesetVersion: current.rulesetVersion, originalKind: current.originalKind,
            scheduledAt: current.scheduledAt, estimatedMinutes: current.estimatedMinutes, reasonCodes: current.reasonCodes,
            adaptationReasonCodes: [PlanReason.postponed.rawValue, PlanReason.safeReschedule.rawValue], adaptedAt: .now,
            rescheduledFromID: current.rescheduledFromID, revision: (current.revision ?? 1) + 1,
            completedAt: nil, performedKind: nil
        )
        updated.append(LocalPlanDay(
            id: UUID(), date: calendar.startOfDay(for: scheduled), kind: current.kind, status: .adapted, phase: current.phase,
            generatedAt: .now, rulesetVersion: RulesetVersion.current.rawValue,
            originalKind: current.originalKind ?? current.kind, scheduledAt: scheduled, estimatedMinutes: current.estimatedMinutes,
            reasonCodes: current.reasonCodes, adaptationReasonCodes: [PlanReason.postponed.rawValue, PlanReason.safeReschedule.rawValue],
            adaptedAt: .now, rescheduledFromID: current.id, revision: (current.revision ?? 1) + 1
        ))
        updated.sort { $0.scheduleDate < $1.scheduleDate }
        guard planRepository.write(updated) else { return false }
        plannedDays = updated
        publishPlanChanged()
        return true
    }

    func applyPendingPlanActions() {
        let key = "tempo.pending-skip-plan-date"
        guard let date = UserDefaults.standard.object(forKey: key) as? Date else { return }
        if Calendar.current.isDateInToday(date) { _ = skipTodayPlan() }
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func updateTodayPlan(kind: ActivityKind?, status: LocalPlanStatus) -> Bool {
        let calendar = Calendar.current
        let resolver = PlanActivityResolver()
        guard let index = plannedDays.firstIndex(where: { day in
            guard calendar.isDateInToday(day.date) else { return false }
            guard day.status.isActionable else { return false }
            guard let kind else { return true }
            let effectiveKind = resolver.effectiveKind(
                day.kind,
                exerciseRestricted: baseline?.hasExerciseRestriction == true,
                guidedAllowed: guidedEligibility.isAllowed,
                isToday: true
            )
            return effectiveKind == kind
        }) else { return false }
        var updated = plannedDays
        let current = updated[index]
        updated[index] = LocalPlanDay(
            id: current.id,
            date: current.date,
            kind: current.kind,
            status: status,
            phase: current.phase,
            generatedAt: current.generatedAt,
            rulesetVersion: current.rulesetVersion,
            originalKind: current.originalKind,
            scheduledAt: current.scheduledAt,
            estimatedMinutes: current.estimatedMinutes,
            reasonCodes: current.reasonCodes,
            adaptationReasonCodes: current.adaptationReasonCodes,
            adaptedAt: current.adaptedAt,
            rescheduledFromID: current.rescheduledFromID,
            revision: current.revision,
            completedAt: status == .completed ? .now : current.completedAt,
            performedKind: status == .completed ? kind : current.performedKind
        )
        guard planRepository.write(updated) else { return false }
        plannedDays = updated
        publishPlanChanged()
        return true
    }

    private func load() {
        checkIns = load([LocalCheckIn].self, for: storageKey, defaultValue: [])
        urgeOutcomes = load([LocalUrgeOutcome].self, for: urgeOutcomeStorageKey, defaultValue: [])
        sessions = load([LocalSession].self, for: sessionStorageKey, defaultValue: [])
        privateSessions = privateSessionRepository.read() ?? load([LocalPrivateSession].self, for: privateSessionStorageKey, defaultValue: [])
        profile = load(LocalProfileState.self, for: profileStorageKey, defaultValue: LocalProfileState())
        exercises = load([LocalExerciseLog].self, for: exerciseStorageKey, defaultValue: [])
        plannedDays = planRepository.read() ?? load([LocalPlanDay].self, for: planStorageKey, defaultValue: [])
        if profile.safetyHolds.isEmpty, let blocked = checkIns.first(where: \.blocksTraining) {
            _ = recordSafetyHold(reasonCode: "safety.migrated.\(blocked.action)", severity: RecommendationSeverity.medical.rawValue, source: "migration")
        }
    }

    /// V1 plan rows have no time, duration, reason, revision, or execution
    /// metadata. Add only missing metadata and retain IDs, dates, kinds, and
    /// terminal statuses so an upgrade never erases historical evidence.
    private func migrateLegacyPlanMetadataIfNeeded() {
        let calendar = Calendar.current
        let needsPlanMigration = plannedDays.contains {
            $0.scheduledAt == nil || $0.estimatedMinutes == nil || $0.reasonCodes == nil || $0.revision == nil
        }
        if needsPlanMigration {
            let migrated = plannedDays.map { day -> LocalPlanDay in
                let scheduled = day.scheduledAt ?? calendar.date(bySettingHour: 19, minute: 0, second: 0, of: day.date) ?? day.date
                return LocalPlanDay(
                    id: day.id, date: day.date, kind: day.kind, status: day.status, phase: day.phase,
                    generatedAt: day.generatedAt, rulesetVersion: day.rulesetVersion,
                    originalKind: day.originalKind, scheduledAt: scheduled, estimatedMinutes: day.estimatedMinutes ?? 5,
                    reasonCodes: day.reasonCodes ?? [PlanReason.legacyImported.rawValue], adaptationReasonCodes: day.adaptationReasonCodes,
                    adaptedAt: day.adaptedAt, rescheduledFromID: day.rescheduledFromID, revision: day.revision ?? 0,
                    completedAt: day.completedAt, performedKind: day.performedKind
                )
            }
            if planRepository.write(migrated) { plannedDays = migrated }
        }
        if profile.schemaVersion < 2 {
            var upgraded = profile
            upgraded.schemaVersion = 2
            if persistProfile(upgraded) { profile = upgraded }
        }
    }

    private func load<T: Codable>(_ type: T.Type, for key: String, defaultValue: T) -> T {
        if key != profileStorageKey, let data = ProtectedFileStore.data(for: key) {
            if let decoded = try? JSONDecoder().decode(T.self, from: data) { return decoded }
            if key == sessionStorageKey { markPendingSafetyWrite() }
            return defaultValue
        }
        if let data = SecureLocalStore.data(for: key) {
            guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
                if key == sessionStorageKey { markPendingSafetyWrite() }
                return defaultValue
            }
            if key != profileStorageKey, ProtectedFileStore.store(data, for: key) { SecureLocalStore.remove(key) }
            return decoded
        }
        if let legacyData = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode(T.self, from: legacyData) {
            let stored = key == profileStorageKey ? SecureLocalStore.store(legacyData, for: key) : ProtectedFileStore.store(legacyData, for: key)
            if stored { UserDefaults.standard.removeObject(forKey: key) }
            return decoded
        }
        return defaultValue
    }

    @discardableResult
    private func save<T: Encodable>(_ value: T, for key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return ProtectedFileStore.store(data, for: key)
    }

    private func persistProfile(_ value: LocalProfileState) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return SecureLocalStore.store(data, for: profileStorageKey)
    }

    private func sessionDroppingRawEvents(_ value: LocalSession) -> LocalSession {
        LocalSession(id: value.id, startedAt: value.startedAt, completedAt: value.completedAt, cycles: value.cycles, terminalState: value.terminalState, targetCycles: value.targetCycles, pauseThreshold: value.pauseThreshold, maximumDurationSeconds: value.maximumDurationSeconds, preAnxiety: value.preAnxiety, durationSeconds: value.durationSeconds, lateStopOccurred: value.lateStopOccurred, postAnxiety: value.postAnxiety, postTension: value.postTension, painAfter: value.painAfter, irritationAfter: value.irritationAfter, outcome: value.outcome, note: value.note, arousalEvents: nil, pauseCycles: nil, sessionType: value.sessionType, activeSeconds: value.activeSeconds, recoverySeconds: value.recoverySeconds, rulesetVersion: value.rulesetVersion)
    }

    private func weekStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: day) ?? day
    }

    private func projectedHours(since events: [Date], at date: Date) -> Double? {
        guard let latest = events.filter({ $0 < date }).max() else { return nil }
        return max(0, date.timeIntervalSince(latest) / 3_600)
    }

    private func publishPlanChanged() {
        NotificationCenter.default.post(name: .tempoPlanDidChange, object: nil)
    }

    private func markPendingSafetyWrite() {
        hasPendingSafetyWrite = true
        UserDefaults.standard.set(true, forKey: pendingSafetyStorageKey)
    }

    private func clearPendingSafetyWrite() {
        hasPendingSafetyWrite = false
        UserDefaults.standard.removeObject(forKey: pendingSafetyStorageKey)
    }
}
