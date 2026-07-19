import Foundation

/// Versioned, deterministic rules used to produce a Tempo plan. The value is
/// stored with every item so a future rules change never rewrites history.
public struct RulesetVersion: RawRepresentable, Codable, Equatable, Hashable, Sendable, Comparable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public static let current = RulesetVersion(rawValue: "2.0.0")

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
}

public struct ProgramContext: Equatable, Sendable {
    public var phase: ProgramPhase
    public var baselineCompleted: Bool
    public var anxiety: Int
    public var sleepHours: Double?
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
    public var preferredActivity: String?
    public var programWeek: Int

    public init(
        phase: ProgramPhase = .assessmentRequired,
        baselineCompleted: Bool = false,
        anxiety: Int = 5,
        sleepHours: Double? = nil,
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
        programWeek: Int = 1
    ) {
        self.phase = phase
        self.baselineCompleted = baselineCompleted
        self.anxiety = min(10, max(1, anxiety))
        self.sleepHours = sleepHours
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
        let lighterDay = context.anxiety >= 8 || (context.sleepHours ?? 8) < 5.5
        let lateStops = context.lateStopsLast3Sessions >= 2
        let lowControl = (context.perceivedControl ?? 10) <= 3
        var reasons: [PlanReason] = []
        if context.anxiety >= 8 { reasons.append(.highAnxiety) }
        if (context.sleepHours ?? 8) < 5.5 { reasons.append(.lowSleep) }
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
                let canAddIntervals = (recentDifficulty ?? 10) <= 5 && context.phase == .stability
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
        referenceDate: Date = .now,
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
            let highMovement = (context.weeklyMovementMinutes ?? (context.activityLevel?.localizedCaseInsensitiveContains("aktif") == true ? 150 : 0)) >= 150
            if context.highStimulusPattern, context.programWeek <= 1, offset % 7 == 2 {
                requestedKind = .education
                adaptationReasons.append(.highStimulusReset)
            } else if template.kind == .cardio, offset % 7 == 5,
                      highMovement || context.preferredActivity?.localizedCaseInsensitiveContains("napas") == true {
                requestedKind = .breathing
                adaptationReasons.append(highMovement ? .movementLoad : .preferredActivity)
            }

            var datedContext = context
            if !calendar.isDate(time, inSameDayAs: referenceDate) {
                datedContext.anxiety = min(7, context.anxiety)
                datedContext.sleepHours = nil
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

    public init(guidedSessionDates: [Date] = [], privateSessionDates: [Date] = [], scheduledGuidedDates: [Date] = []) {
        self.guidedSessionDates = guidedSessionDates
        self.privateSessionDates = privateSessionDates
        self.scheduledGuidedDates = scheduledGuidedDates
    }
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
        let today = items.first {
            calendar.isDate($0.scheduledAt, inSameDayAs: date) && $0.status.isActionable
        }
        let insight: String
        if context.hasSafetyHold { insight = "Fokus minggu ini adalah pemulihan dan pemeriksaan ulang, tanpa mengejar target." }
        else if context.anxiety >= 8 { insight = "Ritme hari ini diringankan. Konsistensi kecil lebih penting daripada memaksa." }
        else if let sleep = context.sleepHours, sleep < 5.5 { insight = "Tidur yang kurang adalah alasan sah untuk memilih pemulihan." }
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

public struct AdaptationPolicy: Sendable {
    public init() {}

    public func adaptUnavailable(_ item: ProgramPlanItem, at date: Date) -> ProgramPlanItem {
        item.adapted(to: .recovery, reasons: [.unavailable], at: date)
    }

    public func postpone(_ item: ProgramPlanItem, to date: Date) -> ProgramPlanItem {
        item.adapted(to: item.effectiveKind, reasons: [.postponed, .safeReschedule], at: date, rescheduledFromID: item.id)
    }

    public func safeRescheduleDate(for item: ProgramPlanItem, after date: Date, items: [ProgramPlanItem], calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
        let day = calendar.startOfDay(for: date)
        let scheduledTime = calendar.dateComponents([.hour, .minute], from: item.scheduledAt)
        for offset in 1...6 {
            guard let candidateDay = calendar.date(byAdding: .day, value: offset, to: day) else { continue }
            let candidateAtScheduledTime = calendar.date(
                bySettingHour: scheduledTime.hour ?? 18,
                minute: scheduledTime.minute ?? 0,
                second: 0,
                of: candidateDay
            ) ?? candidateDay
            if item.effectiveKind != .guided { return candidateAtScheduledTime }
            let isTooClose = items.contains { other in
                other.id != item.id && other.effectiveKind == .guided && abs(other.scheduledAt.timeIntervalSince(candidateAtScheduledTime)) < 48 * 3_600
            }
            if !isTooClose { return candidateAtScheduledTime }
        }
        return nil
    }

    public func shouldRescheduleMissed(_ item: ProgramPlanItem, now: Date, items: [ProgramPlanItem], calendar: Calendar = Calendar(identifier: .gregorian)) -> Bool {
        guard !item.status.isTerminal, item.scheduledAt < now else { return false }
        return safeRescheduleDate(for: item, after: now, items: items, calendar: calendar) != nil
    }
}

public enum ProgressPresentationState: Equatable, Sendable {
    case baseline
    case collecting(samplesNeeded: Int)
    case ready(ScoreSnapshot)
}

public struct ProgressEngine: Sendable {
    public init() {}

    public func presentation(sessionCount: Int, scores: ScoreSnapshot) -> ProgressPresentationState {
        guard sessionCount >= 3 else { return sessionCount == 0 ? .baseline : .collecting(samplesNeeded: 3 - sessionCount) }
        return .ready(scores)
    }

    public func consistency(for items: [ProgramPlanItem], through date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Double? {
        let due = items.filter { $0.scheduledAt <= date && $0.status != .recovery }
        guard !due.isEmpty else { return nil }
        let done = due.filter { $0.status == .completed }.count
        return Double(done) / Double(due.count)
    }
}
