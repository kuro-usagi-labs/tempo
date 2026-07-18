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
}

struct LocalExerciseLog: Codable, Identifiable {
    let id: UUID
    let completedAt: Date
    let kind: String
    let durationMinutes: Int
    let perceivedDifficulty: Int?
    let painReported: Bool?
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
    var schemaVersion = 1
    var baseline: LocalBaseline?
    var safetyHolds: [LocalSafetyHold] = []
    var programPhase: ProgramPhase = .awareness
}

private struct LocalExportSnapshot: Codable {
    let exportedAt: Date
    let rulesetVersion: String
    let profile: LocalProfileState
    let checkIns: [LocalCheckIn]
    let sessions: [LocalSession]
    let exercises: [LocalExerciseLog]
}

@Observable
@MainActor
final class LocalHistory {
    private(set) var checkIns: [LocalCheckIn] = []
    private(set) var sessions: [LocalSession] = []
    private(set) var exercises: [LocalExerciseLog] = []
    private var profile = LocalProfileState()
    private(set) var hasPendingSafetyWrite = false
    private let storageKey = "tempo.local.checkins.v1"
    private let sessionStorageKey = "tempo.local.sessions.v1"
    private let profileStorageKey = "tempo.local.profile.v1"
    private let exerciseStorageKey = "tempo.local.exercises.v1"
    private let pendingSafetyStorageKey = "tempo.pending-safety-lock.v1"

    var baseline: LocalBaseline? { profile.baseline }
    var safetyHoldCount: Int { profile.safetyHolds.count }
    var activeSafetyHold: LocalSafetyHold? { profile.safetyHolds.last { $0.resolvedAt == nil } }
    var hasSafetyBlock: Bool { activeSafetyHold != nil || hasPendingSafetyWrite }
    var guidedEligibility: GuidedEligibility {
        GuidedEligibilityEvaluator().evaluate(
            programPhase: effectiveProgramPhase,
            hoursSinceLastSession: hoursSinceLastSession,
            guidedSessionsLast7Days: guidedSessionsLast7Days
        )
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
    var guidedSessionsLast7Days: Int { trainingSessions.filter { $0.completedAt >= Date.now.addingTimeInterval(-7 * 86_400) }.count }
    private var trainingSessions: [LocalSession] {
        sessions.filter { [GuidedSessionState.completed.rawValue, GuidedSessionState.earlyCompletion.rawValue, GuidedSessionState.timeLimitReached.rawValue].contains($0.terminalState) }
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
        let activeDays = Set(trainingSessions.filter { $0.completedAt >= cutoff }.map { Calendar.current.startOfDay(for: $0.completedAt) } + exercises.filter { $0.completedAt >= cutoff }.map { Calendar.current.startOfDay(for: $0.completedAt) })
        let adherenceBase = min(1, Double(activeDays.count) / 5.0)
        return ScoreCalculator().calculate(ScoreInputs(earlyPauseRate: earlyAwareness, loggingCompleteness: logging, tensionRecognitionRate: reflection, escalationPredictionRate: thresholdCompliance, successfulCycleRatio: recovered, controlledCompletionRatio: completed, thresholdCompliance: thresholdCompliance, recoveryCompletionRatio: recovered, calmRate: calm, adherenceRate: adherenceBase))
    }

    func makeExportData() -> Data? {
        try? JSONEncoder().encode(LocalExportSnapshot(exportedAt: .now, rulesetVersion: RuleEngine.rulesetVersion, profile: profile, checkIns: checkIns, sessions: sessions, exercises: exercises))
    }

    init() {
        hasPendingSafetyWrite = UserDefaults.standard.bool(forKey: pendingSafetyStorageKey)
        load()
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
    func addSession(startedAt: Date? = nil, cycles: Int, terminalState: GuidedSessionState, targetCycles: Int? = nil, pauseThreshold: Int? = nil, maximumDurationSeconds: Int? = nil, preAnxiety: Int? = nil, durationSeconds: Int? = nil, lateStopOccurred: Bool? = nil, postAnxiety: Int? = nil, postTension: Int? = nil, painAfter: Bool? = nil, irritationAfter: Bool? = nil, outcome: String? = nil, note: String? = nil, arousalEvents: [LocalArousalEvent]? = nil, pauseCycles: [LocalPauseCycle]? = nil) -> Bool {
        if painAfter == true {
            guard recordSafetyHold(reasonCode: "safety.post-session-pain", severity: RecommendationSeverity.urgent.rawValue, source: "guided-session") else { return false }
        } else if irritationAfter == true {
            guard recordSafetyHold(reasonCode: "safety.post-session-irritation", severity: RecommendationSeverity.caution.rawValue, source: "guided-session") else { return false }
        }
        var updated = sessions
        updated.insert(LocalSession(id: UUID(), startedAt: startedAt, completedAt: .now, cycles: cycles, terminalState: terminalState.rawValue, targetCycles: targetCycles, pauseThreshold: pauseThreshold, maximumDurationSeconds: maximumDurationSeconds, preAnxiety: preAnxiety, durationSeconds: durationSeconds, lateStopOccurred: lateStopOccurred, postAnxiety: postAnxiety, postTension: postTension, painAfter: painAfter, irritationAfter: irritationAfter, outcome: outcome, note: note, arousalEvents: arousalEvents, pauseCycles: pauseCycles), at: 0)
        let rawEventCutoff = Date.now.addingTimeInterval(-90 * 86_400)
        updated = updated.map { $0.completedAt < rawEventCutoff ? sessionDroppingRawEvents($0) : $0 }
        updated = Array(updated.prefix(520))
        guard save(updated, for: sessionStorageKey) else { return false }
        sessions = updated
        return true
    }

    @discardableResult
    func addExercise(kind: String, durationMinutes: Int, perceivedDifficulty: Int? = nil, painReported: Bool? = nil) -> Bool {
        var updated = exercises
        updated.insert(LocalExerciseLog(id: UUID(), completedAt: .now, kind: kind, durationMinutes: durationMinutes, perceivedDifficulty: perceivedDifficulty, painReported: painReported), at: 0)
        updated = Array(updated.prefix(100))
        guard save(updated, for: exerciseStorageKey) else { return false }
        exercises = updated
        return true
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
            }
            return true
        }
        updated.safetyHolds.append(LocalSafetyHold(id: UUID(), createdAt: .now, reasonCode: reasonCode, severity: severity, source: source, recheckNotBefore: notBefore, resolvedAt: nil))
        guard persistProfile(updated) else { markPendingSafetyWrite(); return false }
        profile = updated
        clearPendingSafetyWrite()
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
        return true
    }

