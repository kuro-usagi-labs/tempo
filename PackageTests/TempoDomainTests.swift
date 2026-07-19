import Foundation
import XCTest
@testable import TempoDomain

final class TempoDomainTests: XCTestCase {
    func testImmediatePrivateHighIntensityRoutesToPrivateSession() {
        let result = ImmediateActionRouter().route(ImmediateActionRequest(choice: .privateSession, intensity: 9))
        XCTAssertEqual(result.destination, .privateSession)
    }

    func testImmediatePrivateHighAnxietyAddsAdvisoryWithoutChangingDestination() {
        let result = ImmediateActionRouter().route(ImmediateActionRequest(choice: .privateSession, intensity: 6, anxiety: 9))
        XCTAssertEqual(result.destination, .privateSession)
        XCTAssertTrue(result.advisories.contains(.highAnxiety))
    }

    func testImmediatePrivateRecentGuidedAddsAdvisoryWithoutChangingDestination() {
        let result = ImmediateActionRouter().route(ImmediateActionRequest(
            choice: .privateSession,
            intensity: 6,
            hoursSinceLastGuidedSession: 8,
            guidedSessionsLast7Days: 3
        ))
        XCTAssertEqual(result.destination, .privateSession)
        XCTAssertTrue(result.advisories.contains(.recentGuidedSession))
        XCTAssertTrue(result.advisories.contains(.frequentGuidedSessions))
    }

    func testImmediateResetAlwaysRoutesToFiveMinuteReset() {
        let result = ImmediateActionRouter().route(ImmediateActionRequest(choice: .reset, intensity: 10, anxiety: 10))
        XCTAssertEqual(result.destination, .reset)
    }

    func testImmediateGuidedEligibleRoutesToGuided() {
        let result = ImmediateActionRouter().route(ImmediateActionRequest(choice: .guided, intensity: 8))
        XCTAssertEqual(result.destination, .guided)
    }

    func testImmediateGuidedUnavailableRoutesToExplanation() {
        let eligibility = GuidedEligibility(isAllowed: false, reason: .recoveryWindow, message: "Tunggu sampai besok.")
        let result = ImmediateActionRouter().route(ImmediateActionRequest(choice: .guided, intensity: 8, guidedEligibility: eligibility))
        XCTAssertEqual(result.destination, .guidedUnavailable)
        XCTAssertEqual(result.guidedEligibility, eligibility)
    }

    func testImmediatePhysicalSymptomsOverrideEveryChoice() {
        for choice in ImmediateActionChoice.allCases {
            let result = ImmediateActionRouter().route(ImmediateActionRequest(choice: choice, intensity: 9, hasPhysicalSymptoms: true))
            XCTAssertEqual(result.destination, .healthCheck)
        }
    }

    func testUrgentSymptomsBlockGuidedTraining() {
        var context = DecisionContext()
        context.intent = .training
        context.bloodReported = true
        let recommendation = RuleEngine().evaluate(context)
        XCTAssertEqual(recommendation.action, .healthCheck)
        XCTAssertTrue(recommendation.blocksGuidedTraining)
    }

    func testSafetyHoldAlwaysBlocksTraining() {
        var context = DecisionContext()
        context.programPhase = .safetyHold
        context.intent = .training
        context.urgeIntensity = 7
        let recommendation = RuleEngine().evaluate(context)
        XCTAssertEqual(recommendation.action, .healthCheck)
        XCTAssertTrue(recommendation.blocksGuidedTraining)
    }

    func testGuidedTrainingRequiresBaseline() {
        var context = DecisionContext()
        context.programPhase = .assessmentRequired
        context.intent = .training
        XCTAssertTrue(RuleEngine().evaluate(context).blocksGuidedTraining)
    }

    func testRecentSessionRoutesToRecovery() {
        var context = DecisionContext()
        context.programPhase = .awareness
        context.hoursSinceLastSession = 6
        context.intent = .training
        XCTAssertEqual(RuleEngine().evaluate(context).action, .recovery)
    }

