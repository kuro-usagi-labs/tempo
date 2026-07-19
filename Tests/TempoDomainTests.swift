import XCTest
@testable import Tempo

final class TempoDomainTests: XCTestCase {
    func testImmediateRouterKeepsPrivateChoiceAtHighIntensity() {
        let route = ImmediateActionRouter().route(ImmediateActionRequest(choice: .privateSession, intensity: 9))
        XCTAssertEqual(route.destination, .privateSession)
    }

    func testImmediateRouterUsesAdvisoryWithoutBlockingPrivateChoice() {
        let route = ImmediateActionRouter().route(ImmediateActionRequest(
            choice: .privateSession,
            intensity: 9,
            anxiety: 9,
            hoursSinceLastGuidedSession: 6
        ))
        XCTAssertEqual(route.destination, .privateSession)
        XCTAssertTrue(route.advisories.contains(.highAnxiety))
        XCTAssertTrue(route.advisories.contains(.recentGuidedSession))
    }

    func testImmediateRouterUsesExplicitDestinationsAndPhysicalSafetyOverride() {
        let eligible = GuidedEligibility(isAllowed: true, reason: .ready, message: "Tersedia")
        let blocked = GuidedEligibility(isAllowed: false, reason: .recoveryWindow, message: "Pulih dulu")
        XCTAssertEqual(ImmediateActionRouter().route(ImmediateActionRequest(choice: .reset, intensity: 10)).destination, .reset)
        XCTAssertEqual(ImmediateActionRouter().route(ImmediateActionRequest(choice: .guided, intensity: 8, guidedEligibility: eligible)).destination, .guided)
        XCTAssertEqual(ImmediateActionRouter().route(ImmediateActionRequest(choice: .guided, intensity: 8, guidedEligibility: blocked)).destination, .guidedUnavailable)
        XCTAssertEqual(ImmediateActionRouter().route(ImmediateActionRequest(choice: .privateSession, intensity: 5, hasPhysicalSymptoms: true)).destination, .healthCheck)
    }

    func testImmediateRouterActiveMedicalHoldBlocksResetAndPrivateSession() {
        for choice in [ImmediateActionChoice.reset, .privateSession, .guided] {
            let result = ImmediateActionRouter().route(ImmediateActionRequest(
                choice: choice,
                intensity: 8,
                hasActiveSafetyHold: true,
                activeSafetyHoldSeverity: .medical,
                activeSafetyHoldReason: "safety.urinary"
            ))
            XCTAssertEqual(result.destination, .healthCheck)
        }
    }

    func testImmediateRouterActiveIrritationHoldUsesRecoveryBlockUntilRecheck() {
        let recheck = Date.now.addingTimeInterval(3_600)
        let result = ImmediateActionRouter().route(ImmediateActionRequest(
            choice: .privateSession,
            intensity: 6,
            hasActiveSafetyHold: true,
            activeSafetyHoldSeverity: .caution,
            activeSafetyHoldReason: "safety.irritation",
            activeSafetyHoldRecheckDate: recheck
        ))
        XCTAssertEqual(result.destination, .recoveryBlocked)
        XCTAssertEqual(result.activeSafetyHoldRecheckDate, recheck)
    }

    func testPrivateSessionCycleQualifiesBeforeResumeAndNeverDoubleCounts() {
        var tracker = PrivateSessionCycleTracker()
        tracker.beginRecovery(reason: .manual, assistanceEnabled: true)
        XCTAssertTrue(tracker.qualifyRecovery(elapsedSeconds: 30, intensity: 4, minimumRecoverySeconds: 30))
        tracker.resumeActivePhase()
        XCTAssertFalse(tracker.qualifyRecovery(elapsedSeconds: 60, intensity: 3, minimumRecoverySeconds: 30))
        XCTAssertEqual(tracker.completedCycles, 1)
    }

    func testPrivateInterruptionNeverQualifiesAsTrainingCycle() {
        var tracker = PrivateSessionCycleTracker()
        tracker.beginRecovery(reason: .interruption, assistanceEnabled: true)
        XCTAssertFalse(tracker.qualifyRecovery(elapsedSeconds: 60, intensity: 3, minimumRecoverySeconds: 30))
        XCTAssertEqual(tracker.completedCycles, 0)
    }

    func testSafetyAlwaysBlocksTraining() { var c = DecisionContext(); c.urgeIntensity = 9; c.intent = .training; c.urinaryBurning = true; let r = RuleEngine().evaluate(c); XCTAssertEqual(r.action, .healthCheck); XCTAssertTrue(r.blocksGuidedTraining) }
    func testRecentSessionRoutesToRecovery() { var c = DecisionContext(); c.programPhase = .awareness; c.hoursSinceLastSession = 6; c.intent = .training; XCTAssertEqual(RuleEngine().evaluate(c).action, .recovery) }
    func testGuidedSessionNeedsRecoveryBeforeResume() { var s = GuidedSessionMachine(); s.start(); s.beginActive(); XCTAssertTrue(s.rising(level: 7, threshold: 7)); XCTAssertEqual(s.state, .warning); XCTAssertTrue(s.advanceWarningToRecovery()); s.recovered(level: 5, elapsedSeconds: 30); XCTAssertEqual(s.state, .pausedRecovery); s.recovered(level: 4, elapsedSeconds: 30); XCTAssertEqual(s.state, .resumeReady) }
    func testBeginnerPlanDoesNotPlaceGuidedSessionsConsecutively() { let days = WeeklyScheduler().beginnerPlan().filter { $0.kind == .guided }.map(\.day); XCTAssertEqual(days, [0, 3]) }

