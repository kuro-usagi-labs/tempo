import Foundation

/// Versioned, deterministic rules used to produce a Tempo plan. The value is
/// stored with every item so a future rules change never rewrites history.
public struct RulesetVersion: RawRepresentable, Codable, Equatable, Hashable, Sendable, Comparable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public static let current = RulesetVersion(rawValue: "2.1.3")

    public static func < (lhs: RulesetVersion, rhs: RulesetVersion) -> Bool {
        lhs.rawValue.compare(rhs.rawValue, options: .numeric) == .orderedAscending
    }
}

public enum PlanReason: String, Codable, CaseIterable, Hashable, Sendable {
    case baselineRequired
    case awarenessFoundation
    case guidedSpacing
    case plannedMovement
    case plannedStrength
    case nervousSystemRecovery
    case weeklyReflection
    case highAnxiety
    case lowSleep
    case lowEnergy
    case exerciseRestriction
    case safetyHold
    case guidedRecoveryWindow
    case privateRecoveryWindow
    case lateStopAdaptation
    case unavailable
    case postponed
    case missedActivity
    case safeReschedule
    case legacyImported
    case highStimulusReset
    case movementLoad
    case unsafeActivitySpace
    case preferredActivity

    public var shortExplanation: String {
        switch self {
        case .baselineRequired: "Mulai dari langkah dasar yang aman."
        case .awarenessFoundation: "Membangun jeda dan kesadaran secara bertahap."
        case .guidedSpacing: "Diberi jarak agar pemulihan tetap terjaga."
        case .plannedMovement: "Gerak ringan mendukung tidur dan suasana hati."
        case .plannedStrength: "Kekuatan ringan untuk fondasi aktivitas harian."
        case .nervousSystemRecovery: "Hari pemulihan membantu ritme tetap stabil."
        case .weeklyReflection: "Meninjau pola membantu pilihan berikutnya lebih sadar."
        case .highAnxiety: "Rencana diringankan karena kecemasan sedang tinggi."
        case .lowSleep: "Rencana diringankan agar tubuh bisa mengejar pemulihan."
        case .lowEnergy: "Energi hari ini rendah, jadi langkahnya diringankan."
        case .exerciseRestriction: "Gerak diganti pemulihan sesuai batasan yang dicatat."
        case .safetyHold: "Latihan dijeda sampai pemeriksaan ulang selesai."
        case .guidedRecoveryWindow: "Jeda antar sesi terpandu masih berlangsung."
        case .privateRecoveryWindow: "Tubuh diberi ruang setelah sesi privat."
        case .lateStopAdaptation: "Ambang dan tempo dibuat lebih lembut setelah sinyal terlambat."
        case .unavailable: "Disesuaikan karena waktu hari ini tidak memungkinkan."
        case .postponed: "Dipindahkan ke waktu yang lebih realistis."
        case .missedActivity: "Aktivitas yang terlewat tidak perlu dikejar sekaligus."
        case .safeReschedule: "Penjadwalan ulang tetap menjaga jarak pemulihan."
        case .legacyImported: "Riwayat ini dipertahankan dari versi aplikasi sebelumnya."
        case .highStimulusReset: "Materi awal membantu mengurangi ketergantungan pada stimulus yang sangat tinggi."
        case .movementLoad: "Porsi gerak sudah cukup sehingga program tidak menambah cardio berlebihan."
        case .unsafeActivitySpace: "Aktivitas diganti karena ruang latihan yang aman belum tersedia."
        case .preferredActivity: "Aktivitas dipilih mengikuti preferensimu selama tetap aman."
        }
    }
}

public enum ProgramPlanStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case scheduled
    case completed
    case skipped
    case adapted
    case recovery

    public var isTerminal: Bool { self == .completed || self == .skipped }
    public var isActionable: Bool { self == .scheduled || self == .adapted || self == .recovery }
}

public struct PlanAdaptation: Codable, Equatable, Hashable, Sendable {
    public let adaptedAt: Date
    public let originalKind: ActivityKind
    public let replacementKind: ActivityKind
    public let reasons: [PlanReason]
    public let rescheduledFromID: UUID?

    public init(adaptedAt: Date, originalKind: ActivityKind, replacementKind: ActivityKind, reasons: [PlanReason], rescheduledFromID: UUID? = nil) {
        self.adaptedAt = adaptedAt
        self.originalKind = originalKind
        self.replacementKind = replacementKind
        self.reasons = reasons
        self.rescheduledFromID = rescheduledFromID
    }
}

public struct ProgramActivityExecution: Codable, Equatable, Hashable, Sendable {
    public let completedAt: Date
    public let performedKind: ActivityKind
    public let logID: UUID?

    public init(completedAt: Date, performedKind: ActivityKind, logID: UUID? = nil) {
        self.completedAt = completedAt
        self.performedKind = performedKind
        self.logID = logID
    }
}

/// A plan item keeps its original prescription immutable. Adaptation and
/// execution are attached records, not a replacement of the original kind.
public struct ProgramPlanItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let scheduledAt: Date
    public let prescribedKind: ActivityKind
    public let estimatedMinutes: Int
    public let phase: ProgramPhase
    public let reasons: [PlanReason]
    public let rulesetVersion: RulesetVersion
    public let revision: Int
    public var status: ProgramPlanStatus
    public var adaptation: PlanAdaptation?
    public var execution: ProgramActivityExecution?

    public init(
        id: UUID = UUID(),
        scheduledAt: Date,
        prescribedKind: ActivityKind,
        estimatedMinutes: Int,
        phase: ProgramPhase,
        reasons: [PlanReason],
        rulesetVersion: RulesetVersion = .current,
        revision: Int = 1,
        status: ProgramPlanStatus = .scheduled,
        adaptation: PlanAdaptation? = nil,
        execution: ProgramActivityExecution? = nil
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.prescribedKind = prescribedKind
        self.estimatedMinutes = max(1, estimatedMinutes)
        self.phase = phase
        self.reasons = reasons
        self.rulesetVersion = rulesetVersion
        self.revision = max(1, revision)
        self.status = status
        self.adaptation = adaptation
        self.execution = execution
    }

    public var effectiveKind: ActivityKind { adaptation?.replacementKind ?? prescribedKind }
    public var isMutable: Bool { !status.isTerminal }

    public func adapted(to replacement: ActivityKind, reasons: [PlanReason], at date: Date, rescheduledFromID: UUID? = nil) -> ProgramPlanItem {
        guard isMutable else { return self }
        var copy = self
        copy.status = replacement == .recovery ? .recovery : .adapted
        copy.adaptation = PlanAdaptation(
            adaptedAt: date,
            originalKind: prescribedKind,
            replacementKind: replacement,
            reasons: reasons,
            rescheduledFromID: rescheduledFromID
        )
        return copy
    }

    public func completed(as kind: ActivityKind, at date: Date, logID: UUID? = nil) -> ProgramPlanItem {
        guard isMutable else { return self }
        var copy = self
        copy.status = .completed
        copy.execution = ProgramActivityExecution(completedAt: date, performedKind: kind, logID: logID)
        return copy
    }

    /// A terminal missed item preserves its original prescription and any
    /// adaptation history. This makes a generated replacement auditable
    /// without allowing a refresh to revive the source item.
    public func skipped(reasons: [PlanReason], at date: Date) -> ProgramPlanItem {
        guard isMutable else { return self }
        var copy = self
        let existingReasons = adaptation?.reasons ?? []
        let mergedReasons = existingReasons + reasons.filter { !existingReasons.contains($0) }
        copy.status = .skipped
        copy.adaptation = PlanAdaptation(
            adaptedAt: date,
            originalKind: adaptation?.originalKind ?? prescribedKind,
            replacementKind: effectiveKind,
            reasons: mergedReasons
        )
        return copy
    }
}

