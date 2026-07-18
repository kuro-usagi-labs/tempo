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

@Observable
@MainActor
final class LocalHistory {
    private(set) var checkIns: [LocalCheckIn] = []
    private let storageKey = "tempo.local.checkins.v1"

    init() { load() }

    func add(intensity: Int, trigger: UrgeTrigger, intent: UrgeIntent, recommendation: Recommendation) {
        checkIns.insert(LocalCheckIn(id: UUID(), createdAt: .now, intensity: intensity, trigger: trigger.rawValue, intent: intent.rawValue, action: recommendation.action.rawValue, blocksTraining: recommendation.blocksGuidedTraining), at: 0)
        checkIns = Array(checkIns.prefix(100))
        save()
    }

    func deleteAll() { checkIns = []; UserDefaults.standard.removeObject(forKey: storageKey) }
    private func load() { guard let data = UserDefaults.standard.data(forKey: storageKey), let decoded = try? JSONDecoder().decode([LocalCheckIn].self, from: data) else { return }; checkIns = decoded }
    private func save() { guard let data = try? JSONEncoder().encode(checkIns) else { return }; UserDefaults.standard.set(data, forKey: storageKey) }
}