    func testPlanConstraintsReplaceUnsafeOrUnavailableActivities() {
        let resolver = PlanActivityResolver()
        XCTAssertEqual(resolver.effectiveKind(.cardio, exerciseRestricted: true, guidedAllowed: true, isToday: false), .recovery)
        XCTAssertEqual(resolver.effectiveKind(.strength, exerciseRestricted: true, guidedAllowed: true, isToday: false), .recovery)
        XCTAssertEqual(resolver.effectiveKind(.guided, exerciseRestricted: false, guidedAllowed: false, isToday: true), .recovery)
    }

    func testGuidedEligibilityUsesOneCentralGate() {
        let evaluator = GuidedEligibilityEvaluator()
        XCTAssertEqual(evaluator.evaluate(programPhase: .assessmentRequired, hoursSinceLastSession: nil, guidedSessionsLast7Days: 0).reason, .baselineRequired)
        XCTAssertEqual(evaluator.evaluate(programPhase: .safetyHold, hoursSinceLastSession: nil, guidedSessionsLast7Days: 0).reason, .safetyHold)
        XCTAssertEqual(evaluator.evaluate(programPhase: .awareness, hoursSinceLastSession: 12, guidedSessionsLast7Days: 0).reason, .recoveryWindow)
        XCTAssertTrue(evaluator.evaluate(programPhase: .awareness, hoursSinceLastSession: 30, guidedSessionsLast7Days: 0).isAllowed)
    }

    func testInterruptionTimeStillReachesHardLimit() {
        var session = GuidedSessionMachine(maximumDurationSeconds: 120)
        session.start(); session.beginActive(); session.pause(reason: .interruption)
        session.updateElapsed(totalSeconds: 120)
        XCTAssertEqual(session.state, .timeLimitReached)
        session.abortForSafety()
        XCTAssertEqual(session.state, .timeLimitReached)
    }

    func testInterruptionRecoveryDoesNotAddCycle() {
        var session = GuidedSessionMachine()
        session.start(); session.beginActive(); session.pause(reason: .interruption)
        session.recovered(level: 3, elapsedSeconds: 30)
        XCTAssertEqual(session.state, .resumeReady)
        XCTAssertEqual(session.cycles, 0)
    }

    func testEmergencyPauseRecordsLateStop() {
        var session = GuidedSessionMachine()
        session.start(); session.beginActive(); session.emergencyPause()
        XCTAssertEqual(session.state, .pausedRecovery)
        XCTAssertTrue(session.lateStopOccurred)
        XCTAssertEqual(session.lastPauseReason, .almostTooLate)
    }

    func testEmergencyWarningIsVisibleBeforeRecovery() {
        var session = GuidedSessionMachine()
        session.start(); session.beginActive()
        XCTAssertTrue(session.emergencyWarning())
        XCTAssertEqual(session.state, .warning)
        XCTAssertTrue(session.advanceWarningToRecovery())
        XCTAssertEqual(session.state, .pausedRecovery)
    }

    func testEncryptedExportRoundTripAndWrongPassword() throws {
        let original = Data("private tempo payload".utf8)
        let encrypted = try EncryptedExport.encrypt(original, password: "correct horse")
        XCTAssertNotEqual(encrypted, original)
        XCTAssertEqual(try EncryptedExport.decrypt(encrypted, password: "correct horse"), original)
        XCTAssertThrowsError(try EncryptedExport.decrypt(encrypted, password: "wrong password"))
    }