/// The compact symptom choice stored with a daily readiness check-in.  The
/// value identifies the reported category; whether it is still unresolved is
/// recorded separately on `DailyReadinessRecord` so a clear health recheck can
/// retain the historical category without leaving a permanent safety lock.
public enum DailySymptomType: String, Codable, CaseIterable, Hashable, Sendable {
    case none
    case mildIrritation
    case pain
    case urinaryOrDischarge
    case bloodOrFever

    public var requiresSafetyHold: Bool { self != .none }

    public var safetySeverity: RecommendationSeverity? {
        switch self {
        case .none: nil
        case .mildIrritation: .caution
        case .pain, .urinaryOrDischarge: .medical
        case .bloodOrFever: .urgent
        }
    }

    public var safetyReasonCode: String? {
        switch self {
        case .none: nil
        case .mildIrritation: "safety.daily-readiness-irritation"
        case .pain: "safety.daily-readiness-pain"
        case .urinaryOrDischarge: "safety.daily-readiness-urinary-discharge"
        case .bloodOrFever: "safety.daily-readiness-blood-fever"
        }
    }

    public var displayName: String {
        switch self {
        case .none: "Tidak ada keluhan"
        case .mildIrritation: "Iritasi ringan"
        case .pain: "Nyeri"
        case .urinaryOrDischarge: "Perih saat kencing atau cairan tidak biasa"
        case .bloodOrFever: "Darah atau demam"
        }
    }
}

/// A stable, local representation of the activity someone prefers.  The app
/// layer may continue to persist its older display string while onboarding is
/// migrated; the domain always works from this closed set of safe choices.
public enum ActivityPreference: String, Codable, CaseIterable, Hashable, Sendable {
    case walking
    case walkJog
    case homeStrength
    case breathingAndMobility
    case noPreference

    public init?(legacyValue: String?) {
        guard let legacyValue else { return nil }
        let value = legacyValue
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !value.isEmpty else { return nil }
        if value.contains("tidak") || value.contains("none") || value.contains("no preference") { self = .noPreference }
        else if value.contains("napas") || value.contains("breath") || value.contains("mobilitas") { self = .breathingAndMobility }
        else if value.contains("rumah") || value.contains("home") || value.contains("strength") || value.contains("kekuatan") { self = .homeStrength }
        else if value.contains("jog") || value.contains("lari") || value.contains("run") { self = .walkJog }
        else if value.contains("jalan") || value.contains("walk") { self = .walking }
        // Older versions allowed free text such as "Sepeda". Do not guess a
        // different exercise type; use the deliberate neutral fallback.
        else { self = .noPreference }
    }

    public var legacyDisplayValue: String {
        switch self {
        case .walking: "Jalan santai"
        case .walkJog: "Jalan–jogging"
        case .homeStrength: "Latihan kekuatan di rumah"
        case .breathingAndMobility: "Latihan napas dan mobilitas"
        case .noPreference: "Tidak punya preferensi"
        }
    }

    public func isCompatible(with kind: ActivityKind) -> Bool {
        switch self {
        case .walking, .walkJog: kind == .cardio
        case .homeStrength: kind == .strength
        case .breathingAndMobility: kind == .breathing
        case .noPreference: false
        }
    }
}

public struct ProgramContext: Equatable, Sendable {
    public var phase: ProgramPhase
    public var baselineCompleted: Bool
    public var anxiety: Int
    public var sleepHours: Double?
    /// A current-day readiness value. It is deliberately optional because a
    /// baseline must never masquerade as a daily energy check-in.
    public var energyToday: Int?
    public var exerciseRestricted: Bool
    public var canWalkTwentyMinutes: Bool
    public var hasSafeActivitySpace: Bool
    public var rushedHabit: Bool
    public var highStimulusPattern: Bool
    public var hasSafetyHold: Bool
    public var hoursSinceLastGuidedSession: Double?
    public var hoursSinceLastPrivateSession: Double?
    public var guidedSessionsLast7Days: Int
    public var lateStopsLast3Sessions: Int
    public var perceivedControl: Int?
    public var weeklyMovementMinutes: Int?
    public var activityLevel: String?
    /// Kept for compatibility with persisted baselines. New callers should
    /// prefer `activityPreference` so scheduling never depends on free text.
    public var preferredActivity: String?
    public var activityPreference: ActivityPreference?
    /// True only when anxiety, sleep, and energy were supplied by a current daily
    /// readiness check. Baseline answers are traits, not a reason to rewrite
    /// today's guided activity every time the plan refreshes.
    public var readinessIsCurrent: Bool
    public var programWeek: Int

    public init(
        phase: ProgramPhase = .assessmentRequired,
        baselineCompleted: Bool = false,
        anxiety: Int = 5,
        sleepHours: Double? = nil,
        energyToday: Int? = nil,
        exerciseRestricted: Bool = false,
        canWalkTwentyMinutes: Bool = true,
        hasSafeActivitySpace: Bool = true,
        rushedHabit: Bool = false,
        highStimulusPattern: Bool = false,
        hasSafetyHold: Bool = false,
        hoursSinceLastGuidedSession: Double? = nil,
        hoursSinceLastPrivateSession: Double? = nil,
        guidedSessionsLast7Days: Int = 0,
        lateStopsLast3Sessions: Int = 0,
        perceivedControl: Int? = nil,
        weeklyMovementMinutes: Int? = nil,
        activityLevel: String? = nil,
        preferredActivity: String? = nil,
        activityPreference: ActivityPreference? = nil,
        readinessIsCurrent: Bool = false,
        programWeek: Int = 1
    ) {
        self.phase = phase
        self.baselineCompleted = baselineCompleted
        self.anxiety = min(10, max(1, anxiety))
        self.sleepHours = sleepHours
        self.energyToday = energyToday.map { min(10, max(1, $0)) }
        self.exerciseRestricted = exerciseRestricted
        self.canWalkTwentyMinutes = canWalkTwentyMinutes
        self.hasSafeActivitySpace = hasSafeActivitySpace
        self.rushedHabit = rushedHabit
        self.highStimulusPattern = highStimulusPattern
        self.hasSafetyHold = hasSafetyHold
        self.hoursSinceLastGuidedSession = hoursSinceLastGuidedSession
        self.hoursSinceLastPrivateSession = hoursSinceLastPrivateSession
        self.guidedSessionsLast7Days = max(0, guidedSessionsLast7Days)
        self.lateStopsLast3Sessions = max(0, lateStopsLast3Sessions)
        self.perceivedControl = perceivedControl.map { min(10, max(1, $0)) }
        self.weeklyMovementMinutes = weeklyMovementMinutes.map { max(0, $0) }
        self.activityLevel = activityLevel
        self.preferredActivity = preferredActivity
        self.activityPreference = activityPreference ?? ActivityPreference(legacyValue: preferredActivity)
        self.readinessIsCurrent = readinessIsCurrent
        self.programWeek = max(1, programWeek)
    }
}