    @discardableResult
    func deleteAll() -> Bool {
        guard ProtectedFileStore.removeAll(), SecureLocalStore.removeAll() else { return false }
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
        checkIns = []
        sessions = []
        profile = LocalProfileState()
        exercises = []
        hasPendingSafetyWrite = false
        UserDefaults.standard.removeObject(forKey: pendingSafetyStorageKey)
        return true
    }

    @discardableResult
    func deleteAllNotes() -> Bool {
        let updated = sessions.map { value in
            LocalSession(id: value.id, startedAt: value.startedAt, completedAt: value.completedAt, cycles: value.cycles, terminalState: value.terminalState, targetCycles: value.targetCycles, pauseThreshold: value.pauseThreshold, maximumDurationSeconds: value.maximumDurationSeconds, preAnxiety: value.preAnxiety, durationSeconds: value.durationSeconds, lateStopOccurred: value.lateStopOccurred, postAnxiety: value.postAnxiety, postTension: value.postTension, painAfter: value.painAfter, irritationAfter: value.irritationAfter, outcome: value.outcome, note: nil, arousalEvents: value.arousalEvents, pauseCycles: value.pauseCycles)
        }
        guard save(updated, for: sessionStorageKey) else { return false }
        sessions = updated
        return true
    }

    private func load() {
        checkIns = load([LocalCheckIn].self, for: storageKey, defaultValue: [])
        sessions = load([LocalSession].self, for: sessionStorageKey, defaultValue: [])
        profile = load(LocalProfileState.self, for: profileStorageKey, defaultValue: LocalProfileState())
        exercises = load([LocalExerciseLog].self, for: exerciseStorageKey, defaultValue: [])
        if profile.safetyHolds.isEmpty, let blocked = checkIns.first(where: \.blocksTraining) {
            _ = recordSafetyHold(reasonCode: "safety.migrated.\(blocked.action)", severity: RecommendationSeverity.medical.rawValue, source: "migration")
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
        LocalSession(id: value.id, startedAt: value.startedAt, completedAt: value.completedAt, cycles: value.cycles, terminalState: value.terminalState, targetCycles: value.targetCycles, pauseThreshold: value.pauseThreshold, maximumDurationSeconds: value.maximumDurationSeconds, preAnxiety: value.preAnxiety, durationSeconds: value.durationSeconds, lateStopOccurred: value.lateStopOccurred, postAnxiety: value.postAnxiety, postTension: value.postTension, painAfter: value.painAfter, irritationAfter: value.irritationAfter, outcome: value.outcome, note: value.note, arousalEvents: nil, pauseCycles: nil)
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
