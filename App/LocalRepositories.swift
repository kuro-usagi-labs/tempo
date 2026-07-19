import Foundation

/// Narrow persistence adapters keep storage details out of the plan/session
/// rules. `LocalHistory` remains the observable façade for the SwiftUI app,
/// while these repositories own the protected blobs and can migrate legacy
/// values through the façade's fallback path.
protocol TempoLocalRepository {
    associatedtype Value: Codable
    func read() -> Value?
    func write(_ value: Value) -> Bool
}

struct LocalPlanRepository: TempoLocalRepository {
    typealias Value = [LocalPlanDay]
    let key = "tempo.local.plan.v1"

    func read() -> [LocalPlanDay]? {
        guard let data = ProtectedFileStore.data(for: key) else { return nil }
        return try? JSONDecoder().decode([LocalPlanDay].self, from: data)
    }

    func write(_ value: [LocalPlanDay]) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return ProtectedFileStore.store(data, for: key)
    }
}

struct LocalPrivateSessionRepository: TempoLocalRepository {
    typealias Value = [LocalPrivateSession]
    let key = "tempo.local.private-sessions.v2"

    func read() -> [LocalPrivateSession]? {
        guard let data = ProtectedFileStore.data(for: key) else { return nil }
        return try? JSONDecoder().decode([LocalPrivateSession].self, from: data)
    }

    func write(_ value: [LocalPrivateSession]) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return ProtectedFileStore.store(data, for: key)
    }
}
