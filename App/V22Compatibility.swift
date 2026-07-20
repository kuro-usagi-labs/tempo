import Foundation

extension ActivityPreference {
    /// Source-compatible spelling retained only for review-branch call sites.
    /// Persisted values and domain semantics remain `breathingAndMobility`.
    static var breathingMobility: ActivityPreference { .breathingAndMobility }
}

/// Shared formatter for the new private and guided session presentations.
/// It is intentionally separate from the old file-private helpers.
func tempoV22Duration(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    return "\(safe / 60):\(String(format: "%02d", safe % 60))"
}
