import XCTest
@testable import TempoDomain

final class TempoDomainTests: XCTestCase {
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
        XCTAssertEqual(days, [1, 4])
    }

    func testSchedulerAlwaysProducesSevenDaysAndRecovery() {
        for plan in [WeeklyScheduler().beginnerPlan(), WeeklyScheduler().beginnerPlan(highStress: true), WeeklyScheduler().beginnerPlan(irritation: true)] {
            XCTAssertEqual(plan.map(\.day), Array(0...6))
            XCTAssertTrue(plan.contains { $0.kind == .recovery })
            XCTAssertLessThanOrEqual(plan.filter { $0.kind == .guided }.count, 3)
        }
    }

    func testSessionRequiresRecoveryBeforeResume() {
        var session = GuidedSessionMachine()
        session.start(); session.beginActive(); session.rising(level: 7, threshold: 7)
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

    func testThresholdWarningIsOneShotAndStartsRecovery() {
        var session = GuidedSessionMachine()
        session.start(); session.beginActive()
        XCTAssertTrue(session.rising(level: 7, threshold: 7))
        XCTAssertEqual(session.state, .pausedRecovery)
        XCTAssertEqual(session.lastPauseReason, .threshold)
        XCTAssertFalse(session.rising(level: 8, threshold: 7))
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
}