public struct DailyPrescription: Equatable, Sendable {
    public let activity: ProgramPlanItem?
    public let primaryMessage: String
    public let insight: String

    public init(activity: ProgramPlanItem?, primaryMessage: String, insight: String) {
        self.activity = activity
        self.primaryMessage = primaryMessage
        self.insight = insight
    }
}

public struct SessionPrescription: Equatable, Sendable {
    public let preparationSeconds: Int
    public let activeTargetSeconds: Int
    public let recoverySeconds: Int
    public let maximumCycles: Int
    public let pauseThreshold: Int
    public let maximumDurationSeconds: Int
    public let checkInIntervalSeconds: Int
    public let reasons: [PlanReason]

    public init(preparationSeconds: Int, activeTargetSeconds: Int, recoverySeconds: Int, maximumCycles: Int, pauseThreshold: Int, maximumDurationSeconds: Int, checkInIntervalSeconds: Int, reasons: [PlanReason]) {
        self.preparationSeconds = max(30, preparationSeconds)
        self.activeTargetSeconds = max(60, activeTargetSeconds)
        self.recoverySeconds = max(20, recoverySeconds)
        self.maximumCycles = min(5, max(1, maximumCycles))
        self.pauseThreshold = min(9, max(4, pauseThreshold))
        self.maximumDurationSeconds = min(GuidedSessionMachine.absoluteMaximumDurationSeconds, max(300, maximumDurationSeconds))
        self.checkInIntervalSeconds = max(20, checkInIntervalSeconds)
        self.reasons = reasons
    }
}

public enum ExerciseMode: String, Codable, Equatable, Sendable { case walk, walkJog, strengthCircuit }

public struct ExercisePrescription: Equatable, Sendable {
    public let mode: ExerciseMode
    public let targetMinutes: Int
    public let intervals: [Int]
    public let sets: Int
    public let repetitions: Int
    public let restSeconds: Int
    public let reason: PlanReason

    public init(mode: ExerciseMode, targetMinutes: Int, intervals: [Int] = [], sets: Int = 0, repetitions: Int = 0, restSeconds: Int = 0, reason: PlanReason) {
        self.mode = mode
        self.targetMinutes = max(1, targetMinutes)
        self.intervals = intervals
        self.sets = max(0, sets)
        self.repetitions = max(0, repetitions)
        self.restSeconds = max(0, restSeconds)
        self.reason = reason
    }
}

public struct EligibilityEngine: Sendable {
    public init() {}

    public func guidedEligibility(for context: ProgramContext) -> GuidedEligibility {
        if let privateHours = context.hoursSinceLastPrivateSession, privateHours < 24 {
            return GuidedEligibility(isAllowed: false, reason: .privateRecoveryWindow, message: "Beri tubuh waktu pulih setelah sesi privat sebelum memilih sesi terpandu.")
        }
        return GuidedEligibilityEvaluator().evaluate(
            programPhase: context.hasSafetyHold ? .safetyHold : context.phase,
            hoursSinceLastSession: context.hoursSinceLastGuidedSession,
            guidedSessionsLast7Days: context.guidedSessionsLast7Days
        )
    }
}

public struct SessionPrescriptionEngine: Sendable {
    public init() {}

    public func prescription(for context: ProgramContext) -> SessionPrescription {
        let phaseCycles: Int
        switch context.phase {
        case .assessmentRequired, .safetyHold, .awareness: phaseCycles = 2
        case .basicControl: phaseCycles = 3
        case .stability, .transfer: phaseCycles = 4
        case .independence: phaseCycles = 3
        }
        let lighterDay = context.anxiety >= 8 || (context.sleepHours ?? 8) < 5.5 || (context.energyToday ?? 10) <= 3
        let lateStops = context.lateStopsLast3Sessions >= 2
        let lowControl = (context.perceivedControl ?? 10) <= 3
        var reasons: [PlanReason] = []
        if context.anxiety >= 8 { reasons.append(.highAnxiety) }
        if (context.sleepHours ?? 8) < 5.5 { reasons.append(.lowSleep) }
        if (context.energyToday ?? 10) <= 3 { reasons.append(.lowEnergy) }
        if lateStops { reasons.append(.lateStopAdaptation) }
        return SessionPrescription(
            preparationSeconds: context.rushedHabit ? 60 : (lighterDay ? 60 : 45),
            activeTargetSeconds: lighterDay ? 360 : 600,
            recoverySeconds: lateStops ? 60 : 40,
            maximumCycles: lighterDay ? min(2, phaseCycles) : phaseCycles,
            pauseThreshold: lateStops || lowControl ? 6 : 7,
            maximumDurationSeconds: lighterDay ? 900 : 1_200,
            checkInIntervalSeconds: context.rushedHabit ? 35 : 45,
            reasons: reasons
        )
    }
}

public struct ExercisePrescriptionEngine: Sendable {
    public init() {}

    public func prescription(for kind: ActivityKind, context: ProgramContext, recentDifficulty: Int? = nil) -> ExercisePrescription? {
        guard !context.exerciseRestricted else { return nil }
        switch kind {
        case .cardio:
            if context.canWalkTwentyMinutes {
                let preference = context.activityPreference ?? ActivityPreference(legacyValue: context.preferredActivity)
                let canProgressToWalkJog = (recentDifficulty ?? 10) <= 5 && context.phase == .stability
                // Walk–jog is never inferred from a strength preference or a
                // low-readiness phase. With no preference, retain the safe
                // existing progression behaviour; an explicit walking choice
                // intentionally stays at a steady walk.
                let canAddIntervals = canProgressToWalkJog && (preference == nil || preference == .noPreference || preference == .walkJog)
                return ExercisePrescription(
                    mode: canAddIntervals ? .walkJog : .walk,
                    targetMinutes: canAddIntervals ? 22 : 20,
                    intervals: canAddIntervals ? [120, 60, 120, 60, 120, 60] : [],
                    reason: .plannedMovement
                )
            }
            return ExercisePrescription(mode: .walk, targetMinutes: 10, reason: .plannedMovement)
        case .strength:
            let difficulty = recentDifficulty ?? 4
            let reps = difficulty <= 4 ? 10 : 8
            return ExercisePrescription(mode: .strengthCircuit, targetMinutes: 16, sets: 2, repetitions: reps, restSeconds: 45, reason: .plannedStrength)
        default:
            return nil
        }
    }
}

public struct WeeklyPlanGenerator: Sendable {
    public init() {}

