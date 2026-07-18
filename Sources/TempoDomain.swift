import Foundation

public enum ProgramPhase: String, Codable, CaseIterable, Sendable { case assessmentRequired, awareness, basicControl, stability, transfer, independence, safetyHold }
public enum UrgeTrigger: String, Codable, CaseIterable, Sendable { case desire, boredom, stress, loneliness, sleep }
public enum UrgeIntent: String, Codable, CaseIterable, Sendable { case calm, training, privateSession }
public enum RecommendedAction: String, Codable, Sendable { case healthCheck, recovery, regulate, urgeSurf, guidedSession, privateSession, exercise, education }
public enum RecommendationSeverity: String, Codable, Sendable { case normal, caution, medical, urgent }

public struct DecisionContext: Equatable, Sendable {
    public var programPhase: ProgramPhase = .assessmentRequired
    public var urgeIntensity: Int = 1
    public var trigger: UrgeTrigger? = nil
    public var intent: UrgeIntent? = nil
    public var pain = false, irritation = false, urinaryBurning = false, unusualDischarge = false, bloodReported = false, pelvicOrTesticularPain = false, fever = false
    public var anxiety = 1
    public var sleepHours: Double? = nil
    public var hoursSinceLastSession: Double? = nil
    public var guidedSessionsLast7Days = 0
    public init() {}
}

public struct Recommendation: Equatable, Sendable {
    public let action: RecommendedAction
    public let severity: RecommendationSeverity
    public let reasonCode: String
    public let message: String
    public let blocksGuidedTraining: Bool
    public init(_ action: RecommendedAction, _ severity: RecommendationSeverity = .normal, _ reasonCode: String, _ message: String, blocked: Bool = false) {
        self.action = action; self.severity = severity; self.reasonCode = reasonCode; self.message = message; self.blocksGuidedTraining = blocked
    }
}

public enum GuidedEligibilityReason: String, Codable, Sendable {
    case ready, baselineRequired, safetyHold, recoveryWindow, weeklyLimit
}

public struct GuidedEligibility: Equatable, Sendable {
    public let isAllowed: Bool
    public let reason: GuidedEligibilityReason
    public let message: String

    public init(isAllowed: Bool, reason: GuidedEligibilityReason, message: String) {
        self.isAllowed = isAllowed
        self.reason = reason
        self.message = message
    }
}

public struct GuidedEligibilityEvaluator: Sendable {
    public init() {}
    public func evaluate(programPhase: ProgramPhase, hoursSinceLastSession: Double?, guidedSessionsLast7Days: Int) -> GuidedEligibility {
        if programPhase == .safetyHold {
            return GuidedEligibility(isAllowed: false, reason: .safetyHold, message: "Selesaikan pemeriksaan ulang gejala sebelum guided session.")
        }
        if programPhase == .assessmentRequired {
            return GuidedEligibility(isAllowed: false, reason: .baselineRequired, message: "Lengkapi baseline sebelum memulai guided session.")
        }
        if guidedSessionsLast7Days >= 3 {
            return GuidedEligibility(isAllowed: false, reason: .weeklyLimit, message: "Batas guided session mingguan sudah tercapai. Pilih pemulihan.")
        }
        if let hoursSinceLastSession, hoursSinceLastSession <= 24 {
            return GuidedEligibility(isAllowed: false, reason: .recoveryWindow, message: "Beri waktu pemulihan lebih dari 24 jam sebelum guided session berikutnya.")
        }
        return GuidedEligibility(isAllowed: true, reason: .ready, message: "Guided session tersedia.")
    }
}

public struct RuleEngine: Sendable {
    public static let rulesetVersion = "1.0.0"
    public init() {}
    public func evaluate(_ c: DecisionContext) -> Recommendation {
        if c.programPhase == .safetyHold {
            return Recommendation(.healthCheck, .medical, "safety.active_hold", "Selesaikan pemeriksaan ulang gejala sebelum guided session.", blocked: true)
        }
        if c.bloodReported || c.fever || c.pain || c.pelvicOrTesticularPain {
            return Recommendation(.healthCheck, .urgent, "safety.urgent", "Hentikan latihan. Jawabanmu memerlukan panduan kesehatan segera.", blocked: true)
        }
        if c.urinaryBurning || c.unusualDischarge {
            return Recommendation(.healthCheck, .medical, "safety.urinary", "Health check adalah langkah berikutnya. Guided session dijeda.", blocked: true)
        }
        if c.irritation { return Recommendation(.recovery, .caution, "safety.irritation", "Beri tubuh waktu pulih. Guided session dijeda sekurangnya 48 jam.", blocked: true) }
        if c.programPhase == .assessmentRequired, c.intent == .training {
            return Recommendation(.education, .caution, "readiness.baseline_required", "Lengkapi baseline sebelum memulai guided session.", blocked: true)
        }
        if (c.hoursSinceLastSession ?? .infinity) <= 24 || c.guidedSessionsLast7Days >= 3 {
            return Recommendation(.recovery, .caution, "readiness.recent_session", "Istirahat adalah bagian program. Sesi tambahan sekarang tidak disarankan.", blocked: true)
        }
        if c.anxiety >= 8 { return Recommendation(.regulate, .caution, "readiness.high_anxiety", "Tenangkan diri dengan napas lima menit, lalu nilai ulang kondisimu.") }
        if c.intent == .calm { return Recommendation(.urgeSurf, .normal, "urge.calm_choice", "Ambil jeda lima menit, lalu nilai ulang dorongan sebelum memilih langkah berikutnya.") }
        if c.trigger == .boredom || c.trigger == .stress || c.urgeIntensity <= 4 {
            return Recommendation(.urgeSurf, .normal, "urge.regulation", "Coba reset lima menit sebelum menentukan apa yang kamu butuhkan.")
        }
        if c.intent == .privateSession { return Recommendation(.privateSession, .normal, "urge.private_choice", "Jalani sesi pribadi tanpa terburu-buru dan berhenti jika terasa sakit.") }
        if c.urgeIntensity >= 5 && c.intent == .training { return Recommendation(.guidedSession, .normal, "urge.training_ready", "Waktu pemulihanmu cukup untuk guided control session.") }
        return Recommendation(.education, .normal, "plan.review", "Materi singkat atau aktivitas pemulihan adalah langkah aman berikutnya.")
    }
}