    func testLegacySessionJSONStillDecodesAfterSchemaExpansion() throws {
        struct LegacySession: Encodable {
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
        let legacy = LegacySession(id: UUID(), completedAt: .now, cycles: 1, terminalState: GuidedSessionState.completed.rawValue, durationSeconds: nil, postAnxiety: nil, postTension: nil, irritationAfter: nil, outcome: nil)
        let decoded = try JSONDecoder().decode(LocalSession.self, from: JSONEncoder().encode(legacy))
        XCTAssertEqual(decoded.cycles, 1)
        XCTAssertNil(decoded.lateStopOccurred)
        XCTAssertNil(decoded.arousalEvents)
    }

    func testLegacyBaselineJSONStillDecodesAfterExerciseExpansion() throws {
        struct LegacyBaseline: Encodable {
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
        let legacy = LegacyBaseline(completedAt: .now, onset: "Belum yakin", difficultyContext: "Keduanya", perceivedControl: 5, anxiety: 5, sleepHours: 7, activityLevel: "Jarang", rushedHabit: false, highStimulusPattern: false, hasSafetySymptoms: false, rulesetVersion: "1.0.0")
        let decoded = try JSONDecoder().decode(LocalBaseline.self, from: JSONEncoder().encode(legacy))
        XCTAssertEqual(decoded.sleepHours, 7)
        XCTAssertNil(decoded.weeklyMovementMinutes)
    }

    func testNotificationSyncCancelsLegacyDeferredAndIndexedRequests() {
        let identifiers = Set(LocalNotificationPlanSync.cancellationRequestIdentifiers(indexed: [
            "tempo.plan.replaced-guided",
            "tempo.plan.replaced-guided",
            "tempo.daily-plan.3"
        ]))

        XCTAssertTrue(identifiers.contains("tempo.plan.replaced-guided"))
        XCTAssertTrue(identifiers.contains("tempo.remind-later"))
        XCTAssertTrue(identifiers.contains("tempo.daily-plan"))
        XCTAssertEqual(identifiers.filter { $0.hasPrefix("tempo.daily-plan.") }.count, 7)
    }

    func testDailyReadinessUsesLatestCurrentDayThenRecentAndKeepsOneEntryPerDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
        }

        let reference = date(20, 20)
        let recent = DailyReadinessRecord(date: date(19, 9), sleepHoursLastNight: 6.5, anxietyToday: 7, energyToday: 4, irritationOrPain: false)
        let earlierToday = DailyReadinessRecord(date: date(20, 8), sleepHoursLastNight: 7, anxietyToday: 3, energyToday: 7, irritationOrPain: false)
        let latestToday = DailyReadinessRecord(date: date(20, 19), sleepHoursLastNight: 5, anxietyToday: 9, energyToday: 2, irritationOrPain: true)
        let stale = DailyReadinessRecord(date: date(10, 9), sleepHoursLastNight: 8, anxietyToday: 2, energyToday: 8, irritationOrPain: false)

        XCTAssertEqual(DailyReadinessSelection.today(from: [recent, earlierToday, latestToday], at: reference, calendar: calendar)?.id, latestToday.id)
        XCTAssertEqual(DailyReadinessSelection.currentOrRecent(from: [recent, earlierToday, latestToday], at: reference, calendar: calendar)?.id, latestToday.id)
        XCTAssertEqual(DailyReadinessSelection.currentOrRecent(from: [recent, stale], at: reference, calendar: calendar)?.id, recent.id)
        XCTAssertNil(DailyReadinessSelection.currentOrRecent(from: [stale], at: reference, calendar: calendar))
        XCTAssertEqual(recent.sleepHoursLastNight, 6.5)

        let updated = DailyReadinessSelection.replacingToday(latestToday, in: [recent, earlierToday], calendar: calendar)
        XCTAssertEqual(updated.filter { calendar.isDate($0.date, inSameDayAs: reference) }.count, 1)
        XCTAssertEqual(updated.first?.id, latestToday.id)
        XCTAssertEqual(updated.last?.id, recent.id)
    }

    func testLegacyPrivateSessionDecodesWithoutDetailedPauseCounts() throws {
        struct LegacyPrivateSession: Encodable {
            let id: UUID
            let startedAt: Date
            let completedAt: Date
            let elapsedSeconds: Int
            let pauseCount: Int
            let outcome: String?
            let note: String?
            let detailWasSaved: Bool
            let rulesetVersion: String
        }

        let legacy = LegacyPrivateSession(
            id: UUID(), startedAt: .now.addingTimeInterval(-60), completedAt: .now,
            elapsedSeconds: 60, pauseCount: 1, outcome: nil, note: nil,
            detailWasSaved: false, rulesetVersion: "2.1.0"
        )
        let decoded = try JSONDecoder().decode(LocalPrivateSession.self, from: JSONEncoder().encode(legacy))

        XCTAssertNil(decoded.thresholdPauseCount)
        XCTAssertNil(decoded.interruptionPauseCount)
    }

    func testDailyRecommendationDoesNotLetCompletedItemMaskActionableReschedule() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 10))!
        let completed = ProgramPlanItem(
            scheduledAt: calendar.date(byAdding: .minute, value: 5, to: now)!,
            prescribedKind: .breathing,
            estimatedMinutes: 5,
            phase: .awareness,
            reasons: [.nervousSystemRecovery],
            status: .completed
        )
        let rescheduled = ProgramPlanItem(
            scheduledAt: calendar.date(byAdding: .hour, value: 4, to: now)!,
            prescribedKind: .guided,
            estimatedMinutes: 20,
            phase: .awareness,
            reasons: [.guidedSpacing],
            status: .adapted,
            adaptation: PlanAdaptation(
                adaptedAt: now,
                originalKind: .guided,
                replacementKind: .guided,
                reasons: [.postponed, .safeReschedule],
                rescheduledFromID: UUID()
            )
        )

        let recommendation = DailyRecommendationEngine().prescription(
            for: now,
            items: [completed, rescheduled],
            context: ProgramContext(phase: .awareness, baselineCompleted: true),
            calendar: calendar
        )

        XCTAssertEqual(recommendation.activity?.id, rescheduled.id)
    }
}
