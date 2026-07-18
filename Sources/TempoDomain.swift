import Foundation

public enum ProgramPhase: String, Codable, CaseIterable { case assessmentRequired, awareness, basicControl, stability, transfer, independence, safetyHold }
public enum UrgeTrigger: String, Codable, CaseIterable { case desire, boredom, stress, loneliness, sleep }
public enum UrgeIntent: String, Codable, CaseIterable { case calm, training, privateSession }
public enum RecommendedAction: String, Codable { case healthCheck, recovery, regulate, urgeSurf, guidedSession, privateSession, exercise, education }
public enum RecommendationSeverity: String, Codable { case normal, caution, medical, urgent }

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

public struct RuleEngine: Sendable {
    public static let rulesetVersion = "1.0.0"
    public init() {}
    public func evaluate(_ c: DecisionContext) -> Recommendation {
        if c.bloodReported || c.fever || c.pain || c.pelvicOrTesticularPain {
            return Recommendation(.healthCheck, .urgent, "safety.urgent", "Stop training for now. Your answers need urgent health guidance.", blocked: true)
        }
        if c.urinaryBurning || c.unusualDischarge {
            return Recommendation(.healthCheck, .medical, "safety.urinary", "A health check is the better next step. Pause guided training.", blocked: true)
        }
        if c.irritation { return Recommendation(.recovery, .caution, "safety.irritation", "Give your body time to recover. Guided training is paused for 48–72 hours.", blocked: true) }
        if (c.hoursSinceLastSession ?? .infinity) < 12 || c.guidedSessionsLast7Days >= 3 {
            return Recommendation(.recovery, .caution, "readiness.recent_session", "Rest is part of the program. Another session now is unlikely to help.")
        }
        if c.anxiety >= 8 { return Recommendation(.regulate, .caution, "readiness.high_anxiety", "Settle first with five minutes of breathing, then reassess.") }
        if c.trigger == .boredom || c.trigger == .stress || c.urgeIntensity <= 4 {
            return Recommendation(.urgeSurf, .normal, "urge.regulation", "Try a five-minute reset before deciding what you need.")
        }
        if c.intent == .privateSession { return Recommendation(.privateSession, .normal, "urge.private_choice", "Keep this private session unhurried and stop if anything hurts.") }
        if c.urgeIntensity >= 5 && c.intent == .training { return Recommendation(.guidedSession, .normal, "urge.training_ready", "You have enough recovery time for a guided control session.") }
        return Recommendation(.education, .normal, "plan.review", "A short lesson or recovery activity is the safest next step today.")
    }
}

public enum GuidedSessionState: String, Codable { case precheck, prepare, activeLow, activeRising, warning, pausedRecovery, resumeReady, completed, earlyCompletion, cancelled, safetyAbort, timeLimitReached }
public struct GuidedSessionMachine: Equatable, Sendable {
    public private(set) var state: GuidedSessionState = .precheck
    public private(set) var cycles = 0
    public let maximumCycles: Int
    public init(maximumCycles: Int = 3) { self.maximumCycles = min(max(1, maximumCycles), 5) }
    public mutating func start() { guard state == .precheck else { return }; state = .prepare }
    public mutating func beginActive() { guard state == .prepare || state == .resumeReady else { return }; state = .activeLow }
    public mutating func rising(level: Int, threshold: Int) { guard state == .activeLow || state == .activeRising else { return }; state = level >= threshold ? .warning : .activeRising }
    public mutating func pause() { guard [.activeLow, .activeRising, .warning].contains(state) else { return }; state = .pausedRecovery }
    public mutating func recovered(level: Int) { guard state == .pausedRecovery, level <= 4 else { return }; cycles += 1; state = cycles >= maximumCycles ? .completed : .resumeReady }
    public mutating func earlyCompletion() { guard ![.completed, .cancelled, .safetyAbort, .timeLimitReached].contains(state) else { return }; state = .earlyCompletion }
    public mutating func reachTimeLimit() { guard ![.completed, .cancelled, .safetyAbort, .earlyCompletion].contains(state) else { return }; state = .timeLimitReached }
    public mutating func abortForSafety() { state = .safetyAbort }
}

public enum ActivityKind: String, Codable { case guided, breathing, cardio, strength, recovery, education, review }
public struct PlannedActivity: Equatable, Sendable { public let day: Int; public let kind: ActivityKind; public init(day: Int, kind: ActivityKind) { self.day = day; self.kind = kind } }
public struct WeeklyScheduler: Sendable {
    public init() {}
    public func beginnerPlan(highStress: Bool = false, irritation: Bool = false) -> [PlannedActivity] {
        if irritation { return [.init(day: 0, kind: .breathing), .init(day: 1, kind: .recovery), .init(day: 3, kind: .cardio), .init(day: 6, kind: .review)] }
        if highStress { return [.init(day: 0, kind: .breathing), .init(day: 2, kind: .guided), .init(day: 4, kind: .cardio), .init(day: 6, kind: .review)] }
        return [.init(day: 0, kind: .breathing), .init(day: 1, kind: .guided), .init(day: 2, kind: .recovery), .init(day: 3, kind: .cardio), .init(day: 4, kind: .guided), .init(day: 5, kind: .strength), .init(day: 6, kind: .review)]
    }
}

public struct ScoreInputs: Sendable {
    public let earlyPauseRate: Double
    public let loggingCompleteness: Double
    public let tensionRecognitionRate: Double
    public let escalationPredictionRate: Double
    public let successfulCycleRatio: Double
    public let thresholdCompliance: Double
    public let recoveryCompletionRatio: Double
    public let calmRate: Double
    public let adherenceRate: Double
    public init(earlyPauseRate: Double, loggingCompleteness: Double, tensionRecognitionRate: Double, escalationPredictionRate: Double, successfulCycleRatio: Double, thresholdCompliance: Double, recoveryCompletionRatio: Double, calmRate: Double, adherenceRate: Double) { self.earlyPauseRate = earlyPauseRate; self.loggingCompleteness = loggingCompleteness; self.tensionRecognitionRate = tensionRecognitionRate; self.escalationPredictionRate = escalationPredictionRate; self.successfulCycleRatio = successfulCycleRatio; self.thresholdCompliance = thresholdCompliance; self.recoveryCompletionRatio = recoveryCompletionRatio; self.calmRate = calmRate; self.adherenceRate = adherenceRate }
}

public struct ScoreSnapshot: Equatable, Sendable { public let awareness: Int; public let control: Int; public let recovery: Int; public let calm: Int; public let consistency: Int }
public struct ScoreCalculator: Sendable {
    public init() {}
    public func calculate(_ input: ScoreInputs) -> ScoreSnapshot {
        func score(_ value: Double) -> Int { Int((max(0, min(1, value)) * 100).rounded()) }
        let awareness = input.earlyPauseRate * 0.50 + input.loggingCompleteness * 0.20 + input.tensionRecognitionRate * 0.15 + input.escalationPredictionRate * 0.15
        let control = input.successfulCycleRatio * 0.45 + input.thresholdCompliance * 0.20 + input.recoveryCompletionRatio * 0.35
        return ScoreSnapshot(awareness: score(awareness), control: score(control), recovery: score(input.recoveryCompletionRatio), calm: score(input.calmRate), consistency: score(input.adherenceRate))
    }
}