public enum GuidedSessionState: String, Codable, Sendable { case precheck, prepare, activeLow, activeRising, warning, pausedRecovery, resumeReady, completed, earlyCompletion, cancelled, safetyAbort, timeLimitReached }
public enum GuidedPauseReason: String, Codable, Sendable { case manual, threshold, almostTooLate, interruption }
public struct GuidedSessionMachine: Equatable, Sendable {
    public static let absoluteMaximumDurationSeconds = 1_500
    public private(set) var state: GuidedSessionState = .precheck
    public private(set) var cycles = 0
    public private(set) var elapsedSeconds = 0
    public private(set) var lastPauseReason: GuidedPauseReason?
    public private(set) var lateStopOccurred = false
    public let maximumCycles: Int
    public let maximumDurationSeconds: Int
    public var isTerminal: Bool { [.completed, .earlyCompletion, .cancelled, .safetyAbort, .timeLimitReached].contains(state) }
    public init(maximumCycles: Int = 3, maximumDurationSeconds: Int = 1_200) {
        self.maximumCycles = min(max(1, maximumCycles), 5)
        self.maximumDurationSeconds = min(max(60, maximumDurationSeconds), Self.absoluteMaximumDurationSeconds)
    }
    public mutating func start() { guard state == .precheck else { return }; state = .prepare }
    public mutating func beginActive() { guard state == .prepare || state == .resumeReady else { return }; state = .activeLow }
    @discardableResult public mutating func rising(level: Int, threshold: Int) -> Bool {
        guard state == .activeLow || state == .activeRising else { return false }
        if level >= threshold {
            state = .warning
            lastPauseReason = .threshold
            state = .pausedRecovery
            return true
        }
        state = level >= 6 ? .activeRising : .activeLow
        return false
    }
    @discardableResult public mutating func pause(reason: GuidedPauseReason = .manual) -> Bool {
        guard [.activeLow, .activeRising, .warning].contains(state) else { return false }
        lastPauseReason = reason
        state = .pausedRecovery
        return true
    }
    @discardableResult public mutating func emergencyPause() -> Bool {
        guard [.activeLow, .activeRising, .warning].contains(state) else { return false }
        lastPauseReason = .almostTooLate
        lateStopOccurred = true
        state = .pausedRecovery
        return true
    }
    public mutating func recovered(level: Int, elapsedSeconds: Int, minimumSeconds: Int = 30) { guard state == .pausedRecovery, elapsedSeconds >= minimumSeconds, level <= 4 else { return }; cycles += 1; state = cycles >= maximumCycles ? .completed : .resumeReady }
    public mutating func updateElapsed(totalSeconds: Int) {
        guard !isTerminal, state != .precheck else { return }
        elapsedSeconds = max(elapsedSeconds, max(0, totalSeconds))
        if elapsedSeconds >= maximumDurationSeconds { state = .timeLimitReached }
    }
    public mutating func complete() { guard !isTerminal, state != .precheck else { return }; state = .completed }
    public mutating func cancel() { guard !isTerminal else { return }; state = .cancelled }
    public mutating func earlyCompletion() { guard !isTerminal, [.activeLow, .activeRising, .warning, .pausedRecovery, .resumeReady].contains(state) else { return }; state = .earlyCompletion }
    public mutating func reachTimeLimit() { guard !isTerminal, state != .precheck else { return }; elapsedSeconds = maximumDurationSeconds; state = .timeLimitReached }
    public mutating func abortForSafety() { guard !isTerminal else { return }; state = .safetyAbort }
}