    public func generate(
        weekStarting monday: Date,
        weeks: Int = 2,
        context: ProgramContext,
        scheduleHistory: ProgramScheduleHistory = ProgramScheduleHistory(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [ProgramPlanItem] {
        generate(
            weekStarting: monday,
            weeks: weeks,
            context: context,
            scheduleHistory: scheduleHistory,
            referenceDate: Self.startOfMonday(for: monday, calendar: calendar),
            calendar: calendar
        )
    }

    public func generate(
        weekStarting monday: Date,
        weeks: Int = 2,
        context: ProgramContext,
        scheduleHistory: ProgramScheduleHistory = ProgramScheduleHistory(),
        referenceDate: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [ProgramPlanItem] {
        let start = Self.startOfMonday(for: monday, calendar: calendar)
        let count = min(4, max(1, weeks))
        var generated: [ProgramPlanItem] = []
        for offset in 0..<(count * 7) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let template = template(for: context.phase)[offset % 7]
            let time = calendar.date(bySettingHour: template.hour, minute: template.minute, second: 0, of: date) ?? date
            var requestedKind = template.kind
            var adaptationReasons: [PlanReason] = []
            let activityPreference = context.activityPreference ?? ActivityPreference(legacyValue: context.preferredActivity)
            let highMovement = (context.weeklyMovementMinutes ?? (context.activityLevel?.localizedCaseInsensitiveContains("aktif") == true ? 150 : 0)) >= 150
            let candidateWeekOffset = offset / 7
            let candidateProgramWeek = context.programWeek + candidateWeekOffset
            if context.highStimulusPattern, candidateProgramWeek == 1, offset % 7 == 2 {
                requestedKind = .education
                adaptationReasons.append(.highStimulusReset)
            } else if template.kind == .cardio, offset % 7 == 5, highMovement {
                requestedKind = .breathing
                adaptationReasons.append(.movementLoad)
            } else if activityPreference == .breathingAndMobility, template.kind == .cardio, offset % 7 == 5 {
                requestedKind = .breathing
                adaptationReasons.append(.preferredActivity)
            } else if activityPreference == .homeStrength,
                      template.kind == .cardio,
                      offset % 7 == 1,
                      context.hasSafeActivitySpace,
                      !context.exerciseRestricted {
                // Keep strength days separated while still honouring a safe
                // home-strength preference on the first movement slot.
                requestedKind = .strength
                adaptationReasons.append(.preferredActivity)
            } else if let activityPreference, activityPreference.isCompatible(with: template.kind) {
                adaptationReasons.append(.preferredActivity)
            }

            var datedContext = context
            let appliesCurrentReadiness = context.readinessIsCurrent && calendar.isDate(time, inSameDayAs: referenceDate)
            if !appliesCurrentReadiness {
                datedContext.anxiety = min(7, context.anxiety)
                datedContext.sleepHours = nil
                datedContext.energyToday = nil
            }
            let generatedGuidedDates = generated.filter { $0.effectiveKind == .guided && $0.status.isActionable }.map(\.scheduledAt)
            let guidedDates = scheduleHistory.guidedSessionDates + scheduleHistory.scheduledGuidedDates + generatedGuidedDates
            datedContext.hoursSinceLastGuidedSession = projectedHours(since: guidedDates, at: time)
            datedContext.hoursSinceLastPrivateSession = projectedHours(since: scheduleHistory.privateSessionDates, at: time)
            let sevenDaysEarlier = time.addingTimeInterval(-7 * 86_400)
            datedContext.guidedSessionsLast7Days = guidedDates.filter { $0 >= sevenDaysEarlier && $0 < time }.count

            var resolved = PlanActivityResolver().resolve(requestedKind, context: datedContext)
            adaptationReasons.append(contentsOf: resolved.reasons)
            if resolved.kind == .guided,
               guidedDates.contains(where: { abs($0.timeIntervalSince(time)) < 48 * 3_600 }) {
                resolved = (.recovery, [.guidedSpacing])
                adaptationReasons.append(.guidedSpacing)
            }
            let finalKind = resolved.kind
            let isAdapted = finalKind != template.kind
            let status: ProgramPlanStatus = isAdapted ? (finalKind == .recovery ? .recovery : .adapted) : .scheduled
            let item = ProgramPlanItem(
                id: stableID(for: time, kind: template.kind, phase: context.hasSafetyHold ? .safetyHold : context.phase),
                scheduledAt: time,
                prescribedKind: template.kind,
                estimatedMinutes: finalKind == .recovery && template.kind != .recovery ? min(8, template.minutes) : template.minutes,
                phase: context.hasSafetyHold ? .safetyHold : context.phase,
                reasons: template.reasons + adaptationReasons,
                rulesetVersion: .current,
                status: status,
                adaptation: isAdapted ? PlanAdaptation(adaptedAt: referenceDate, originalKind: template.kind, replacementKind: finalKind, reasons: adaptationReasons) : nil
            )
            generated.append(item)
        }
        return generated
    }

    private func projectedHours(since events: [Date], at scheduledDate: Date) -> Double? {
        guard let latest = events.filter({ $0 < scheduledDate }).max() else { return nil }
        return max(0, scheduledDate.timeIntervalSince(latest) / 3_600)
    }

    /// Stable IDs make a generated plan reproducible and give notification
    /// scheduling a durable key. Persisted legacy IDs are retained by the app
    /// layer during migration rather than regenerated.
    private func stableID(for date: Date, kind: ActivityKind, phase: ProgramPhase) -> UUID {
        let seed = "\(RulesetVersion.current.rawValue)|\(Int64(date.timeIntervalSince1970))|\(phase.rawValue)|\(kind.rawValue)"
        func fnv1a(_ value: String, seed: UInt64) -> UInt64 {
            value.utf8.reduce(seed) { hash, byte in
                (hash ^ UInt64(byte)) &* 1_099_511_628_211
            }
        }
        let first = fnv1a(seed, seed: 14_695_981_039_346_656_037)
        let second = fnv1a(String(seed.reversed()), seed: 1_099_511_628_211)
        let hex = String(format: "%016llx%016llx", first, second)
        let formatted = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20))"
        return UUID(uuidString: formatted) ?? UUID()
    }

    private func template(for phase: ProgramPhase) -> [(kind: ActivityKind, hour: Int, minute: Int, minutes: Int, reasons: [PlanReason])] {
        let awareness: [(kind: ActivityKind, hour: Int, minute: Int, minutes: Int, reasons: [PlanReason])] = [
            (.guided, 18, 30, 18, [.awarenessFoundation, .guidedSpacing]),
            (.cardio, 18, 0, 20, [.plannedMovement]),
            (.breathing, 21, 0, 5, [.nervousSystemRecovery]),
            (.guided, 18, 30, 18, [.awarenessFoundation, .guidedSpacing]),
            (.strength, 18, 0, 16, [.plannedStrength]),
            (.cardio, 9, 0, 20, [.plannedMovement]),
            (.review, 19, 30, 5, [.weeklyReflection])
        ]
        switch phase {
        case .assessmentRequired:
            return [
                (.education, 19, 0, 4, [.baselineRequired]), (.breathing, 21, 0, 5, [.nervousSystemRecovery]),
                (.cardio, 18, 0, 15, [.plannedMovement]), (.recovery, 21, 0, 5, [.nervousSystemRecovery]),
                (.education, 19, 0, 4, [.baselineRequired]), (.strength, 18, 0, 12, [.plannedStrength]),
                (.review, 19, 30, 5, [.weeklyReflection])
            ]
        case .awareness: return awareness
        case .basicControl:
            return [(.guided, 18, 30, 20, [.guidedSpacing]), (.cardio, 18, 0, 20, [.plannedMovement]), (.strength, 18, 0, 16, [.plannedStrength]), (.guided, 18, 30, 20, [.guidedSpacing]), (.breathing, 21, 0, 5, [.nervousSystemRecovery]), (.cardio, 9, 0, 20, [.plannedMovement]), (.review, 19, 30, 5, [.weeklyReflection])]
        case .stability:
            return [(.guided, 18, 30, 20, [.guidedSpacing]), (.cardio, 18, 0, 22, [.plannedMovement]), (.strength, 18, 0, 16, [.plannedStrength]), (.guided, 18, 30, 20, [.guidedSpacing]), (.recovery, 21, 0, 6, [.nervousSystemRecovery]), (.cardio, 9, 0, 22, [.plannedMovement]), (.review, 19, 30, 5, [.weeklyReflection])]
        case .transfer:
            return [(.cardio, 18, 0, 22, [.plannedMovement]), (.guided, 18, 30, 18, [.guidedSpacing]), (.education, 19, 0, 5, [.awarenessFoundation]), (.recovery, 21, 0, 6, [.nervousSystemRecovery]), (.guided, 18, 30, 18, [.guidedSpacing]), (.strength, 9, 0, 16, [.plannedStrength]), (.review, 19, 30, 5, [.weeklyReflection])]
        case .independence:
            return [(.cardio, 18, 0, 22, [.plannedMovement]), (.breathing, 21, 0, 5, [.nervousSystemRecovery]), (.strength, 18, 0, 16, [.plannedStrength]), (.guided, 18, 30, 18, [.guidedSpacing]), (.recovery, 21, 0, 6, [.nervousSystemRecovery]), (.cardio, 9, 0, 22, [.plannedMovement]), (.review, 19, 30, 5, [.weeklyReflection])]
        case .safetyHold:
            return [(.recovery, 21, 0, 5, [.safetyHold]), (.breathing, 21, 0, 5, [.safetyHold]), (.recovery, 21, 0, 5, [.safetyHold]), (.breathing, 21, 0, 5, [.safetyHold]), (.recovery, 21, 0, 5, [.safetyHold]), (.breathing, 21, 0, 5, [.safetyHold]), (.review, 19, 30, 5, [.weeklyReflection])]
        }
    }

