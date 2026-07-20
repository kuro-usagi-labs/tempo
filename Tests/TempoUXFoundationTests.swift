import XCTest
@testable import Tempo

final class TempoUXFoundationTests: XCTestCase {
    func testIntensityZoneMappingPreservesLegacyNumericCompatibility() {
        XCTAssertEqual(TempoIntensityZone.calm.numericValue, 2)
        XCTAssertEqual(TempoIntensityZone.rising.numericValue, 4)
        XCTAssertEqual(TempoIntensityZone.medium.numericValue, 6)
        XCTAssertEqual(TempoIntensityZone.nearLimit.numericValue, 7)
        XCTAssertEqual(TempoIntensityZone.critical.numericValue, 9)

        XCTAssertEqual(TempoIntensityZone(numericValue: 1), .calm)
        XCTAssertEqual(TempoIntensityZone(numericValue: 3), .calm)
        XCTAssertEqual(TempoIntensityZone(numericValue: 5), .rising)
        XCTAssertEqual(TempoIntensityZone(numericValue: 6), .medium)
        XCTAssertEqual(TempoIntensityZone(numericValue: 8), .nearLimit)
        XCTAssertEqual(TempoIntensityZone(numericValue: 10), .critical)
    }

    func testMovementFrequencyMapsToPersistedWeeklyMinutes() {
        XCTAssertEqual(TempoMovementFrequency.rarely.weeklyMinutes, 0)
        XCTAssertEqual(TempoMovementFrequency.onceOrTwice.weeklyMinutes, 60)
        XCTAssertEqual(TempoMovementFrequency.threeOrFour.weeklyMinutes, 150)
        XCTAssertEqual(TempoMovementFrequency.almostDaily.weeklyMinutes, 240)
        XCTAssertEqual(TempoMovementFrequency(weeklyMinutes: 0), .rarely)
        XCTAssertEqual(TempoMovementFrequency(weeklyMinutes: 75), .onceOrTwice)
        XCTAssertEqual(TempoMovementFrequency(weeklyMinutes: 180), .threeOrFour)
        XCTAssertEqual(TempoMovementFrequency(weeklyMinutes: 300), .almostDaily)
    }

    func testOnboardingDraftPersistsAndClearsWithoutTouchingDomainHistory() {
        let suiteName = "tempo.ux-foundation-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var draft = TempoOnboardingDraft()
        draft.step = 4
        draft.adultConfirmed = true
        draft.activityPreference = .breathingAndMobility
        draft.movementFrequency = .threeOrFour
        draft.severeOrPelvicPain = true

        XCTAssertTrue(TempoOnboardingDraftStore.save(draft, defaults: defaults))
        XCTAssertEqual(TempoOnboardingDraftStore.load(defaults: defaults), draft)
        TempoOnboardingDraftStore.clear(defaults: defaults)
        XCTAssertNil(TempoOnboardingDraftStore.load(defaults: defaults))
    }

    func testCalendarVisualResolverUsesStatusAndLinkageRatherThanColorOnly() {
        let now = Date.now
        let planned = makePlan(status: .planned, date: now)
        let completed = makePlan(status: .completed, date: now)
        let adapted = makePlan(status: .adapted, date: now)
        let skipped = makePlan(status: .skipped, date: now)
        let recovery = makePlan(status: .recovery, date: now, kind: .recovery)
        let replacement = makePlan(status: .adapted, date: now, rescheduledFromID: UUID())

        XCTAssertEqual(TempoCalendarVisualResolver.state(for: []), .empty)
        XCTAssertEqual(TempoCalendarVisualResolver.state(for: [planned]), .upcoming)
        XCTAssertEqual(TempoCalendarVisualResolver.state(for: [completed]), .completed)
        XCTAssertEqual(TempoCalendarVisualResolver.state(for: [adapted]), .adapted)
        XCTAssertEqual(TempoCalendarVisualResolver.state(for: [skipped]), .skipped)
        XCTAssertEqual(TempoCalendarVisualResolver.state(for: [recovery]), .recovery)
        XCTAssertEqual(TempoCalendarVisualResolver.state(for: [replacement]), .replacement)
        XCTAssertNotEqual(TempoCalendarDayVisualState.completed.symbol, TempoCalendarDayVisualState.upcoming.symbol)
    }

