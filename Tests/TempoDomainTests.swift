import XCTest
@testable import Tempo

final class TempoDomainTests: XCTestCase {
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
}
