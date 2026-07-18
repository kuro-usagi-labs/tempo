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

struct LocalSession: Codable, Identifiable {
    let id: UUID
    let completedAt: Date
    let cycles: Int
    let terminalState: String
    let durationSeconds: Int?
    let postAnxiety: Int?
    let postTension: Int?
    let irritationAfter: Bool?
    let outcome: String?
}

struct LocalExerciseLog: Codable, Identifiable {
    let id: UUID
    let completedAt: Date
    let kind: String
    let durationMinutes: Int
}

struct LocalBaseline: Codable {
    let completedAt: Date
    let onset: String
    let difficultyContext: String
    let perceivedControl: Int
    let anxiety: Int
    let sleepHours: Int
    let activityLevel: String
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
    private let storageKey = "tempo.local.checkins.v1"
    private let sessionStorageKey = "tempo.local.sessions.v1"
    private let profileStorageKey = "tempo.local.profile.v1"
    private let exerciseStorageKey = "tempo.local.exercises.v1"

    var baseline: LocalBaseline? { profile.baseline }
    var activeSafetyHold: LocalSafetyHold? { profile.safetyHolds.last { $0.resolvedAt == nil } }
    var effectiveProgramPhase: ProgramPhase {
        if activeSafetyHold != nil { return .safetyHold }
        if baseline == nil { return .assessmentRequired }
        return profile.programPhase
    }
    var hoursSinceLastSession: Double? { sessions.first.map { Date.now.timeIntervalSince($0.completedAt) / 3_600 } }
    var guidedSessionsLast7Days: Int { sessions.filter { $0.completedAt >= Date.now.addingTimeInterval(-7 * 86_400) && $0.terminalState != GuidedSessionState.cancelled.rawValue }.count }
    var scoreSnapshot: ScoreSnapshot {
        let sessionCount = max(1, sessions.count)
        let completed = Double(sessions.filter { $0.terminalState == GuidedSessionState.completed.rawValue }.count) / Double(sessionCount)
        let recovered = Double(sessions.filter { $0.cycles > 0 }.count) / Double(sessionCount)
        let earlyAwareness = Double(sessions.filter { $0.terminalState == GuidedSessionState.earlyCompletion.rawValue || $0.cycles > 0 }.count) / Double(sessionCount)
        let logging = checkIns.isEmpty ? 0 : 1.0
        let reflection = Double(sessions.filter { $0.postTension != nil }.count) / Double(sessionCount)
        let adherenceBase = min(1, Double(exercises.count + sessions.count) / 7.0)
        return ScoreCalculator().calculate(ScoreInputs(earlyPauseRate: earlyAwareness, loggingCompleteness: logging, tensionRecognitionRate: reflection, escalationPredictionRate: earlyAwareness, successfulCycleRatio: recovered, controlledCompletionRatio: completed, thresholdCompliance: recovered, recoveryCompletionRatio: recovered, calmRate: completed, adherenceRate: adherenceBase))
    }

    func makeExportData() -> Data? {
        try? JSONEncoder().encode(LocalExportSnapshot(exportedAt: .now, rulesetVersion: RuleEngine.rulesetVersion, profile: profile, checkIns: checkIns, sessions: sessions, exercises: exercises))
    }

    init() { load() }

    func add(intensity: Int, trigger: UrgeTrigger, intent: UrgeIntent, recommendation: Recommendation) {
        checkIns.insert(LocalCheckIn(id: UUID(), createdAt: .now, intensity: intensity, trigger: trigger.rawValue, intent: intent.rawValue, action: recommendation.action.rawValue, blocksTraining: recommendation.blocksGuidedTraining), at: 0)
        checkIns = Array(checkIns.prefix(100))
        save()
        if recommendation.blocksGuidedTraining && recommendation.reasonCode.hasPrefix("safety.") {
            _ = recordSafetyHold(reasonCode: recommendation.reasonCode, severity: recommendation.severity.rawValue, source: "urge-check-in")
        }
    }

    func addSession(cycles: Int, terminalState: GuidedSessionState, durationSeconds: Int? = nil, postAnxiety: Int? = nil, postTension: Int? = nil, irritationAfter: Bool? = nil, outcome: String? = nil) {
        sessions.insert(LocalSession(id: UUID(), completedAt: .now, cycles: cycles, terminalState: terminalState.rawValue, durationSeconds: durationSeconds, postAnxiety: postAnxiety, postTension: postTension, irritationAfter: irritationAfter, outcome: outcome), at: 0)
        sessions = Array(sessions.prefix(100))
        save(sessions, for: sessionStorageKey)
        if irritationAfter == true {
            _ = recordSafetyHold(reasonCode: "safety.post-session-irritation", severity: RecommendationSeverity.caution.rawValue, source: "guided-session")
        }
    }

    func addExercise(kind: String, durationMinutes: Int) {
        exercises.insert(LocalExerciseLog(id: UUID(), completedAt: .now, kind: kind, durationMinutes: durationMinutes), at: 0)
        exercises = Array(exercises.prefix(100))
        save(exercises, for: exerciseStorageKey)
    }

    @discardableResult
    func saveBaseline(_ baseline: LocalBaseline) -> Bool {
        var updated = profile
        updated.baseline = baseline
        if baseline.hasSafetySymptoms {
            updated.safetyHolds.append(LocalSafetyHold(id: UUID(), createdAt: .now, reasonCode: "safety.baseline", severity: RecommendationSeverity.medical.rawValue, source: "baseline", resolvedAt: nil))
        }
        guard persistProfile(updated) else { return false }
        profile = updated
        return true
    }

    @discardableResult
    func recordSafetyHold(reasonCode: String, severity: String, source: String) -> Bool {
        if activeSafetyHold?.reasonCode == reasonCode { return true }
        var updated = profile
        updated.safetyHolds.append(LocalSafetyHold(id: UUID(), createdAt: .now, reasonCode: reasonCode, severity: severity, source: source, resolvedAt: nil))
        guard persistProfile(updated) else { return false }
        profile = updated
        return true
    }

    @discardableResult
    func resolveSafetyHoldsAfterClearRecheck() -> Bool {
        var updated = profile
        let now = Date.now
        for index in updated.safetyHolds.indices where updated.safetyHolds[index].resolvedAt == nil {
            updated.safetyHolds[index].resolvedAt = now
        }
        guard persistProfile(updated) else { return false }
        profile = updated
        return true
    }

    func deleteAll() {
        checkIns = []
        sessions = []
        SecureLocalStore.remove(storageKey)
        SecureLocalStore.remove(sessionStorageKey)
        SecureLocalStore.remove(profileStorageKey)
        SecureLocalStore.remove(exerciseStorageKey)
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
        profile = LocalProfileState()
        exercises = []
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
        if let data = SecureLocalStore.data(for: key), let decoded = try? JSONDecoder().decode(T.self, from: data) { return decoded }
        if let legacyData = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode(T.self, from: legacyData) {
            if SecureLocalStore.store(legacyData, for: key) { UserDefaults.standard.removeObject(forKey: key) }
            return decoded
        }
        return defaultValue
    }

    private func save() {
        save(checkIns, for: storageKey)
    }

    private func save<T: Encodable>(_ value: T, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        SecureLocalStore.store(data, for: key)
    }

    private func persistProfile(_ value: LocalProfileState) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return SecureLocalStore.store(data, for: profileStorageKey)
    }
}