    func testProgressTrendDoesNotClaimDirectionBelowThreeSamples() {
        let now = Date.now
        let sessions = [
            makeSession(completedAt: now.addingTimeInterval(-60), recovery: 50, postAnxiety: 5),
            makeSession(completedAt: now, recovery: 45, postAnxiety: 4)
        ]
        let trends = TempoProgressTrendEngine().trends(
            sessions: sessions,
            privateSessions: [],
            plan: []
        )

        XCTAssertEqual(trends.first { $0.kind == .recovery }?.state, .insufficient)
        XCTAssertEqual(trends.first { $0.kind == .sessionAnxiety }?.state, .insufficient)
        XCTAssertFalse(trends.contains { $0.sampleCount < 3 && $0.state == .improving })
    }

    func testProgressTrendUsesTwoThreeSessionWindowsBeforeDirectionalClaim() {
        let now = Date.now
        let recoveries = [90, 85, 80, 55, 50, 45]
        let sessions = recoveries.enumerated().map { index, recovery in
            makeSession(
                completedAt: now.addingTimeInterval(Double(index - recoveries.count) * 86_400),
                recovery: recovery,
                postAnxiety: max(1, 8 - index)
            )
        }
        let trends = TempoProgressTrendEngine().trends(
            sessions: sessions,
            privateSessions: [],
            plan: []
        )

        let recovery = trends.first { $0.kind == .recovery }
        XCTAssertEqual(recovery?.state, .improving)
        XCTAssertEqual(recovery?.sampleCount, 6)
        XCTAssertNotNil(recovery?.previousValue)
        XCTAssertNotNil(recovery?.currentValue)
    }

    private func makePlan(
        status: LocalPlanStatus,
        date: Date,
        kind: ActivityKind = .guided,
        rescheduledFromID: UUID? = nil
    ) -> LocalPlanDay {
        LocalPlanDay(
            id: UUID(),
            date: date,
            kind: kind,
            status: status,
            phase: .awareness,
            generatedAt: date,
            rulesetVersion: RulesetVersion.current.rawValue,
            scheduledAt: date,
            estimatedMinutes: 10,
            reasonCodes: [PlanReason.awarenessFoundation.rawValue],
            adaptationReasonCodes: rescheduledFromID == nil ? nil : [PlanReason.safeReschedule.rawValue],
            adaptedAt: rescheduledFromID == nil ? nil : date,
            rescheduledFromID: rescheduledFromID,
            revision: 1,
            completedAt: status == .completed ? date : nil,
            performedKind: status == .completed ? kind : nil
        )
    }

    private func makeSession(completedAt: Date, recovery: Int, postAnxiety: Int) -> LocalSession {
        LocalSession(
            id: UUID(),
            startedAt: completedAt.addingTimeInterval(-600),
            completedAt: completedAt,
            cycles: 1,
            terminalState: GuidedSessionState.completed.rawValue,
            targetCycles: 2,
            pauseThreshold: 7,
            maximumDurationSeconds: 1_200,
            preAnxiety: postAnxiety + 1,
            durationSeconds: 600,
            lateStopOccurred: false,
            postAnxiety: postAnxiety,
            postTension: postAnxiety,
            painAfter: false,
            irritationAfter: false,
            outcome: GuidedSessionState.completed.rawValue,
            note: nil,
            arousalEvents: [],
            pauseCycles: [
                LocalPauseCycle(
                    index: 1,
                    startOffset: 100,
                    endOffset: 100 + recovery,
                    arousalBefore: 6,
                    arousalAfter: 3,
                    lateStop: false,
                    successful: true
                )
            ],
            sessionType: "guided",
            activeSeconds: 500,
            recoverySeconds: recovery,
            rulesetVersion: RulesetVersion.current.rawValue
        )
    }
}