    public static func startOfMonday(for date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: day) ?? day
    }
}

public struct ProgramScheduleHistory: Equatable, Sendable {
    public var guidedSessionDates: [Date]
    public var privateSessionDates: [Date]
    public var scheduledGuidedDates: [Date]
    /// When true, `guidedSessionDates` and `scheduledGuidedDates` represent
    /// the complete known local history. In that case a projected rolling
    /// count must use those dates instead of a stale aggregate from today.
    public var hasCompleteGuidedHistory: Bool

    public init(
        guidedSessionDates: [Date] = [],
        privateSessionDates: [Date] = [],
        scheduledGuidedDates: [Date] = [],
        hasCompleteGuidedHistory: Bool = false
    ) {
        self.guidedSessionDates = guidedSessionDates
        self.privateSessionDates = privateSessionDates
        self.scheduledGuidedDates = scheduledGuidedDates
        self.hasCompleteGuidedHistory = hasCompleteGuidedHistory
    }
}

/// Separates the program week being viewed in the calendar from the actual
/// week used by progression. Navigating never mutates program state.
public struct ProgramWeekCalculator: Sendable {
    public init() {}

    public func displayedWeek(
        baselineCompletedAt: Date?,
        weekStarting: Date,
        calendar: Calendar = Calendar(identifier: .gregorian),
        maximumWeek: Int = 12
    ) -> Int {
        guard let baselineCompletedAt else { return 1 }
        let baselineWeek = WeeklyPlanGenerator.startOfMonday(for: baselineCompletedAt, calendar: calendar)
        let displayedWeek = WeeklyPlanGenerator.startOfMonday(for: weekStarting, calendar: calendar)
        let days = calendar.dateComponents([.day], from: baselineWeek, to: displayedWeek).day ?? 0
        let week = days / 7 + 1
        return min(max(1, maximumWeek), max(1, week))
    }
}

/// The domain result for an automatic missed-guided reschedule. The caller
/// replaces the source with `skippedSource` and appends `rescheduledItem` in a
/// single persisted write, so no refresh can temporarily revive the source.
public struct AutomaticGuidedReschedule: Equatable, Sendable {
    public let skippedSource: ProgramPlanItem
    public let rescheduledItem: ProgramPlanItem

    public init(skippedSource: ProgramPlanItem, rescheduledItem: ProgramPlanItem) {
        self.skippedSource = skippedSource
        self.rescheduledItem = rescheduledItem
    }
}

/// A missed guided activity is always made terminal. A replacement is optional
/// because safety constraints are never weakened merely to preserve a target.
public enum MissedGuidedResolution: Equatable, Sendable {
    case skipped(ProgramPlanItem)
    case rescheduled(AutomaticGuidedReschedule)
}

public struct PlanRefreshPolicy: Sendable {
    public init() {}

    public func shouldRetainExisting(_ item: ProgramPlanItem, now: Date, force: Bool) -> Bool {
        if item.status.isTerminal { return true }
        if item.adaptation?.rescheduledFromID != nil { return true }
        let userReasons: Set<PlanReason> = [.unavailable, .postponed, .safeReschedule]
        if let reasons = item.adaptation?.reasons, !userReasons.isDisjoint(with: reasons) { return true }
        if item.scheduledAt <= now { return true }
        if !force, item.status == .adapted || item.status == .recovery { return true }
        return false
    }
}

public struct DailyRecommendationEngine: Sendable {
    public init() {}

    public func prescription(for date: Date, items: [ProgramPlanItem], context: ProgramContext, calendar: Calendar = Calendar(identifier: .gregorian)) -> DailyPrescription {
        // Callers can supply the persisted plan in any order.  Choosing the
        // first row made a completed early item mask a later, actionable item
        // on the same day. Keep the selection rules here, where both Today and
        // any future caller get the same deterministic primary activity.
        let today = items
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: date) }
            .sorted { lhs, rhs in
                let lhsActionable = lhs.status.isActionable
                let rhsActionable = rhs.status.isActionable
                if lhsActionable != rhsActionable { return lhsActionable }

                let lhsIncomplete = !lhs.status.isTerminal
                let rhsIncomplete = !rhs.status.isTerminal
                if lhsIncomplete != rhsIncomplete { return lhsIncomplete }

                let lhsDistance = abs(lhs.scheduledAt.timeIntervalSince(date))
                let rhsDistance = abs(rhs.scheduledAt.timeIntervalSince(date))
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }

                let lhsRescheduled = lhs.adaptation?.rescheduledFromID != nil
                let rhsRescheduled = rhs.adaptation?.rescheduledFromID != nil
                if lhsRescheduled != rhsRescheduled { return lhsRescheduled }

                return lhs.scheduledAt < rhs.scheduledAt
            }
            .first
        let insight: String
        if context.hasSafetyHold { insight = "Fokus minggu ini adalah pemulihan dan pemeriksaan ulang, tanpa mengejar target." }
        else if context.anxiety >= 8 { insight = "Ritme hari ini diringankan. Konsistensi kecil lebih penting daripada memaksa." }
        else if let sleep = context.sleepHours, sleep < 5.5 { insight = "Tidur yang kurang adalah alasan sah untuk memilih pemulihan." }
        else if let energy = context.energyToday, energy <= 3 { insight = "Energi hari ini rendah; pemulihan adalah langkah yang cukup." }
        else { insight = "Ikuti satu langkah yang dijadwalkan; rencana dapat menyesuaikan bila keadaan berubah." }
        guard let today else {
            return DailyPrescription(activity: nil, primaryMessage: "Tidak ada target yang perlu dikejar hari ini.", insight: insight)
        }
        return DailyPrescription(activity: today, primaryMessage: today.reasons.first?.shortExplanation ?? "Satu langkah yang sesuai untuk hari ini.", insight: insight)
    }
}

