import Foundation

extension ActivityPreference {
    /// Source-compatible spelling used by the review-only UX layer. The domain
    /// and persisted raw value remain `breathingAndMobility`.
    static var breathingMobility: ActivityPreference { .breathingAndMobility }
}
