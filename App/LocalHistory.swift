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

    func addSession(cycles: Int, terminalState: GuidedSessionState) { sessions.insert(LocalSession(id: UUID(), completedAt: .now, cycles: cycles, terminalState: terminalState.rawValue), at: 0); sessions = Array(sessions.prefix(100)); guard let data = try? JSONEncoder().encode(sessions) else { return }; UserDefaults.standard.set(data, forKey: sessionStorageKey) }
    func deleteAll() { checkIns = []; sessions = []; UserDefaults.standard.removeObject(forKey: storageKey); UserDefaults.standard.removeObject(forKey: sessionStorageKey) }
    private func load() { if let data = UserDefaults.standard.data(forKey: storageKey), let decoded = try? JSONDecoder().decode([LocalCheckIn].self, from: data) { checkIns = decoded }; if let data = UserDefaults.standard.data(forKey: sessionStorageKey), let decoded = try? JSONDecoder().decode([LocalSession].self, from: data) { sessions = decoded } }
    private func save() { guard let data = try? JSONEncoder().encode(checkIns) else { return }; UserDefaults.standard.set(data, forKey: storageKey) }
}
