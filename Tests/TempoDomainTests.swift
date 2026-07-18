import XCTest
@testable import Tempo

final class TempoDomainTests: XCTestCase {
    func testSafetyAlwaysBlocksTraining() { var c = DecisionContext(); c.urgeIntensity = 9; c.intent = .training; c.urinaryBurning = true; let r = RuleEngine().evaluate(c); XCTAssertEqual(r.action, .healthCheck); XCTAssertTrue(r.blocksGuidedTraining) }
    func testRecentSessionRoutesToRecovery() { var c = DecisionContext(); c.hoursSinceLastSession = 6; c.intent = .training; XCTAssertEqual(RuleEngine().evaluate(c).action, .recovery) }
    func testGuidedSessionNeedsRecoveryBeforeResume() { var s = GuidedSessionMachine(); s.start(); s.beginActive(); s.rising(level: 7, threshold: 7); s.pause(); s.recovered(level: 5, elapsedSeconds: 30); XCTAssertEqual(s.state, .pausedRecovery); s.recovered(level: 4, elapsedSeconds: 30); XCTAssertEqual(s.state, .resumeReady) }
    func testBeginnerPlanDoesNotPlaceGuidedSessionsConsecutively() { let days = WeeklyScheduler().beginnerPlan().filter { $0.kind == .guided }.map(\.day); XCTAssertEqual(days, [1, 4]) }
}