public enum ActivityKind: String, Codable, Sendable { case guided, breathing, cardio, strength, recovery, education, review }
public struct PlannedActivity: Equatable, Sendable { public let day: Int; public let kind: ActivityKind; public init(day: Int, kind: ActivityKind) { self.day = day; self.kind = kind } }
public struct WeeklyScheduler: Sendable {
    public init() {}
    public func beginnerPlan(highStress: Bool = false, irritation: Bool = false) -> [PlannedActivity] {
        plan(for: .awareness, highStress: highStress, irritation: irritation)
    }
    public func plan(for phase: ProgramPhase, highStress: Bool = false, irritation: Bool = false) -> [PlannedActivity] {
        if irritation || phase == .safetyHold {
            return [.init(day: 0, kind: .breathing), .init(day: 1, kind: .recovery), .init(day: 2, kind: .cardio), .init(day: 3, kind: .recovery), .init(day: 4, kind: .education), .init(day: 5, kind: .cardio), .init(day: 6, kind: .review)]
        }
        if phase == .assessmentRequired {
            return [.init(day: 0, kind: .education), .init(day: 1, kind: .breathing), .init(day: 2, kind: .cardio), .init(day: 3, kind: .recovery), .init(day: 4, kind: .education), .init(day: 5, kind: .strength), .init(day: 6, kind: .review)]
        }
        if highStress {
            return [.init(day: 0, kind: .breathing), .init(day: 1, kind: .recovery), .init(day: 2, kind: .guided), .init(day: 3, kind: .cardio), .init(day: 4, kind: .recovery), .init(day: 5, kind: .education), .init(day: 6, kind: .review)]
        }
        switch phase {
        case .awareness:
            return [.init(day: 0, kind: .breathing), .init(day: 1, kind: .guided), .init(day: 2, kind: .recovery), .init(day: 3, kind: .cardio), .init(day: 4, kind: .guided), .init(day: 5, kind: .strength), .init(day: 6, kind: .review)]
        case .basicControl:
            return [.init(day: 0, kind: .cardio), .init(day: 1, kind: .guided), .init(day: 2, kind: .strength), .init(day: 3, kind: .breathing), .init(day: 4, kind: .guided), .init(day: 5, kind: .recovery), .init(day: 6, kind: .review)]
        case .stability:
            return [.init(day: 0, kind: .cardio), .init(day: 1, kind: .guided), .init(day: 2, kind: .strength), .init(day: 3, kind: .recovery), .init(day: 4, kind: .guided), .init(day: 5, kind: .cardio), .init(day: 6, kind: .review)]
        case .transfer:
            return [.init(day: 0, kind: .cardio), .init(day: 1, kind: .education), .init(day: 2, kind: .guided), .init(day: 3, kind: .recovery), .init(day: 4, kind: .strength), .init(day: 5, kind: .breathing), .init(day: 6, kind: .review)]
        case .independence:
            return [.init(day: 0, kind: .cardio), .init(day: 1, kind: .breathing), .init(day: 2, kind: .strength), .init(day: 3, kind: .recovery), .init(day: 4, kind: .guided), .init(day: 5, kind: .education), .init(day: 6, kind: .review)]
        case .assessmentRequired, .safetyHold:
            return []
        }
    }
}

public struct ScoreInputs: Sendable {
    public let earlyPauseRate: Double
    public let loggingCompleteness: Double
    public let tensionRecognitionRate: Double
    public let escalationPredictionRate: Double
    public let successfulCycleRatio: Double
    public let controlledCompletionRatio: Double
    public let thresholdCompliance: Double
    public let recoveryCompletionRatio: Double
    public let calmRate: Double
    public let adherenceRate: Double
    public init(earlyPauseRate: Double, loggingCompleteness: Double, tensionRecognitionRate: Double, escalationPredictionRate: Double, successfulCycleRatio: Double, controlledCompletionRatio: Double, thresholdCompliance: Double, recoveryCompletionRatio: Double, calmRate: Double, adherenceRate: Double) { self.earlyPauseRate = earlyPauseRate; self.loggingCompleteness = loggingCompleteness; self.tensionRecognitionRate = tensionRecognitionRate; self.escalationPredictionRate = escalationPredictionRate; self.successfulCycleRatio = successfulCycleRatio; self.controlledCompletionRatio = controlledCompletionRatio; self.thresholdCompliance = thresholdCompliance; self.recoveryCompletionRatio = recoveryCompletionRatio; self.calmRate = calmRate; self.adherenceRate = adherenceRate }
}

public struct ScoreSnapshot: Equatable, Sendable { public let awareness: Int; public let control: Int; public let recovery: Int; public let calm: Int; public let consistency: Int }
public struct ScoreCalculator: Sendable {
    public init() {}
    public func calculate(_ input: ScoreInputs) -> ScoreSnapshot {
        func score(_ value: Double) -> Int { Int((max(0, min(1, value)) * 100).rounded()) }
        let awareness = input.earlyPauseRate * 0.50 + input.loggingCompleteness * 0.20 + input.tensionRecognitionRate * 0.15 + input.escalationPredictionRate * 0.15
        let control = input.successfulCycleRatio * 0.45 + input.controlledCompletionRatio * 0.20 + input.thresholdCompliance * 0.20 + input.recoveryCompletionRatio * 0.15
        return ScoreSnapshot(awareness: score(awareness), control: score(control), recovery: score(input.recoveryCompletionRatio), calm: score(input.calmRate), consistency: score(input.adherenceRate))
    }
}
