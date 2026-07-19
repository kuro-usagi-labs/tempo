import XCTest

final class TempoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-tempo-ui-testing-reset"]
        app.launch()
    }

    func testOnboardingStartsWithIntegratedBaseline() {
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        XCTAssertTrue(nextButton.isEnabled)
    }

    func testOnboardingCanReachFourTabShell() {
        completeOnboarding()
        XCTAssertTrue(app.tabBars.buttons["Hari Ini"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Program"].exists)
        XCTAssertTrue(app.tabBars.buttons["Progres"].exists)
        XCTAssertTrue(app.tabBars.buttons["Profil"].exists)
    }

    func testProgramCalendarIsReachableAfterBaseline() {
        completeOnboarding()
        app.tabBars.buttons["Program"].tap()
        XCTAssertTrue(identifiedElement("tab.program").waitForExistence(timeout: 5))
    }

    func testProgramWeekNavigationAndTodayResetAreReachable() {
        completeOnboarding()
        app.tabBars.buttons["Program"].tap()

        let range = identifiedElement("program.week.range")
        XCTAssertTrue(range.waitForExistence(timeout: 5))
        let badge = identifiedElement("program.week.badge")
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        let currentWeek = badge.value as? String
        XCTAssertNotNil(currentWeek)
        let next = identifiedElement("program.week.next")
        XCTAssertTrue(next.exists)
        XCTAssertTrue(next.isEnabled)
        next.tap()
        XCTAssertTrue(identifiedElement("program.week.previous").isEnabled)
        let changedWeek = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", currentWeek ?? ""),
            object: badge
        )
        wait(for: [changedWeek], timeout: 5)
        let nextWeek = badge.value as? String
        XCTAssertNotEqual(nextWeek, currentWeek)

        let today = identifiedElement("program.week.today")
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        XCTAssertTrue(range.exists)
        XCTAssertEqual(badge.value as? String, currentWeek)
    }

    func testPrimaryActivityPromptsForDailyReadinessBeforeOpening() {
        completeOnboarding()
        let start = identifiedElement("today.primary.start")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(identifiedElement("today.readiness.save").waitForExistence(timeout: 5))
    }

    func testPainReadinessRoutesToHealthCheckAndClearRecheckRestoresImmediatePrivateFlow() {
        completeOnboarding()
        let start = identifiedElement("today.primary.start")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        tapIdentified("today.readiness.symptom.yes")
        tapIdentified("today.readiness.symptom.pain")
        tapIdentified("today.readiness.save")

        XCTAssertTrue(identifiedElement("health.check").waitForExistence(timeout: 5))
        tapIdentified("health.check.confirmed")
        tapIdentified("health.check.medicalFollowUp")
        tapIdentified("health.check.submit")

        XCTAssertTrue(app.tabBars.buttons["Hari Ini"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Hari Ini"].tap()
        XCTAssertTrue(identifiedElement("tab.today").waitForExistence(timeout: 5))
        completeImmediateFlow(choice: "Sesi privat")
        XCTAssertTrue(identifiedElement("private.session.timer").waitForExistence(timeout: 5))
    }

    func testProfileActivityPreferenceCanBeUpdatedWithoutRepeatingOnboarding() {
        completeOnboarding()
        app.tabBars.buttons["Profil"].tap()

        tapIdentified("profile.activityPreference.open")
        XCTAssertTrue(identifiedElement("profile.activityPreference.sheet").waitForExistence(timeout: 5))
        tapIdentified("profile.activityPreference.breathingAndMobility")
        XCTAssertTrue(identifiedElement("profile.activityPreference.validation").waitForExistence(timeout: 5))
        tapIdentified("profile.activityPreference.done")
        XCTAssertTrue(identifiedElement("profile.activityPreference.value").waitForExistence(timeout: 5))
    }

    func testManualPostponeOpensTheLinkedReplacement() {
        completeOnboarding()
        app.tabBars.buttons["Program"].tap()

        tapIdentified("program.plan.actionable")
        XCTAssertTrue(identifiedElement("plan.detail.postpone").waitForExistence(timeout: 5))
        tapIdentified("plan.detail.postpone")
        XCTAssertTrue(identifiedElement("plan.detail.replacement").waitForExistence(timeout: 5))
    }

    func testImmediatePrivateRouteUsesThreeDecisionFlow() {
        completeOnboarding()
        completeImmediateFlow(choice: "Sesi privat")
        XCTAssertTrue(identifiedElement("private.session.timer").waitForExistence(timeout: 5))
    }

    func testImmediateResetRouteOpensFiveMinuteReset() {
        completeOnboarding()
        completeImmediateFlow(choice: "Reset dulu")
        XCTAssertTrue(identifiedElement("breathing.session").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Reset lima menit"].exists)
    }

    func testImmediateGuidedRouteOpensGuidedCoach() {
        completeOnboarding()
        completeImmediateFlow(choice: "Sesi terpandu")
        XCTAssertTrue(identifiedElement("guided.session").waitForExistence(timeout: 5))
    }

    func testPrivateManualPauseEntersRecoveryWithoutRedWarning() {
        completeOnboarding()
        completeImmediateFlow(choice: "Sesi privat")
        XCTAssertTrue(identifiedElement("private.session.timer").waitForExistence(timeout: 5))

        tapButton("Mulai dengan pelan")
        tapButton("Jeda sekarang")

        XCTAssertTrue(identifiedElement("private.recovery").waitForExistence(timeout: 5))
        XCTAssertFalse(identifiedElement("private.pause.warning").exists)
    }

    func testPrivateThresholdUsesVisibleWarning() {
        completeOnboarding()
        completeImmediateFlow(choice: "Sesi privat")
        XCTAssertTrue(identifiedElement("private.session.timer").waitForExistence(timeout: 5))

        tapButton("Mulai dengan pelan")
        let threshold = identifiedElement("intensity.level.7")
        XCTAssertTrue(threshold.waitForExistence(timeout: 5))
        threshold.tap()
        XCTAssertTrue(identifiedElement("private.pause.warning").waitForExistence(timeout: 5))
    }

    func testPrivateEmergencyUsesVisibleWarning() {
        completeOnboarding()
        completeImmediateFlow(choice: "Sesi privat")
        tapButton("Mulai dengan pelan")
        tapButton("Hampir keluar")
        XCTAssertTrue(identifiedElement("private.pause.warning").waitForExistence(timeout: 5))
    }

    private func completeOnboarding() {
        tapNext()
        tapNext()
        let adultConfirmation = app.buttons["onboarding.adultConfirmed"]
        XCTAssertTrue(adultConfirmation.waitForExistence(timeout: 5))
        adultConfirmation.tap()
        XCTAssertTrue(nextButton.isEnabled)
        tapNext()
        for _ in 0..<8 { tapNext() }
        let finishButton = app.buttons["onboarding.finish"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        XCTAssertTrue(finishButton.isEnabled)
        finishButton.tap()
        XCTAssertTrue(app.tabBars.buttons["Hari Ini"].waitForExistence(timeout: 5))
    }

    private func completeImmediateFlow(choice: String) {
        tapButton("Aku mau onani sekarang")
        XCTAssertTrue(identifiedElement("immediate.action").waitForExistence(timeout: 5))
        tapButton(choice)
        tapButton("Berikutnya")
        tapButton("Berikutnya")
        tapButton("Lanjutkan")
    }

    private var nextButton: XCUIElement { app.buttons["onboarding.next"] }

    private func tapNext() {
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        XCTAssertTrue(nextButton.isEnabled)
        nextButton.tap()
    }

    private func tapButton(_ label: String) {
        let button = app.buttons[label]
        if !button.waitForExistence(timeout: 1) {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isEnabled)
        button.tap()
    }

    private func tapIdentified(_ identifier: String) {
        let element = identifiedElement(identifier)
        for _ in 0..<3 {
            if element.waitForExistence(timeout: 1), element.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(element.isHittable)
        XCTAssertTrue(element.isEnabled)
        element.tap()
    }

    private func identifiedElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

}