    func testSessionWithinTwentyFourHoursRoutesToRecovery() {
        var context = DecisionContext()
        context.programPhase = .awareness
        context.hoursSinceLastSession = 18
        context.urgeIntensity = 6
        context.trigger = .desire
        context.intent = .training
        XCTAssertEqual(RuleEngine().evaluate(context).action, .recovery)
    }

    func testSchedulerKeepsGuidedSessionsApart() {
        let days = WeeklyScheduler().beginnerPlan().filter { $0.kind == .guided }.map(\.day)
        XCTAssertEqual(days, [0, 3])
    }

    func testSchedulerAlwaysProducesSevenDaysAndRecovery() {
        for plan in [WeeklyScheduler().beginnerPlan(), WeeklyScheduler().beginnerPlan(highStress: true), WeeklyScheduler().beginnerPlan(irritation: true)] {
            XCTAssertEqual(plan.map(\.day), Array(0...6))
            XCTAssertTrue(plan.contains { $0.kind == .recovery })
            XCTAssertLessThanOrEqual(plan.filter { $0.kind == .guided }.count, 3)
        }
    }

    func testPlanConstraintsReplaceUnsafeOrUnavailableActivities() {
        let resolver = PlanActivityResolver()
        XCTAssertEqual(resolver.effectiveKind(.cardio, exerciseRestricted: true, guidedAllowed: true, isToday: false), .recovery)
        XCTAssertEqual(resolver.effectiveKind(.strength, exerciseRestricted: true, guidedAllowed: true, isToday: false), .recovery)
        XCTAssertEqual(resolver.effectiveKind(.guided, exerciseRestricted: false, guidedAllowed: false, isToday: true), .recovery)
        XCTAssertEqual(resolver.effectiveKind(.guided, exerciseRestricted: false, guidedAllowed: false, isToday: false), .guided)
    }

    func testSessionRequiresRecoveryBeforeResume() {
        var session = GuidedSessionMachine()
        session.start(); session.beginActive(); session.rising(level: 7, threshold: 7)
        XCTAssertEqual(session.state, .warning)
        XCTAssertTrue(session.advanceWarningToRecovery())
        XCTAssertEqual(session.state, .pausedRecovery)
        session.recovered(level: 5, elapsedSeconds: 30)
        XCTAssertEqual(session.state, .pausedRecovery)
        session.recovered(level: 4, elapsedSeconds: 30)
        XCTAssertEqual(session.state, .resumeReady)
    }

    func testSessionTimeLimitIsTerminal() {
        var session = GuidedSessionMachine()
        session.start(); session.beginActive(); session.reachTimeLimit()
        XCTAssertEqual(session.state, .timeLimitReached)
        session.earlyCompletion()
        XCTAssertEqual(session.state, .timeLimitReached)
    }

    func testEmergencyPauseCanRecoverButDoesNotCompleteEarly() {
        var session = GuidedSessionMachine()
        session.start(); session.beginActive(); session.emergencyPause()
        XCTAssertEqual(session.state, .pausedRecovery)
        XCTAssertTrue(session.lateStopOccurred)
        XCTAssertEqual(session.lastPauseReason, .almostTooLate)
        session.recovered(level: 4, elapsedSeconds: 30)
        XCTAssertEqual(session.state, .resumeReady)
    }

    func testRecoveryMinimumIsEnforcedInDomain() {
        var session = GuidedSessionMachine()
        session.start(); session.beginActive(); session.pause()
        session.recovered(level: 4, elapsedSeconds: 29)
        XCTAssertEqual(session.state, .pausedRecovery)
        session.recovered(level: 5, elapsedSeconds: 30)
        XCTAssertEqual(session.state, .pausedRecovery)
    }

    func testCancellationIsTerminal() {
        var session = GuidedSessionMachine()
        session.start(); session.cancel(); session.beginActive()
        session.abortForSafety()
        XCTAssertEqual(session.state, .cancelled)
    }