public struct ProgramEngine: Sendable {
    public let weeklyGenerator: WeeklyPlanGenerator
    public let dailyRecommendationEngine: DailyRecommendationEngine
    public let sessionPrescriptionEngine: SessionPrescriptionEngine
    public let exercisePrescriptionEngine: ExercisePrescriptionEngine
    public let eligibilityEngine: EligibilityEngine

    public init(
        weeklyGenerator: WeeklyPlanGenerator = WeeklyPlanGenerator(),
        dailyRecommendationEngine: DailyRecommendationEngine = DailyRecommendationEngine(),
        sessionPrescriptionEngine: SessionPrescriptionEngine = SessionPrescriptionEngine(),
        exercisePrescriptionEngine: ExercisePrescriptionEngine = ExercisePrescriptionEngine(),
        eligibilityEngine: EligibilityEngine = EligibilityEngine()
    ) {
        self.weeklyGenerator = weeklyGenerator
        self.dailyRecommendationEngine = dailyRecommendationEngine
        self.sessionPrescriptionEngine = sessionPrescriptionEngine
        self.exercisePrescriptionEngine = exercisePrescriptionEngine
        self.eligibilityEngine = eligibilityEngine
    }
}

public enum ScheduleConstraint: String, CaseIterable, Hashable, Sendable {
    case sourceNotActionable
    case sourceAlreadyRescheduled
    case duplicateReplacement
    case candidateBeforeEarliest
    case safetyHold
    case privateRecoveryWindow
    case guidedSpacing
    case guidedWeeklyLimit
    case demandingActivity
    case reviewDay
    case exerciseRestriction
    case unsafeActivitySpace
    case duplicateActivity
    case guidedIneligible
}

public struct ScheduleEvaluation: Equatable, Sendable {
    public let blockers: Set<ScheduleConstraint>

    public init(blockers: Set<ScheduleConstraint> = []) {
        self.blockers = blockers
    }

    public var isAllowed: Bool { blockers.isEmpty }
}

/// Shared, deterministic scheduling gate. Manual postponement, missed-guided
/// recovery, and future adaptive moves must ask this same evaluator before a
/// replacement is created.
public struct ScheduleConstraintEvaluator: Sendable {
    public static let minimumGuidedSpacing: TimeInterval = 48 * 3_600
    public static let privateRecoveryWindow: TimeInterval = 24 * 3_600
    public static let maximumGuidedSessionsPerSevenDays = 3

    public init() {}

