import Foundation

public enum ProgramPhase: String, Codable, CaseIterable, Sendable, Hashable { case assessmentRequired, awareness, basicControl, stability, transfer, independence, safetyHold }
public enum UrgeTrigger: String, Codable, CaseIterable, Sendable, Hashable { case desire, boredom, stress, loneliness, sleep }
public enum UrgeIntent: String, Codable, CaseIterable, Sendable, Hashable { case calm, training, privateSession }
public enum RecommendedAction: String, Codable, Sendable, Hashable { case healthCheck, recovery, regulate, urgeSurf, guidedSession, privateSession, exercise, education }
public enum RecommendationSeverity: String, Codable, Sendable, Hashable { case normal, caution, medical, urgent }

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

public enum ImmediateActionChoice: String, Codable, CaseIterable, Sendable, Hashable {
    case reset
    case privateSession
    case guided
}

public enum ImmediateActionDestination: String, Codable, Sendable, Hashable {
    case reset
    case privateSession
    case guided
    case guidedUnavailable
    case healthCheck
    /// An active, mild-irritation hold needs recovery and a recheck. It is
    /// deliberately distinct from both reset and the general health route so
    /// the UI cannot offer a training shortcut while the hold is active.
    case recoveryBlocked
}

public enum ImmediateActionAdvisory: String, Codable, Sendable, Hashable {
    case highAnxiety
    case lowSleep
    case recentGuidedSession
    case recentPrivateSession
    case frequentGuidedSessions

    public var message: String {
        switch self {
        case .highAnxiety: "Kecemasan sedang tinggi. Pertahankan tempo ringan dan berhenti kapan pun dibutuhkan."
        case .lowSleep: "Tidurmu sedang kurang. Pilih sesi yang singkat dan beri tubuh ruang pulih."
        case .recentGuidedSession: "Kamu baru menjalani sesi terpandu. Sesi privat tetap tersedia, tetapi jangan mengejar latihan tambahan."
        case .recentPrivateSession: "Tubuh mungkin masih dalam masa pemulihan dari sesi privat sebelumnya."
        case .frequentGuidedSessions: "Porsi latihan terpandu minggu ini sudah cukup. Sesi privat tidak dihitung sebagai latihan terpandu."
        }
    }
}

public struct ImmediateActionRequest: Equatable, Sendable {
    public var choice: ImmediateActionChoice
    public var intensity: Int
    public var anxiety: Int
    public var sleepHours: Double?
    public var hoursSinceLastGuidedSession: Double?
    public var hoursSinceLastPrivateSession: Double?
    public var guidedSessionsLast7Days: Int
    public var guidedEligibility: GuidedEligibility
    /// The answer given in the current quick-action flow. This must take
    /// precedence over every action choice.
    public var hasCurrentPhysicalSymptoms: Bool
    /// An unresolved hold stored from a previous check-in or session.
    public var hasActiveSafetyHold: Bool
    public var activeSafetyHoldSeverity: RecommendationSeverity?
    public var activeSafetyHoldReason: String?
    public var activeSafetyHoldRecheckDate: Date?

    /// Source-compatible spelling retained for callers built before the
    /// safety-hold fields were introduced.
    public var hasPhysicalSymptoms: Bool {
        get { hasCurrentPhysicalSymptoms }
        set { hasCurrentPhysicalSymptoms = newValue }
    }

    public init(
        choice: ImmediateActionChoice,
        intensity: Int,
        anxiety: Int = 5,
        sleepHours: Double? = nil,
        hoursSinceLastGuidedSession: Double? = nil,
        hoursSinceLastPrivateSession: Double? = nil,
        guidedSessionsLast7Days: Int = 0,
        guidedEligibility: GuidedEligibility = GuidedEligibility(isAllowed: true, reason: .ready, message: "Guided session tersedia."),
        hasPhysicalSymptoms: Bool? = nil,
        hasCurrentPhysicalSymptoms: Bool = false,
        hasActiveSafetyHold: Bool = false,
        activeSafetyHoldSeverity: RecommendationSeverity? = nil,
        activeSafetyHoldReason: String? = nil,
        activeSafetyHoldRecheckDate: Date? = nil
    ) {
        self.choice = choice
        self.intensity = min(10, max(1, intensity))
        self.anxiety = min(10, max(1, anxiety))
        self.sleepHours = sleepHours
        self.hoursSinceLastGuidedSession = hoursSinceLastGuidedSession
        self.hoursSinceLastPrivateSession = hoursSinceLastPrivateSession
        self.guidedSessionsLast7Days = max(0, guidedSessionsLast7Days)
        self.guidedEligibility = guidedEligibility
        self.hasCurrentPhysicalSymptoms = hasCurrentPhysicalSymptoms || (hasPhysicalSymptoms ?? false)
        self.hasActiveSafetyHold = hasActiveSafetyHold
        self.activeSafetyHoldSeverity = activeSafetyHoldSeverity
        self.activeSafetyHoldReason = activeSafetyHoldReason
        self.activeSafetyHoldRecheckDate = activeSafetyHoldRecheckDate
    }
}