    func testScoresStayWithinExpectedRange() {
        let inputs = ScoreInputs(earlyPauseRate: 1, loggingCompleteness: 1, tensionRecognitionRate: 1, escalationPredictionRate: 1, successfulCycleRatio: 1, controlledCompletionRatio: 1, thresholdCompliance: 1, recoveryCompletionRatio: 1, calmRate: 1, adherenceRate: 1)
        let scores = ScoreCalculator().calculate(inputs)
        XCTAssertEqual(scores.awareness, 100)
        XCTAssertEqual(scores.control, 100)
        XCTAssertEqual(scores.consistency, 100)
    }

    func testScoreWeightsMatchSpecification() {
        func scores(early: Double = 0, logging: Double = 0, tension: Double = 0, escalation: Double = 0, cycles: Double = 0, controlled: Double = 0, threshold: Double = 0, recovery: Double = 0) -> ScoreSnapshot {
            ScoreCalculator().calculate(ScoreInputs(earlyPauseRate: early, loggingCompleteness: logging, tensionRecognitionRate: tension, escalationPredictionRate: escalation, successfulCycleRatio: cycles, controlledCompletionRatio: controlled, thresholdCompliance: threshold, recoveryCompletionRatio: recovery, calmRate: 0, adherenceRate: 0))
        }
        XCTAssertEqual(scores(early: 1).awareness, 50)
        XCTAssertEqual(scores(logging: 1).awareness, 20)
        XCTAssertEqual(scores(tension: 1).awareness, 15)
        XCTAssertEqual(scores(escalation: 1).awareness, 15)
        XCTAssertEqual(scores(cycles: 1).control, 45)
        XCTAssertEqual(scores(controlled: 1).control, 20)
        XCTAssertEqual(scores(threshold: 1).control, 20)
        XCTAssertEqual(scores(recovery: 1).control, 15)
    }

    func testEveryPhysicalSafetyFlagWinsOverReadiness() {
        let mutations: [(inout DecisionContext) -> Void] = [
            { $0.pain = true }, { $0.irritation = true }, { $0.urinaryBurning = true },
            { $0.unusualDischarge = true }, { $0.bloodReported = true },
            { $0.pelvicOrTesticularPain = true }, { $0.fever = true }
        ]
        for mutation in mutations {
            var context = DecisionContext()
            context.programPhase = .awareness
            context.intent = .training
            context.urgeIntensity = 9
            mutation(&context)
            let result = RuleEngine().evaluate(context)
            XCTAssertTrue(result.blocksGuidedTraining)
            XCTAssertTrue(result.reasonCode.hasPrefix("safety."))
        }
    }

    func testEligibilityGateCannotBypassBaselineHoldOrRecovery() {
        let evaluator = GuidedEligibilityEvaluator()
        XCTAssertEqual(evaluator.evaluate(programPhase: .assessmentRequired, hoursSinceLastSession: nil, guidedSessionsLast7Days: 0).reason, .baselineRequired)
        XCTAssertEqual(evaluator.evaluate(programPhase: .safetyHold, hoursSinceLastSession: nil, guidedSessionsLast7Days: 0).reason, .safetyHold)
        XCTAssertEqual(evaluator.evaluate(programPhase: .awareness, hoursSinceLastSession: 24, guidedSessionsLast7Days: 0).reason, .recoveryWindow)
        XCTAssertEqual(evaluator.evaluate(programPhase: .awareness, hoursSinceLastSession: 25, guidedSessionsLast7Days: 3).reason, .weeklyLimit)
        XCTAssertTrue(evaluator.evaluate(programPhase: .awareness, hoursSinceLastSession: nil, guidedSessionsLast7Days: 0).isAllowed)
    }

    func testThresholdWarningStaysVisibleUntilExplicitRecoveryAdvance() {
        var session = GuidedSessionMachine()
        session.start(); session.beginActive()
        XCTAssertTrue(session.rising(level: 7, threshold: 7))
        XCTAssertEqual(session.state, .warning)
        XCTAssertEqual(session.lastPauseReason, .threshold)
        XCTAssertFalse(session.rising(level: 8, threshold: 7))
        XCTAssertTrue(session.advanceWarningToRecovery())
        XCTAssertEqual(session.state, .pausedRecovery)
        XCTAssertFalse(session.advanceWarningToRecovery())
    }

