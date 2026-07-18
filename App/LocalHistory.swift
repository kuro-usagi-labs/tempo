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

@Observable
@MainActor
final class LocalHistory {
    private(set) var checkIns: [LocalCheckIn] = []
    private(set) var sessions: [LocalSession] = []
    private let storageKey = "tempo.local.checkins.v1"
    private let sessionStorageKey = "tempo.local.sessions.v1"

    init() { load() }

    func add(intensity: Int, trigger: UrgeTrigger, intent: UrgeIntent, recommendation: Recommendation) {
        checkIns.insert(LocalCheckIn(id: UUID(), createdAt: .now, intensity: intensity, trigger: trigger.rawValue, intent: intent.rawValue, action: recommendation.action.rawValue, blocksTraining: recommendation.blocksGuidedTraining), at: 0)
        checkIns = Array(checkIns.prefix(100))
        save()
    }

    func addSession(cycles: Int, terminalState: GuidedSessionState, durationSeconds: Int? = nil, postAnxiety: Int? = nil, postTension: Int? = nil, irritationAfter: Bool? = nil, outcome: String? = nil) {
        sessions.insert(LocalSession(id: UUID(), completedAt: .now, cycles: cycles, terminalState: terminalState.rawValue, durationSeconds: durationSeconds, postAnxiety: postAnxiety, postTension: postTension, irritationAfter: irritationAfter, outcome: outcome), at: 0)
        sessions = Array(sessions.prefix(100))
        save(sessions, for: sessionStorageKey)
    }

    func deleteAll() {
        checkIns = []
        sessions = []
        SecureLocalStore.remove(storageKey)
        SecureLocalStore.remove(sessionStorageKey)
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
    }

    private func load() {
        checkIns = load([LocalCheckIn].self, for: storageKey, defaultValue: [])
        sessions = load([LocalSession].self, for: sessionStorageKey, defaultValue: [])
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
}