public struct ImmediateActionRoute: Equatable, Sendable {
    public let destination: ImmediateActionDestination
    public let advisories: [ImmediateActionAdvisory]
    public let guidedEligibility: GuidedEligibility?
    public let activeSafetyHoldSeverity: RecommendationSeverity?
    public let activeSafetyHoldReason: String?
    public let activeSafetyHoldRecheckDate: Date?

    public init(
        destination: ImmediateActionDestination,
        advisories: [ImmediateActionAdvisory] = [],
        guidedEligibility: GuidedEligibility? = nil,
        activeSafetyHoldSeverity: RecommendationSeverity? = nil,
        activeSafetyHoldReason: String? = nil,
        activeSafetyHoldRecheckDate: Date? = nil
    ) {
        self.destination = destination
        self.advisories = advisories
        self.guidedEligibility = guidedEligibility
        self.activeSafetyHoldSeverity = activeSafetyHoldSeverity
        self.activeSafetyHoldReason = activeSafetyHoldReason
        self.activeSafetyHoldRecheckDate = activeSafetyHoldRecheckDate
    }
}

public struct ImmediateActionRouter: Sendable {
    public init() {}

    public func route(_ request: ImmediateActionRequest) -> ImmediateActionRoute {
        if request.hasCurrentPhysicalSymptoms {
            return ImmediateActionRoute(destination: .healthCheck)
        }
        if request.hasActiveSafetyHold {
            return safetyHoldRoute(for: request)
        }
        switch request.choice {
        case .reset:
            return ImmediateActionRoute(destination: .reset)
        case .guided:
            if request.guidedEligibility.isAllowed {
                return ImmediateActionRoute(destination: .guided)
            }
            return ImmediateActionRoute(
                destination: .guidedUnavailable,
                guidedEligibility: request.guidedEligibility
            )
        case .privateSession:
            var advisories: [ImmediateActionAdvisory] = []
            if request.anxiety >= 8 { advisories.append(.highAnxiety) }
            if let sleep = request.sleepHours, sleep < 5.5 { advisories.append(.lowSleep) }
            if let hours = request.hoursSinceLastGuidedSession, hours <= 24 { advisories.append(.recentGuidedSession) }
            if let hours = request.hoursSinceLastPrivateSession, hours < 24 { advisories.append(.recentPrivateSession) }
            if request.guidedSessionsLast7Days >= 3 { advisories.append(.frequentGuidedSessions) }
            return ImmediateActionRoute(destination: .privateSession, advisories: advisories)
        }
    }

    private func safetyHoldRoute(for request: ImmediateActionRequest) -> ImmediateActionRoute {
        let severity = request.activeSafetyHoldSeverity
        let reason = request.activeSafetyHoldReason
        let recheckDate = request.activeSafetyHoldRecheckDate
        let isIrritationOnly = severity == .caution &&
            reason?.localizedCaseInsensitiveContains("irritation") == true &&
            (recheckDate?.timeIntervalSinceNow ?? 0) > 0
        return ImmediateActionRoute(
            destination: isIrritationOnly ? .recoveryBlocked : .healthCheck,
            activeSafetyHoldSeverity: severity,
            activeSafetyHoldReason: reason,
            activeSafetyHoldRecheckDate: recheckDate
        )
    }
}

public enum GuidedEligibilityReason: String, Codable, Sendable, Hashable {
    case ready, baselineRequired, safetyHold, recoveryWindow, privateRecoveryWindow, weeklyLimit
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

/// The reason a private session left its active phase. It is intentionally
/// separate from guided-session reasons because private sessions are not
/// scored as guided training.
public enum PrivatePauseReason: String, Codable, Sendable, Hashable {
    case manual
    case threshold
    case emergency
    case interruption
}

/// Counts a private-session cycle at the moment recovery is genuinely safe.
/// Resuming starts a new active phase only; it can never increment a cycle a
/// second time. Interruption and non-assisted manual pauses are retained as
/// events but do not qualify as training cycles.
public struct PrivateSessionCycleTracker: Equatable, Sendable {
    public private(set) var completedCycles = 0
    public private(set) var currentCycleEligible = false
    public private(set) var recoveryQualified = false

    public init() {}

    public mutating func beginRecovery(reason: PrivatePauseReason, assistanceEnabled: Bool) {
        currentCycleEligible = reason != .interruption && (assistanceEnabled || reason == .emergency)
        recoveryQualified = false
    }