    func testElapsedTimeCannotMoveBackwardAndStopsWhilePaused() {
        var session = GuidedSessionMachine(maximumDurationSeconds: 120)
        session.start(); session.beginActive(); session.pause(reason: .interruption)
        session.updateElapsed(totalSeconds: 90)
        session.updateElapsed(totalSeconds: 20)
        XCTAssertEqual(session.elapsedSeconds, 90)
        session.updateElapsed(totalSeconds: 120)
        XCTAssertEqual(session.state, .timeLimitReached)
        session.cancel()
        XCTAssertEqual(session.state, .timeLimitReached)
    }

    func testInterruptionRecoveryDoesNotCountAsTrainingCycle() {
        var session = GuidedSessionMachine()
        session.start(); session.beginActive(); session.pause(reason: .interruption)
        session.recovered(level: 3, elapsedSeconds: 30)
        XCTAssertEqual(session.state, .resumeReady)
        XCTAssertEqual(session.cycles, 0)
    }

    func testPreparationCannotBeRecordedAsCompletedSession() {
        var session = GuidedSessionMachine()
        session.start(); session.complete()
        XCTAssertEqual(session.state, .prepare)
    }

    func testAbsoluteSessionCapIsEnforced() {
        let session = GuidedSessionMachine(maximumCycles: 99, maximumDurationSeconds: 9_999)
        XCTAssertEqual(session.maximumCycles, 5)
        XCTAssertEqual(session.maximumDurationSeconds, 1_500)
    }

    func testAllProgramPlansHaveSevenDaysAndValidGuidedSpacing() {
        let scheduler = WeeklyScheduler()
        for phase in ProgramPhase.allCases {
            let plan = scheduler.plan(for: phase)
            XCTAssertEqual(plan.map(\.day), Array(0...6))
            XCTAssertLessThanOrEqual(plan.filter { $0.kind == .guided }.count, 3)
            let guidedDays = plan.filter { $0.kind == .guided }.map(\.day)
            for pair in zip(guidedDays, guidedDays.dropFirst()) { XCTAssertGreaterThanOrEqual(pair.1 - pair.0, 2) }
            XCTAssertTrue(plan.contains { $0.kind == .recovery })
        }
    }

    func testWeeklyPlanGeneratorProducesRealMondayToSundayAwarenessPlan() {
        let calendar = utcCalendar
        let thursday = date(2026, 7, 16, hour: 9, calendar: calendar)
        let context = ProgramContext(phase: .awareness, baselineCompleted: true)

        let plan = WeeklyPlanGenerator().generate(
            weekStarting: thursday,
            weeks: 1,
            context: context,
            calendar: calendar
        )

        XCTAssertEqual(plan.count, 7)
        XCTAssertEqual(plan.map { calendar.component(.weekday, from: $0.scheduledAt) }, [2, 3, 4, 5, 6, 7, 1])
        XCTAssertEqual(plan.filter { $0.effectiveKind == .guided }.map { calendar.component(.weekday, from: $0.scheduledAt) }, [2, 5])
        XCTAssertTrue(plan.allSatisfy { $0.phase == .awareness && $0.rulesetVersion == .current })
        XCTAssertTrue(plan.first?.reasons.contains(.awarenessFoundation) == true)
        XCTAssertTrue(plan.allSatisfy { $0.estimatedMinutes > 0 })
    }

    func testWeeklyPlanGeneratorIsDeterministicAndAppliesSafetyAdaptation() {
        let calendar = utcCalendar
        let monday = date(2026, 7, 13, hour: 12, calendar: calendar)
        var context = ProgramContext(phase: .awareness, baselineCompleted: true, exerciseRestricted: true)
        let first = WeeklyPlanGenerator().generate(weekStarting: monday, weeks: 2, context: context, calendar: calendar)
        let second = WeeklyPlanGenerator().generate(weekStarting: monday, weeks: 2, context: context, calendar: calendar)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 14)
        XCTAssertTrue(first.filter { $0.prescribedKind == .cardio || $0.prescribedKind == .strength }.allSatisfy {
            $0.effectiveKind == .recovery && $0.status == .recovery && $0.reasons.contains(.exerciseRestriction)
        })