    public func evaluate(
        source: ProgramPlanItem,
        candidate: Date,
        items: [ProgramPlanItem],
        scheduleHistory: ProgramScheduleHistory,
        context: ProgramContext,
        now: Date,
        earliestDate: Date? = nil,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> ScheduleEvaluation {
        var blockers = Set<ScheduleConstraint>()
        let earliest = earliestDate ?? now

        if !source.status.isActionable { blockers.insert(.sourceNotActionable) }
        if source.adaptation?.rescheduledFromID != nil { blockers.insert(.sourceAlreadyRescheduled) }
        if candidate <= earliest { blockers.insert(.candidateBeforeEarliest) }
        if context.hasSafetyHold { blockers.insert(.safetyHold) }
        if items.contains(where: { $0.id != source.id && $0.adaptation?.rescheduledFromID == source.id }) {
            blockers.insert(.duplicateReplacement)
        }

        let otherItems = items.filter { $0.id != source.id }
        let sameDay = otherItems.filter { calendar.isDate($0.scheduledAt, inSameDayAs: candidate) && $0.status != .skipped }
        if sameDay.contains(where: { $0.status.isActionable && $0.effectiveKind == source.effectiveKind }) {
            blockers.insert(.duplicateActivity)
        }
        if sameDay.contains(where: { $0.effectiveKind == .review }) && source.effectiveKind != .review {
            blockers.insert(.reviewDay)
        }

        switch source.effectiveKind {
        case .guided:
            if sameDay.contains(where: { [.guided, .cardio, .strength].contains($0.effectiveKind) }) {
                blockers.insert(.demandingActivity)
            }
            let guided = guidedDates(
                excluding: source,
                items: items,
                scheduleHistory: scheduleHistory,
                context: context,
                referenceDate: now
            )
            let privateDates = privateDates(scheduleHistory: scheduleHistory, context: context, referenceDate: now)
            if guided.dates.contains(where: { abs($0.timeIntervalSince(candidate)) < Self.minimumGuidedSpacing }) {
                blockers.insert(.guidedSpacing)
            }
            if privateDates.contains(where: { $0 < candidate && candidate.timeIntervalSince($0) < Self.privateRecoveryWindow }) {
                blockers.insert(.privateRecoveryWindow)
            }
            let projectedCount = projectedGuidedCount(
                dates: guided.dates,
                hasConcreteDates: guided.hasConcreteDates,
                candidate: candidate,
                fallback: context.guidedSessionsLast7Days,
                historyIsComplete: scheduleHistory.hasCompleteGuidedHistory
            )
            if projectedCount >= Self.maximumGuidedSessionsPerSevenDays {
                blockers.insert(.guidedWeeklyLimit)
            }
            var projectedContext = context
            projectedContext.readinessIsCurrent = false
            projectedContext.anxiety = 5
            projectedContext.sleepHours = nil
            projectedContext.energyToday = nil
            projectedContext.hoursSinceLastGuidedSession = projectedHours(since: guided.dates, at: candidate)
            projectedContext.hoursSinceLastPrivateSession = projectedHours(since: privateDates, at: candidate)
            projectedContext.guidedSessionsLast7Days = projectedCount
            if !EligibilityEngine().guidedEligibility(for: projectedContext).isAllowed {
                blockers.insert(.guidedIneligible)
            }

        case .cardio, .strength:
            if context.exerciseRestricted { blockers.insert(.exerciseRestriction) }
            if source.effectiveKind == .strength && !context.hasSafeActivitySpace {
                blockers.insert(.unsafeActivitySpace)
            }
            if sameDay.contains(where: { [.guided, .cardio, .strength].contains($0.effectiveKind) }) {
                blockers.insert(.demandingActivity)
            }

        case .breathing, .education, .recovery, .review:
            break
        }

        return ScheduleEvaluation(blockers: blockers)
    }

    public func firstAllowedDate(
        for source: ProgramPlanItem,
        after earliestDate: Date,
        items: [ProgramPlanItem],
        scheduleHistory: ProgramScheduleHistory,
        context: ProgramContext,
        now: Date,
        horizonDays: Int = 6,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date? {
        let day = calendar.startOfDay(for: earliestDate)
        let time = calendar.dateComponents([.hour, .minute], from: source.scheduledAt)
        for offset in 1...max(1, horizonDays) {
            guard let candidateDay = calendar.date(byAdding: .day, value: offset, to: day) else { continue }
            let candidate = calendar.date(
                bySettingHour: time.hour ?? 18,
                minute: time.minute ?? 0,
                second: 0,
                of: candidateDay
            ) ?? candidateDay
            let evaluation = evaluate(
                source: source,
                candidate: candidate,
                items: items,
                scheduleHistory: scheduleHistory,
                context: context,
                now: now,
                earliestDate: earliestDate,
                calendar: calendar
            )
            if evaluation.isAllowed { return candidate }
        }
        return nil
    }

    private func guidedDates(
        excluding source: ProgramPlanItem,
        items: [ProgramPlanItem],
        scheduleHistory: ProgramScheduleHistory,
        context: ProgramContext,
        referenceDate: Date
    ) -> (dates: [Date], hasConcreteDates: Bool) {
        var dates = scheduleHistory.guidedSessionDates + scheduleHistory.scheduledGuidedDates
        // A caller may supply the source's old scheduled date in the legacy
        // date-only history. Remove one exact match only: it is the source,
        // while a genuinely separate same-time plan row remains a conflict.
        if source.effectiveKind == .guided,
           source.status.isActionable,
           let sourceIndex = dates.firstIndex(where: { abs($0.timeIntervalSince(source.scheduledAt)) < 1 }) {
            dates.remove(at: sourceIndex)
        }
        for item in items where item.id != source.id && item.effectiveKind == .guided {
            switch item.status {
            case .skipped, .recovery:
                continue
            case .completed:
                if !scheduleHistory.hasCompleteGuidedHistory,
                   item.execution?.performedKind == .guided {
                    dates.append(item.execution?.completedAt ?? item.scheduledAt)
                }
            case .scheduled, .adapted:
                dates.append(item.scheduledAt)
            }
        }
        let hasConcreteDates = !dates.isEmpty
        if dates.isEmpty, !scheduleHistory.hasCompleteGuidedHistory,
           let hours = context.hoursSinceLastGuidedSession {
            dates.append(referenceDate.addingTimeInterval(-hours * 3_600))
        }
        return (deduplicatedDates(dates), hasConcreteDates)
    }

    private func privateDates(
        scheduleHistory: ProgramScheduleHistory,
        context: ProgramContext,
        referenceDate: Date
    ) -> [Date] {
        var dates = scheduleHistory.privateSessionDates
        if dates.isEmpty, let hours = context.hoursSinceLastPrivateSession {
            dates.append(referenceDate.addingTimeInterval(-hours * 3_600))
        }
        return deduplicatedDates(dates)
    }

    private func projectedGuidedCount(
        dates: [Date],
        hasConcreteDates: Bool,
        candidate: Date,
        fallback: Int,
        historyIsComplete: Bool
    ) -> Int {
        let windowStart = candidate.addingTimeInterval(-7 * 86_400)
        let concreteCount = dates.filter { $0 >= windowStart && $0 < candidate }.count
        // Concrete dates describe the candidate's rolling window. The current
        // aggregate is only useful when no dated history is available at all.
        if historyIsComplete { return concreteCount }
        // Partial dates cannot prove that the current aggregate is lower. A
        // complete local history, above, is the only case allowed to replace
        // the aggregate with a lower candidate-window count.
        if !hasConcreteDates { return max(0, fallback) }
        return max(max(0, fallback), concreteCount)
    }

    private func projectedHours(since dates: [Date], at date: Date) -> Double? {
        guard let latest = dates.filter({ $0 < date }).max() else { return nil }
        return max(0, date.timeIntervalSince(latest) / 3_600)
    }

    private func deduplicatedDates(_ dates: [Date]) -> [Date] {
        let sorted = dates.sorted()
        var unique: [Date] = []
        for date in sorted {
            if let previous = unique.last, abs(date.timeIntervalSince(previous)) < 1 {
                continue
            }
            unique.append(date)
        }
        return unique
    }
}

public struct AdaptationPolicy: Sendable {
    public static let minimumGuidedSpacing = ScheduleConstraintEvaluator.minimumGuidedSpacing
    public static let privateRecoveryWindow = ScheduleConstraintEvaluator.privateRecoveryWindow
    public static let maximumGuidedSessionsPerSevenDays = ScheduleConstraintEvaluator.maximumGuidedSessionsPerSevenDays
    public static let automaticGuidedRescheduleHorizonDays = 6
    public static let maximumMissedGuidedAge: TimeInterval = 48 * 3_600

    private let constraints: ScheduleConstraintEvaluator

    public init(constraints: ScheduleConstraintEvaluator = ScheduleConstraintEvaluator()) {
        self.constraints = constraints
    }

    public func adaptUnavailable(_ item: ProgramPlanItem, at date: Date) -> ProgramPlanItem {
        item.adapted(to: .recovery, reasons: [.unavailable], at: date)
    }

    /// Retained for source compatibility. New callers should use
    /// `manualReschedule` so the terminal source and linked replacement are
    /// persisted together after shared constraint evaluation.
    public func postpone(_ item: ProgramPlanItem, to date: Date) -> ProgramPlanItem {
        item.adapted(to: item.effectiveKind, reasons: [.postponed, .safeReschedule], at: date, rescheduledFromID: item.id)
    }

    public func manualReschedule(
        _ item: ProgramPlanItem,
        now: Date,
        items: [ProgramPlanItem],
        scheduleHistory: ProgramScheduleHistory = ProgramScheduleHistory(),
        context: ProgramContext,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> AutomaticGuidedReschedule? {
        let earliest = max(now, item.scheduledAt)
        guard let target = constraints.firstAllowedDate(
            for: item,
            after: earliest,
            items: items,
            scheduleHistory: scheduleHistory,
            context: context,
            now: now,
            calendar: calendar
        ) else { return nil }
        return reschedulePair(item, target: target, at: now, reasons: [.postponed, .safeReschedule])
    }

    /// Produces the two records that must be persisted together when an
    /// untouched guided activity has passed. It deliberately returns `nil`
    /// rather than relaxing any safety condition.
    public func automaticRescheduleMissedGuided(
        _ item: ProgramPlanItem,
        now: Date,
        items: [ProgramPlanItem],
        scheduleHistory: ProgramScheduleHistory = ProgramScheduleHistory(),
        context: ProgramContext,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> AutomaticGuidedReschedule? {
        guard let target = safeAutomaticGuidedRescheduleDate(
            for: item,
            after: now,
            items: items,
            scheduleHistory: scheduleHistory,
            context: context,
            calendar: calendar
        ) else { return nil }
        return reschedulePair(item, target: target, at: now, reasons: [.missedActivity, .safeReschedule])
    }

    /// Resolves a recently missed guided item in one explicit result. Callers
    /// should persist the returned skipped source even when no safe
    /// replacement is available.
    public func resolveMissedGuided(
        _ item: ProgramPlanItem,
        now: Date,
        items: [ProgramPlanItem],
        scheduleHistory: ProgramScheduleHistory = ProgramScheduleHistory(),
        context: ProgramContext,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> MissedGuidedResolution? {
        guard isAutomaticallyReschedulableMissedGuided(item, now: now, context: context) else { return nil }
        if let reschedule = automaticRescheduleMissedGuided(
            item,
            now: now,
            items: items,
            scheduleHistory: scheduleHistory,
            context: context,
            calendar: calendar
        ) {
            return .rescheduled(reschedule)
        }
        return .skipped(item.skipped(reasons: [.missedActivity], at: now))
    }

    public func safeAutomaticGuidedRescheduleDate(
        for item: ProgramPlanItem,
        after now: Date,
        items: [ProgramPlanItem],
        scheduleHistory: ProgramScheduleHistory = ProgramScheduleHistory(),
        context: ProgramContext,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date? {
        guard isAutomaticallyReschedulableMissedGuided(item, now: now, context: context) else { return nil }
        return constraints.firstAllowedDate(
            for: item,
            after: now,
            items: items,
            scheduleHistory: scheduleHistory,
            context: context,
            now: now,
            horizonDays: Self.automaticGuidedRescheduleHorizonDays,
            calendar: calendar
        )
    }

    public func safeRescheduleDate(
        for item: ProgramPlanItem,
        after date: Date,
        items: [ProgramPlanItem],
        scheduleHistory: ProgramScheduleHistory = ProgramScheduleHistory(),
        context: ProgramContext? = nil,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date? {
        let resolvedContext = context ?? ProgramContext(phase: item.phase, baselineCompleted: true)
        return constraints.firstAllowedDate(
            for: item,
            after: max(date, item.scheduledAt),
            items: items,
            scheduleHistory: scheduleHistory,
            context: resolvedContext,
            now: date,
            calendar: calendar
        )
    }

    public func shouldRescheduleMissed(_ item: ProgramPlanItem, now: Date, items: [ProgramPlanItem], calendar: Calendar = Calendar(identifier: .gregorian)) -> Bool {
        guard !item.status.isTerminal, item.scheduledAt < now else { return false }
        return safeRescheduleDate(for: item, after: now, items: items, calendar: calendar) != nil
    }

    private func isAutomaticallyReschedulableMissedGuided(_ item: ProgramPlanItem, now: Date, context: ProgramContext) -> Bool {
        guard context.baselineCompleted,
              !context.hasSafetyHold,
              item.status == .scheduled,
              item.adaptation == nil,
              item.prescribedKind == .guided,
              item.effectiveKind == .guided,
              item.scheduledAt < now,
              now.timeIntervalSince(item.scheduledAt) < Self.maximumMissedGuidedAge
        else { return false }
        return true
    }

    private func reschedulePair(
        _ item: ProgramPlanItem,
        target: Date,
        at now: Date,
        reasons: [PlanReason]
    ) -> AutomaticGuidedReschedule {
        let skippedSource = item.skipped(reasons: reasons, at: now)
        let replacementKind = item.effectiveKind
        let replacement = ProgramPlanItem(
            id: rescheduleID(sourceID: item.id, scheduledAt: target),
            scheduledAt: target,
            prescribedKind: item.prescribedKind,
            estimatedMinutes: item.estimatedMinutes,
            phase: item.phase,
            reasons: item.reasons,
            rulesetVersion: item.rulesetVersion,
            revision: item.revision + 1,
            status: replacementKind == .recovery ? .recovery : .adapted,
            adaptation: PlanAdaptation(
                adaptedAt: now,
                originalKind: item.adaptation?.originalKind ?? item.prescribedKind,
                replacementKind: replacementKind,
                reasons: reasons,
                rescheduledFromID: item.id
            )
        )
        return AutomaticGuidedReschedule(skippedSource: skippedSource, rescheduledItem: replacement)
    }

    private func rescheduleID(sourceID: UUID, scheduledAt: Date) -> UUID {
        let source = sourceID.uuidString.replacingOccurrences(of: "-", with: "")
        let timestamp = String(format: "%016llx", UInt64(max(0, scheduledAt.timeIntervalSince1970.rounded())))
        let hex = String(source.prefix(16)) + timestamp
        let formatted = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20))"
        return UUID(uuidString: formatted) ?? UUID()
    }
}

public enum ProgressPresentationState: Equatable, Sendable {
    case baseline
    case collecting(samplesNeeded: Int)
    case ready(ScoreSnapshot)
}

public enum ConsistencyEligibility: Equatable, Sendable {
    case required
    case excused
    case notDue
}

public struct ProgressEngine: Sendable {
    public init() {}

    public func presentation(sessionCount: Int, scores: ScoreSnapshot) -> ProgressPresentationState {
        guard sessionCount >= 3 else { return sessionCount == 0 ? .baseline : .collecting(samplesNeeded: 3 - sessionCount) }
        return .ready(scores)
    }

    public func consistency(for items: [ProgramPlanItem], through date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Double? {
        let replacementSourceIDs = Set(items.compactMap { $0.adaptation?.rescheduledFromID })
        let due = items.filter {
            consistencyEligibility(for: $0, through: date) == .required &&
                ($0.adaptation?.rescheduledFromID != nil || !replacementSourceIDs.contains($0.id))
        }
        let uniqueDue = deduplicatedReplacements(in: due)
        guard !uniqueDue.isEmpty else { return nil }
        let done = uniqueDue.filter { $0.status == .completed }.count
        return Double(done) / Double(uniqueDue.count)
    }

    public func consistencyEligibility(
        for item: ProgramPlanItem,
        through date: Date
    ) -> ConsistencyEligibility {
        guard item.scheduledAt <= date else { return .notDue }

        let adaptationReasons = Set(item.adaptation?.reasons ?? [])
        let originalKind = item.adaptation?.originalKind ?? item.prescribedKind
        let effectiveKind = item.effectiveKind
        let changedKind = originalKind != effectiveKind
        let isRecoveryLike = effectiveKind == .recovery || effectiveKind == .breathing
        let isReplacement = item.adaptation?.rescheduledFromID != nil
        let isPostponedSource = !isReplacement && item.status == .skipped &&
            (!adaptationReasons.isDisjoint(with: [.postponed, .safeReschedule]))
        if isPostponedSource { return .excused }

        // These reasons mean Tempo substituted a lower-demand activity for
        // safety or today's real-world capacity. Completing one is welcome,
        // but leaving it incomplete must never reduce consistency.
        let excusedAdaptations: Set<PlanReason> = [
            .safetyHold,
            .unavailable,
            .privateRecoveryWindow,
            .guidedRecoveryWindow,
            .guidedSpacing,
            .lowSleep,
            .lowEnergy,
            .highAnxiety,
            .exerciseRestriction,
            .unsafeActivitySpace
        ]
        let isGeneratedSafetyRecovery = isRecoveryLike &&
            (item.phase == .safetyHold || item.reasons.contains(.safetyHold))
        let isExcusedAdaptation = !adaptationReasons.isDisjoint(with: excusedAdaptations) &&
            (changedKind || isRecoveryLike)
        if isGeneratedSafetyRecovery || isExcusedAdaptation {
            return .excused
        }

        // A linked replacement remains the one required occurrence even when
        // its linkage reasons contain postponed/safeReschedule. Normal
        // prescribed recovery and breathing are required like any other item.
        return .required
    }

    /// Historical data may contain more than one replacement for the same
    /// source from older builds. Count only the best known child so a source
    /// and replacement can never depress (or inflate) consistency twice.
    private func deduplicatedReplacements(in items: [ProgramPlanItem]) -> [ProgramPlanItem] {
        let direct = items.filter { $0.adaptation?.rescheduledFromID == nil }
        let children = Dictionary(grouping: items.compactMap { item -> (UUID, ProgramPlanItem)? in
            guard let sourceID = item.adaptation?.rescheduledFromID else { return nil }
            return (sourceID, item)
        }, by: { $0.0 })
        let canonicalChildren = children.values.compactMap { group -> ProgramPlanItem? in
            group.map { $0.1 }.sorted { lhs, rhs in
                if (lhs.status == .completed) != (rhs.status == .completed) {
                    return lhs.status == .completed
                }
                return lhs.scheduledAt < rhs.scheduledAt
            }.first
        }
        return direct + canonicalChildren
    }
}