    @discardableResult
    public mutating func qualifyRecovery(
        elapsedSeconds: Int,
        intensity: Int,
        minimumRecoverySeconds: Int
    ) -> Bool {
        guard currentCycleEligible,
              !recoveryQualified,
              elapsedSeconds >= max(0, minimumRecoverySeconds),
              intensity <= 4 else { return false }
        recoveryQualified = true
        completedCycles += 1
        return true
    }

    public mutating func resumeActivePhase() {
        currentCycleEligible = false
        recoveryQualified = false
    }
}

public enum GuidedSessionState: String, Codable, Sendable, Hashable { case precheck, prepare, activeLow, activeRising, warning, pausedRecovery, resumeReady, completed, earlyCompletion, cancelled, safetyAbort, timeLimitReached }
public enum GuidedPauseReason: String, Codable, Sendable, Hashable { case manual, threshold, almostTooLate, interruption }
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
            return true
        }
        state = level >= 6 ? .activeRising : .activeLow
        return false
    }
    /// Keeps warning as a visible state until the UI has delivered its explicit warning cue.
    @discardableResult public mutating func advanceWarningToRecovery() -> Bool {
        guard state == .warning else { return false }
        state = .pausedRecovery
        return true
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
    @discardableResult public mutating func emergencyWarning() -> Bool {
        guard [.activeLow, .activeRising].contains(state) else { return false }
        lastPauseReason = .almostTooLate
        lateStopOccurred = true
        state = .warning
        return true
    }
    public mutating func recovered(level: Int, elapsedSeconds: Int, minimumSeconds: Int = 30) {
        guard state == .pausedRecovery, elapsedSeconds >= minimumSeconds, level <= 4 else { return }
        if lastPauseReason == .interruption { state = .resumeReady; return }
        cycles += 1
        state = cycles >= maximumCycles ? .completed : .resumeReady
    }
    public mutating func updateElapsed(totalSeconds: Int) {
        guard !isTerminal, state != .precheck else { return }
        elapsedSeconds = max(elapsedSeconds, max(0, totalSeconds))
        if elapsedSeconds >= maximumDurationSeconds { state = .timeLimitReached }
    }
    public mutating func complete() { guard !isTerminal, [.activeLow, .activeRising, .warning, .pausedRecovery, .resumeReady].contains(state) else { return }; state = .completed }
    public mutating func cancel() { guard !isTerminal else { return }; state = .cancelled }
    public mutating func earlyCompletion() { guard !isTerminal, [.activeLow, .activeRising, .warning, .pausedRecovery, .resumeReady].contains(state) else { return }; state = .earlyCompletion }
    public mutating func reachTimeLimit() { guard !isTerminal, state != .precheck else { return }; elapsedSeconds = maximumDurationSeconds; state = .timeLimitReached }
    public mutating func abortForSafety() { guard !isTerminal else { return }; state = .safetyAbort }
}

public enum ActivityKind: String, Codable, Sendable, Hashable { case guided, breathing, cardio, strength, recovery, education, review }
public struct PlanActivityResolver: Sendable {
    public init() {}
    public func effectiveKind(_ scheduledKind: ActivityKind, exerciseRestricted: Bool, guidedAllowed: Bool, isToday: Bool) -> ActivityKind {
        if exerciseRestricted && (scheduledKind == .cardio || scheduledKind == .strength) { return .recovery }
        if isToday && scheduledKind == .guided && !guidedAllowed { return .recovery }
        return scheduledKind
    }

    public func resolve(_ kind: ActivityKind, context: ProgramContext) -> (kind: ActivityKind, reasons: [PlanReason]) {
        if context.hasSafetyHold { return (.recovery, [.safetyHold]) }
        if context.exerciseRestricted && (kind == .cardio || kind == .strength) { return (.recovery, [.exerciseRestriction]) }
        if kind == .strength, !context.hasSafeActivitySpace {
            return context.canWalkTwentyMinutes ? (.cardio, [.unsafeActivitySpace]) : (.recovery, [.unsafeActivitySpace])
        }
        if kind == .guided {
            let eligibility = EligibilityEngine().guidedEligibility(for: context)
            if !eligibility.isAllowed {
                return (.recovery, [eligibility.reason == .privateRecoveryWindow ? .privateRecoveryWindow : .guidedRecoveryWindow])
            }
            if context.anxiety >= 8 { return (.breathing, [.highAnxiety]) }
            if (context.sleepHours ?? 8) < 5.5 { return (.recovery, [.lowSleep]) }
            if (context.energyToday ?? 10) <= 3 { return (.recovery, [.lowEnergy]) }
        }
        if (context.energyToday ?? 10) <= 3 && (kind == .cardio || kind == .strength) {
            return (.recovery, [.lowEnergy])
        }
        return (kind, [])
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