        context.hasSafetyHold = true
        let held = WeeklyPlanGenerator().generate(weekStarting: monday, weeks: 1, context: context, calendar: calendar)
        XCTAssertTrue(held.allSatisfy { $0.phase == .safetyHold && $0.effectiveKind == .recovery })
        XCTAssertTrue(held.allSatisfy { $0.reasons.contains(.safetyHold) })
    }

    func testPrivateSessionOnMondayDoesNotRemoveThursdayGuidedSession() {
        let calendar = utcCalendar
        let monday = date(2026, 7, 13, hour: 0, calendar: calendar)
        let privateSession = date(2026, 7, 13, hour: 12, calendar: calendar)
        let plan = WeeklyPlanGenerator().generate(
            weekStarting: monday,
            weeks: 1,
            context: ProgramContext(phase: .awareness, baselineCompleted: true),
            scheduleHistory: ProgramScheduleHistory(privateSessionDates: [privateSession]),
            referenceDate: privateSession,
            calendar: calendar
        )

        let thursday = plan.first { calendar.component(.weekday, from: $0.scheduledAt) == 5 }
        XCTAssertEqual(thursday?.effectiveKind, .guided)
        XCTAssertEqual(thursday?.status, .scheduled)
    }

    func testPrivateSessionWithinTwentyFourHoursReplacesGuidedWithRecovery() {
        let calendar = utcCalendar
        let monday = date(2026, 7, 13, calendar: calendar)
        let wednesdayNight = date(2026, 7, 15, hour: 22, calendar: calendar)
        let plan = WeeklyPlanGenerator().generate(
            weekStarting: monday,
            weeks: 1,
            context: ProgramContext(phase: .awareness, baselineCompleted: true),
            scheduleHistory: ProgramScheduleHistory(privateSessionDates: [wednesdayNight]),
            referenceDate: wednesdayNight,
            calendar: calendar
        )

        let thursday = plan.first { calendar.component(.weekday, from: $0.scheduledAt) == 5 }
        XCTAssertEqual(thursday?.prescribedKind, .guided)
        XCTAssertEqual(thursday?.effectiveKind, .recovery)
        XCTAssertTrue(thursday?.adaptation?.reasons.contains(.privateRecoveryWindow) == true)
    }

    func testHighAnxietyTodayDoesNotRemoveGuidedSeveralDaysLater() {
        let calendar = utcCalendar
        let monday = date(2026, 7, 13, hour: 9, calendar: calendar)
        let plan = WeeklyPlanGenerator().generate(
            weekStarting: monday,
            weeks: 1,
            context: ProgramContext(phase: .awareness, baselineCompleted: true, anxiety: 9),
            referenceDate: monday,
            calendar: calendar
        )

        let thursday = plan.first { calendar.component(.weekday, from: $0.scheduledAt) == 5 }
        XCTAssertEqual(thursday?.effectiveKind, .guided)
    }

    func testGeneratedGuidedSessionsKeepSafeSpacingAroundExistingReschedule() {
        let calendar = utcCalendar
        let monday = date(2026, 7, 13, calendar: calendar)
        let rescheduledTuesday = date(2026, 7, 14, hour: 18, minute: 30, calendar: calendar)
        let plan = WeeklyPlanGenerator().generate(
            weekStarting: monday,
            weeks: 1,
            context: ProgramContext(phase: .awareness, baselineCompleted: true),
            scheduleHistory: ProgramScheduleHistory(scheduledGuidedDates: [rescheduledTuesday]),
            referenceDate: monday,
            calendar: calendar
        )
        let guidedDates = ([rescheduledTuesday] + plan.filter { $0.effectiveKind == .guided }.map(\.scheduledAt)).sorted()

        for pair in zip(guidedDates, guidedDates.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1.timeIntervalSince(pair.0), 48 * 3_600)
        }
    }

    func testForcedRefreshRetainsUnavailableAndRescheduledDecisions() {
        let scheduled = date(2026, 7, 20, hour: 18, calendar: utcCalendar)
        let original = planItem(scheduledAt: scheduled, kind: .guided)
        let unavailable = original.adapted(to: .recovery, reasons: [.unavailable], at: scheduled)
        let rescheduled = original.adapted(to: .guided, reasons: [.postponed, .safeReschedule], at: scheduled, rescheduledFromID: original.id)
        let policy = PlanRefreshPolicy()

        XCTAssertTrue(policy.shouldRetainExisting(unavailable, now: scheduled.addingTimeInterval(-3_600), force: true))
        XCTAssertTrue(policy.shouldRetainExisting(rescheduled, now: scheduled.addingTimeInterval(-3_600), force: true))
    }

    func testBaselineAnswersChangePrescriptionAndExerciseSelection() {
        let normal = SessionPrescriptionEngine().prescription(for: ProgramContext(phase: .awareness, baselineCompleted: true))
        let adapted = SessionPrescriptionEngine().prescription(for: ProgramContext(
            phase: .awareness,
            baselineCompleted: true,
            rushedHabit: true,
            perceivedControl: 2
        ))
        XCTAssertGreaterThan(adapted.preparationSeconds, normal.preparationSeconds)
        XCTAssertLessThan(adapted.pauseThreshold, normal.pauseThreshold)

        let noSpace = ProgramContext(phase: .awareness, baselineCompleted: true, hasSafeActivitySpace: false)
        XCTAssertEqual(PlanActivityResolver().resolve(.strength, context: noSpace).kind, .cardio)
    }

    func testEligibilityEngineBlocksGuidedSessionDuringPrivateRecovery() {
        let engine = EligibilityEngine()
        let recovering = ProgramContext(
            phase: .awareness,
            baselineCompleted: true,
            hoursSinceLastPrivateSession: 23,
            guidedSessionsLast7Days: 0
        )
        let available = ProgramContext(
            phase: .awareness,
            baselineCompleted: true,
            hoursSinceLastPrivateSession: 24,
            guidedSessionsLast7Days: 0
        )

        XCTAssertEqual(engine.guidedEligibility(for: recovering).reason, .privateRecoveryWindow)
        XCTAssertFalse(engine.guidedEligibility(for: recovering).isAllowed)
        XCTAssertTrue(engine.guidedEligibility(for: available).isAllowed)
    }

    func testSessionPrescriptionSoftensAfterRepeatedLateStops() {
        let engine = SessionPrescriptionEngine()
        let normal = engine.prescription(for: ProgramContext(phase: .basicControl, baselineCompleted: true))
        let adapted = engine.prescription(for: ProgramContext(
            phase: .basicControl,
            baselineCompleted: true,
            anxiety: 8,
            sleepHours: 5,
            lateStopsLast3Sessions: 2
        ))

        XCTAssertEqual(normal.maximumCycles, 3)
        XCTAssertEqual(normal.pauseThreshold, 7)
        XCTAssertEqual(normal.recoverySeconds, 40)
        XCTAssertEqual(adapted.maximumCycles, 2)
        XCTAssertEqual(adapted.pauseThreshold, 6)
        XCTAssertEqual(adapted.recoverySeconds, 60)
        XCTAssertLessThan(adapted.activeTargetSeconds, normal.activeTargetSeconds)
        XCTAssertTrue(adapted.reasons.contains(.highAnxiety))
        XCTAssertTrue(adapted.reasons.contains(.lowSleep))
        XCTAssertTrue(adapted.reasons.contains(.lateStopAdaptation))
    }

    func testAdaptationPolicyMaintainsFortyEightHourGuidedSpacing() {
        let calendar = utcCalendar
        let original = planItem(
            scheduledAt: date(2026, 7, 13, hour: 18, minute: 30, calendar: calendar),
            kind: .guided
        )
        let blocker = planItem(
            scheduledAt: date(2026, 7, 14, hour: 18, minute: 30, calendar: calendar),
            kind: .guided
        )
        let policy = AdaptationPolicy()

        let rescheduled = policy.safeRescheduleDate(
            for: original,
            after: date(2026, 7, 13, hour: 8, calendar: calendar),
            items: [original, blocker],
            calendar: calendar
        )

        guard let rescheduled else {
            return XCTFail("Expected a safely spaced replacement day")
        }
        XCTAssertEqual(rescheduled, date(2026, 7, 16, hour: 18, minute: 30, calendar: calendar))
        XCTAssertGreaterThanOrEqual(abs(blocker.scheduledAt.timeIntervalSince(rescheduled)), 48 * 3_600)
    }

    func testProgramPlanItemPreservesOriginalPrescriptionAndTerminalHistory() {
        let scheduled = date(2026, 7, 13, hour: 18, minute: 30, calendar: utcCalendar)
        let original = planItem(scheduledAt: scheduled, kind: .guided, reasons: [.awarenessFoundation])
        let adapted = original.adapted(to: .recovery, reasons: [.unavailable], at: scheduled)
        let completed = adapted.completed(as: .recovery, at: scheduled)

        XCTAssertEqual(original.prescribedKind, .guided)
        XCTAssertEqual(adapted.prescribedKind, .guided)
        XCTAssertEqual(adapted.effectiveKind, .recovery)
        XCTAssertEqual(adapted.reasons, [.awarenessFoundation])
        XCTAssertEqual(adapted.adaptation?.originalKind, .guided)
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(completed.adapted(to: .cardio, reasons: [.postponed], at: scheduled), completed)
        XCTAssertEqual(completed.completed(as: .cardio, at: scheduled), completed)
    }

    func testProgressEngineUsesOnlyDueNonRecoveryItemsAndWaitsForSamples() {
        let calendar = utcCalendar
        let start = date(2026, 7, 13, hour: 9, calendar: calendar)
        let completed = planItem(scheduledAt: start, kind: .cardio).completed(as: .cardio, at: start)
        let missed = planItem(scheduledAt: date(2026, 7, 14, hour: 9, calendar: calendar), kind: .strength)
        let recovery = planItem(scheduledAt: start, kind: .recovery).adapted(to: .recovery, reasons: [.nervousSystemRecovery], at: start)
        let future = planItem(scheduledAt: date(2026, 7, 17, hour: 9, calendar: calendar), kind: .guided)
        let scores = ScoreCalculator().calculate(ScoreInputs(
            earlyPauseRate: 0.7,
            loggingCompleteness: 0.7,
            tensionRecognitionRate: 0.7,
            escalationPredictionRate: 0.7,
            successfulCycleRatio: 0.65,
            controlledCompletionRatio: 0.65,
            thresholdCompliance: 0.65,
            recoveryCompletionRatio: 0.75,
            calmRate: 0.6,
            adherenceRate: 0.5
        ))
        let engine = ProgressEngine()

        XCTAssertEqual(engine.presentation(sessionCount: 0, scores: scores), .baseline)
        XCTAssertEqual(engine.presentation(sessionCount: 2, scores: scores), .collecting(samplesNeeded: 1))
        XCTAssertEqual(engine.presentation(sessionCount: 3, scores: scores), .ready(scores))
        XCTAssertEqual(
            engine.consistency(for: [completed, missed, recovery, future], through: date(2026, 7, 14, hour: 23, calendar: calendar), calendar: calendar),
            0.5
        )
        XCTAssertNil(engine.consistency(for: [future, recovery], through: start, calendar: calendar))
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func planItem(
        scheduledAt: Date,
        kind: ActivityKind,
        reasons: [PlanReason] = [.plannedMovement]
    ) -> ProgramPlanItem {
        ProgramPlanItem(
            scheduledAt: scheduledAt,
            prescribedKind: kind,
            estimatedMinutes: 20,
            phase: .awareness,
            reasons: reasons
        )
    }
}
