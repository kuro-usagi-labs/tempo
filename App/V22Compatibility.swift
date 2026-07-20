import Foundation

extension ActivityPreference {
    /// Source-compatible spelling retained only for review-branch call sites.
    /// Persisted values and domain semantics remain `breathingAndMobility`.
    static var breathingMobility: ActivityPreference { .breathingAndMobility }
}

/// Shared formatter for V22 screens that do not already own a file-private
/// formatter. The generic signature intentionally avoids redeclaring the
/// existing private `(Int) -> String` helper in the private-session file.
func tempoV22Duration<T: BinaryInteger>(_ seconds: T) -> String {
    let safe = max(0, Int(seconds))
    return "\(safe / 60):\(String(format: "%02d", safe % 60))"
}
