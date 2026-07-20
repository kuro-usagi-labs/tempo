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

    func testGuidedSessionNeedsRecoveryBeforeResume() { var s = GuidedSessionMachine(); s.start(); s.beginActive(); XCTAssertTrue(s.rising(level: 7, threshold: 7)); XCTAssertEqual(s.state, .warning); XCTAssertTrue(s.advanceWarningToRecovery()); s.recovered(level: 5, elapsedSeconds: 30); XCTAssertEqual(s.state, .pausedRecovery); s.recovered(level: 4, elapsedSeconds: 30); XCTAssertEqual(s.state, .resumeReady) }

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

    func testLegacyDailyReadinessBooleanMigratesToAnUnresolvedPainRecord() throws {
        struct LegacyReadiness: Encodable {
            let id: UUID
            let date: Date
            let sleepHoursLastNight: Double
            let anxietyToday: Int
            let energyToday: Int
            let irritationOrPain: Bool
        }

        let legacy = LegacyReadiness(
            id: UUID(),
            date: .now,
            sleepHoursLastNight: 6.5,
            anxietyToday: 7,
            energyToday: 4,
            irritationOrPain: true
        )

        let decoded = try JSONDecoder().decode(DailyReadinessRecord.self, from: JSONEncoder().encode(legacy))

        XCTAssertEqual(decoded.symptomType, .pain)
        XCTAssertTrue(decoded.hasUnresolvedSymptom)
        XCTAssertTrue(decoded.irritationOrPain)
    }

    func testResolvedDailyReadinessKeepsItsHistoricalSymptomCategory() {
        let reportedAt = Date.now.addingTimeInterval(-60)
        let resolvedAt = Date.now
        let record = DailyReadinessRecord(
            date: reportedAt,
            sleepHoursLastNight: 7,
            anxietyToday: 5,
            energyToday: 5,
            symptomType: .urinaryOrDischarge
        )

        let resolved = record.resolved(at: resolvedAt)

        XCTAssertEqual(resolved.symptomType, .urinaryOrDischarge)
        XCTAssertEqual(resolved.symptomResolvedAt, Optional(resolvedAt))
        XCTAssertFalse(resolved.hasUnresolvedSymptom)
        XCTAssertFalse(resolved.irritationOrPain)
    }

    func testClearSafetyRecheckResolvesEveryActiveHoldAndOnlyTodaysSymptom() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12))!
        let today = DailyReadinessRecord(
            date: calendar.date(byAdding: .hour, value: -2, to: now)!,
            sleepHoursLastNight: 6,
            anxietyToday: 7,
            energyToday: 4,
            symptomType: .pain
        )
        let yesterday = DailyReadinessRecord(
            date: calendar.date(byAdding: .day, value: -1, to: now)!,
            sleepHoursLastNight: 7,
            anxietyToday: 5,
            energyToday: 6,
            symptomType: .mildIrritation
        )
        let activeHolds = [
            LocalSafetyHold(id: UUID(), createdAt: now.addingTimeInterval(-300), reasonCode: "safety.daily-readiness-pain", severity: RecommendationSeverity.medical.rawValue, source: "readiness", recheckNotBefore: nil, resolvedAt: nil),
            LocalSafetyHold(id: UUID(), createdAt: now.addingTimeInterval(-180), reasonCode: "safety.daily-readiness-irritation", severity: RecommendationSeverity.caution.rawValue, source: "readiness", recheckNotBefore: now.addingTimeInterval(-1), resolvedAt: nil)
        ]

        let mutation = SafetyRecheckResolution.resolve(
            holds: activeHolds,
            readiness: [today, yesterday],
            at: now,
            calendar: calendar
        )

        XCTAssertTrue(mutation.holds.allSatisfy { $0.resolvedAt == Optional(now) })
        XCTAssertEqual(mutation.readiness.first { $0.id == today.id }?.symptomResolvedAt, Optional(now))
        XCTAssertNil(mutation.readiness.first { $0.id == yesterday.id }?.symptomResolvedAt)
        XCTAssertEqual(mutation.readiness.first { $0.id == today.id }?.symptomType, Optional<DailySymptomType>.some(.pain))
    }

    @MainActor
    func testClearHealthRecheckPersistsReadinessResolutionAndRestoresPrivateAndGuidedRouting() {
        let history = LocalHistory()
        _ = history.deleteAll()
        defer { _ = history.deleteAll() }

        let baseline = LocalBaseline(
            completedAt: .now,
            onset: "Bertahap",
            difficultyContext: "Keduanya",
            perceivedControl: 5,
            anxiety: 5,
            sleepHours: 7,
            activityLevel: "Ringan",
            weeklyMovementMinutes: 60,
            canWalkTwentyMinutes: true,
            hasExerciseRestriction: false,
            hasSafeActivitySpace: true,
            preferredActivity: "Jalan santai",
            activityPreference: .walking,
            rushedHabit: false,
            highStimulusPattern: false,
            hasSafetySymptoms: false,
            rulesetVersion: RulesetVersion.current.rawValue,
            adultConfirmed: true
        )

        XCTAssertTrue(history.saveBaseline(baseline))
        XCTAssertTrue(history.saveDailyReadiness(
            sleepHoursLastNight: 7,
            anxietyToday: 5,
            energyToday: 6,
            symptomType: .pain
        ))
        XCTAssertTrue(history.hasSafetyBlock)
        XCTAssertEqual(history.activeSafetyHold?.severity, RecommendationSeverity.medical.rawValue)
        XCTAssertTrue(history.todayReadiness?.hasUnresolvedSymptom == true)

        XCTAssertTrue(history.resolveActiveSafetyHoldAfterClearRecheck())
        XCTAssertFalse(history.hasSafetyBlock)
        XCTAssertNil(history.activeSafetyHold)
        XCTAssertFalse(history.todayReadiness?.hasUnresolvedSymptom ?? true)
        XCTAssertNotNil(history.todayReadiness?.symptomResolvedAt)

        let privateRoute = ImmediateActionRouter().route(ImmediateActionRequest(
            choice: .privateSession,
            intensity: 5,
            guidedEligibility: history.guidedEligibility,
            hasActiveSafetyHold: history.hasSafetyBlock
        ))
        let guidedRoute = ImmediateActionRouter().route(ImmediateActionRequest(
            choice: .guided,
            intensity: 5,
            guidedEligibility: history.guidedEligibility,
            hasActiveSafetyHold: history.hasSafetyBlock
        ))
        XCTAssertEqual(privateRoute.destination, .privateSession)
        XCTAssertEqual(guidedRoute.destination, .guided)
    }

    @MainActor
    func testMedicalHoldOutranksMildHoldAndEveryRecoveryWindowMustBeReady() {
        let history = LocalHistory()
        _ = history.deleteAll()
        defer { _ = history.deleteAll() }

        XCTAssertTrue(history.recordSafetyHold(
            reasonCode: "safety.daily-readiness-irritation",
            severity: RecommendationSeverity.caution.rawValue,
            source: "test"
        ))
        XCTAssertTrue(history.recordSafetyHold(
            reasonCode: "safety.daily-readiness-pain",
            severity: RecommendationSeverity.medical.rawValue,
            source: "test"
        ))

        XCTAssertEqual(history.activeSafetyHold?.severity, RecommendationSeverity.medical.rawValue)
        XCTAssertFalse(history.canResolveActiveSafetyHold)
        XCTAssertFalse(history.resolveActiveSafetyHoldAfterClearRecheck(confirmedAllActiveHoldsResolved: true))
        XCTAssertTrue(history.hasSafetyBlock)
    }

    @MainActor
    func testMultipleSafetyHoldsRequireExplicitConfirmationAndRemainInHistory() {
        let history = LocalHistory()
        _ = history.deleteAll()
        defer { _ = history.deleteAll() }

        XCTAssertTrue(history.recordSafetyHold(
            reasonCode: "safety.daily-readiness-pain",
            severity: RecommendationSeverity.medical.rawValue,
            source: "test"
        ))
        XCTAssertTrue(history.recordSafetyHold(
            reasonCode: "safety.daily-readiness-urinary-discharge",
            severity: RecommendationSeverity.medical.rawValue,
            source: "test"
        ))

        XCTAssertTrue(history.requiresMultipleHoldConfirmation)
        XCTAssertEqual(Set(history.unresolvedSafetyHoldSummaries.map(\.title)), Set(["Nyeri", "Keluhan saluran kemih"]))
        XCTAssertTrue(history.unresolvedSafetyHoldSummaries.allSatisfy { !$0.detail.contains("safety.") })
        XCTAssertFalse(history.resolveActiveSafetyHoldAfterClearRecheck())
        XCTAssertTrue(history.hasSafetyBlock)

        XCTAssertTrue(history.resolveActiveSafetyHoldAfterClearRecheck(confirmedAllActiveHoldsResolved: true))
        XCTAssertFalse(history.hasSafetyBlock)
        XCTAssertEqual(history.safetyHoldCount, 2)
        XCTAssertTrue(history.unresolvedSafetyHolds.isEmpty)
    }

    @MainActor
    func testSafetyRecheckProfileWriteFailureRemainsFailClosed() {
        let history = LocalHistory(safetyRecheckProfileStore: { _ in false })
        _ = history.deleteAll()
        defer { _ = history.deleteAll() }

        XCTAssertTrue(history.recordSafetyHold(
            reasonCode: "safety.daily-readiness-pain",
            severity: RecommendationSeverity.medical.rawValue,
            source: "test"
        ))
        XCTAssertFalse(history.resolveActiveSafetyHoldAfterClearRecheck())
        XCTAssertTrue(history.hasSafetyBlock)
        XCTAssertNotNil(history.activeSafetyHold)
    }

    @MainActor
    func testPostponePersistsOneSourceAndOneReplacementAndRejectsAChain() {
        let history = LocalHistory()
        _ = history.deleteAll()
        defer { _ = history.deleteAll() }
        let baseline = LocalBaseline(
            completedAt: .now,
            onset: "Bertahap",
            difficultyContext: "Keduanya",
            perceivedControl: 5,
            anxiety: 5,
            sleepHours: 7,
            activityLevel: "Ringan",
            weeklyMovementMinutes: 60,
            canWalkTwentyMinutes: true,
            hasExerciseRestriction: false,
            hasSafeActivitySpace: true,
            preferredActivity: "Jalan santai",
            activityPreference: .walking,
            rushedHabit: false,
            highStimulusPattern: false,
            hasSafetySymptoms: false,
            rulesetVersion: RulesetVersion.current.rawValue,
            adultConfirmed: true
        )
        XCTAssertTrue(history.saveBaseline(baseline))
        guard let source = history.plannedDays.first(where: {
            $0.status.isActionable && $0.scheduleDate > .now && [.breathing, .recovery].contains($0.effectiveKind)
        }) else {
            return XCTFail("Expected an actionable future plan item")
        }

        XCTAssertTrue(history.postponePlan(id: source.id))
        let storedSource = history.plannedDays.first { $0.id == source.id }
        let replacements = history.plannedDays.filter { $0.rescheduledFromID == source.id }
        XCTAssertEqual(storedSource?.status, .skipped)
        XCTAssertEqual(replacements.count, 1)
        guard let replacement = replacements.first else { return }
        XCTAssertFalse(history.postponePlan(id: replacement.id))
        XCTAssertEqual(history.plannedDays.filter { $0.rescheduledFromID == source.id }.count, 1)
    }

    @MainActor
    func testRefreshingWeekOnePlanDoesNotDuplicateHighStimulusEducation() {
        let history = LocalHistory()
        _ = history.deleteAll()
        defer { _ = history.deleteAll() }
        let baseline = LocalBaseline(
            completedAt: .now,
            onset: "Bertahap",
            difficultyContext: "Keduanya",
            perceivedControl: 5,
            anxiety: 5,
            sleepHours: 7,
            activityLevel: "Ringan",
            weeklyMovementMinutes: 60,
            canWalkTwentyMinutes: true,
            hasExerciseRestriction: false,
            hasSafeActivitySpace: true,
            preferredActivity: "Jalan santai",
            activityPreference: .walking,
            rushedHabit: false,
            highStimulusPattern: true,
            hasSafetySymptoms: false,
            rulesetVersion: RulesetVersion.current.rawValue,
            adultConfirmed: true
        )
        XCTAssertTrue(history.saveBaseline(baseline))
        XCTAssertTrue(history.refreshPlan(force: true))
        XCTAssertTrue(history.refreshPlan(force: true))
        let resetRows = history.plannedDays.filter {
            $0.reasonCodes?.contains(PlanReason.highStimulusReset.rawValue) == true
        }
        XCTAssertEqual(resetRows.count, 1)
        XCTAssertEqual(Set(resetRows.map(\.id)).count, 1)
    }

    func testHistoricalReadinessTrendDoesNotPretendToBeToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12))!
        let historical = DailyReadinessRecord(
            date: calendar.date(byAdding: .day, value: -2, to: now)!,
            sleepHoursLastNight: 5.5,
            anxietyToday: 8,
            energyToday: 3,
            symptomType: .none
        )

        XCTAssertNil(DailyReadinessSelection.today(from: [historical], at: now, calendar: calendar))
        XCTAssertEqual(DailyReadinessSelection.currentOrRecent(from: [historical], at: now, calendar: calendar)?.id, historical.id)

        let trend = DailyReadinessSelection.recentTrend(from: [historical], at: now, calendar: calendar)
        XCTAssertEqual(trend?.sampleCount, 1)
        XCTAssertEqual(trend?.averageAnxiety, 8.0)
        XCTAssertEqual(trend?.averageEnergy, 3.0)
        XCTAssertEqual(trend?.latestDate, Optional(historical.date))
    }

    func testActivityPreferenceUpdatePreservesBaselineSafetyAndCapabilityAnswers() {
        let baseline = LocalBaseline(
            completedAt: .now,
            onset: "Bertahap",
            difficultyContext: "Keduanya",
            perceivedControl: 4,
            anxiety: 6,
            sleepHours: 7,
            activityLevel: "Ringan",
            weeklyMovementMinutes: 80,
            canWalkTwentyMinutes: true,
            hasExerciseRestriction: false,
            hasSafeActivitySpace: true,
            preferredActivity: "Jalan santai",
            activityPreference: .walking,
            rushedHabit: true,
            highStimulusPattern: true,
            hasSafetySymptoms: false,
            rulesetVersion: "2.1.2",
            reminderStartHour: 9,
            reminderEndHour: 21,
            adultConfirmed: true
        )

        let updated = baseline.updatingActivityPreference(.breathingAndMobility)

        XCTAssertEqual(updated.activityPreference, Optional<ActivityPreference>.some(.breathingAndMobility))
        XCTAssertEqual(updated.preferredActivity, Optional(ActivityPreference.breathingAndMobility.legacyDisplayValue))
        XCTAssertEqual(updated.canWalkTwentyMinutes, baseline.canWalkTwentyMinutes)
        XCTAssertEqual(updated.hasExerciseRestriction, baseline.hasExerciseRestriction)
        XCTAssertEqual(updated.hasSafeActivitySpace, baseline.hasSafeActivitySpace)
        XCTAssertEqual(updated.hasSafetySymptoms, baseline.hasSafetySymptoms)
        XCTAssertEqual(updated.adultConfirmed, baseline.adultConfirmed)
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
