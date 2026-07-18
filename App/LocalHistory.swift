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

@Observable
@MainActor
final class LocalHistory {
    private(set) var checkIns: [LocalCheckIn] = []
    private(set) var sessions: [LocalSession] = []
    private var profile = LocalProfileState()
    private let storageKey = "tempo.local.checkins.v1"
    private let sessionStorageKey = "tempo.local.sessions.v1"
    private let profileStorageKey = "tempo.local.profile.v1"

    var baseline: LocalBaseline? { profile.baseline }
    var activeSafetyHold: LocalSafetyHold? { profile.safetyHolds.last { $0.resolvedAt == nil } }
    var effectiveProgramPhase: ProgramPhase {
        if activeSafetyHold != nil { return .safetyHold }
        if baseline == nil { return .assessmentRequired }
        return profile.programPhase
    }

    init() { load() }

    func add(intensity: Int, trigger: UrgeTrigger, intent: UrgeIntent, recommendation: Recommendation) {
        checkIns.insert(LocalCheckIn(id: UUID(), createdAt: .now, intensity: intensity, trigger: trigger.rawValue, intent: intent.rawValue, action: recommendation.action.rawValue, blocksTraining: recommendation.blocksGuidedTraining), at: 0)
        checkIns = Array(checkIns.prefix(100))
        save()
        if recommendation.blocksGuidedTraining {
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
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
        profile = LocalProfileState()
    }

    private func load() {
        checkIns = load([LocalCheckIn].self, for: storageKey, defaultValue: [])
        sessions = load([LocalSession].self, for: sessionStorageKey, defaultValue: [])
        profile = load(LocalProfileState.self, for: profileStorageKey, defaultValue: LocalProfileState())
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
