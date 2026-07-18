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

    func testSessionRequiresRecoveryBeforeResume() {
        var session = GuidedSessionMachine()
        session.start(); session.beginActive(); session.rising(level: 7, threshold: 7); session.pause()
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
}
