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
        guard let currentWeek = badge.value as? String,
              let currentWeekNumber = Int(currentWeek.filter(\.isNumber)) else {
            return XCTFail("Calendar week badge should expose its displayed week number")
        }
        let next = app.buttons["program.week.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertTrue(next.isEnabled)
        next.tap()
        let changedWeek = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", currentWeek),
            object: badge
        )
        wait(for: [changedWeek], timeout: 5)
        let nextWeek = badge.value as? String
        XCTAssertEqual(nextWeek, "Minggu \(currentWeekNumber + 1)")

        let today = identifiedElement("program.week.today")
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        let todayResetWeek = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", currentWeek),
            object: badge
        )
        wait(for: [todayResetWeek], timeout: 5)
        XCTAssertTrue(range.exists)
        XCTAssertEqual(badge.value as? String, currentWeek)

        next.tap()
        let nextWeekAgain = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Minggu \(currentWeekNumber + 1)"),
            object: badge
        )
        wait(for: [nextWeekAgain], timeout: 5)

        let previous = app.buttons["program.week.previous"]
        XCTAssertTrue(previous.waitForExistence(timeout: 5))
        let previousEnabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: previous
        )
        wait(for: [previousEnabled], timeout: 5)
        previous.tap()
        let restoredWeek = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", currentWeek),
            object: badge
        )
        wait(for: [restoredWeek], timeout: 5)
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
        confirmIdentifiedToggle("health.check.confirmed")
        confirmIdentifiedToggle("health.check.medicalFollowUp")
        tapIdentifiedButton("health.check.submit")

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
        let preferenceSheet = identifiedElement("profile.activityPreference.sheet")
        XCTAssertTrue(preferenceSheet.waitForExistence(timeout: 5))
        tapIdentified("profile.activityPreference.breathingAndMobility")
        XCTAssertTrue(identifiedElement("profile.activityPreference.validation").waitForExistence(timeout: 5))
        tapNavigationBarButton("Selesai")
        XCTAssertTrue(preferenceSheet.waitForNonExistence(timeout: 5))
        let value = app.staticTexts["profile.activityPreference.value"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        XCTAssertEqual(value.label, "Latihan napas dan mobilitas")
    }

    func testManualPostponeOpensTheLinkedReplacement() {
        completeOnboarding()
        app.tabBars.buttons["Program"].tap()

        tapIdentified("program.day.2")
        tapIdentified("program.plan.actionable")
        XCTAssertTrue(identifiedElement("plan.detail.postpone").waitForExistence(timeout: 5))
        tapIdentified("plan.detail.postpone")
        XCTAssertTrue(identifiedElement("plan.detail.replacement").waitForExistence(timeout: 5))
        XCTAssertTrue(identifiedElement("plan.detail.alreadyRescheduled").waitForExistence(timeout: 5))
        XCTAssertFalse(identifiedElement("plan.detail.postpone").exists)
        XCTAssertFalse(app.alerts["Rencana belum dapat diubah"].exists)

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()
        XCTAssertTrue(identifiedElement("program.plan.postponedSource").waitForExistence(timeout: 5))
    }

    func testMultipleSafetyHoldsNeedConfirmationBeforeClearRecheck() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-tempo-ui-testing-reset", "-tempo-ui-testing-multiple-safety-holds"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Profil"].tap()
        tapIdentified("profile.safety.open")
        XCTAssertTrue(identifiedElement("health.check.multipleHolds").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nyeri"].exists)
        XCTAssertTrue(app.staticTexts["Keluhan saluran kemih"].exists)

        confirmIdentifiedToggle("health.check.confirmed")
        confirmIdentifiedToggle("health.check.medicalFollowUp")
        let submit = app.buttons["health.check.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertFalse(submit.isEnabled)

        confirmIdentifiedToggle("health.check.confirmedAllActiveHoldsResolved")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Siap"), object: submit)
        if XCTWaiter().wait(for: [ready], timeout: 5) != .completed {
            XCTFail("Unexpected submit state: \(String(describing: submit.value))")
        }
        tapIdentifiedButton("health.check.submit")
        let safetyStatus = app.staticTexts["profile.safety.status"]
        XCTAssertTrue(safetyStatus.waitForExistence(timeout: 5))
        XCTAssertTrue(safetyStatus.label.hasPrefix("Tidak ada safety hold aktif"))
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

    /// Uses the concrete accessibility role for controls whose generic SwiftUI
    /// descendants can otherwise resolve to a non-hittable label or container.
    private func tapIdentifiedButton(_ identifier: String, scrollIntoView: Bool = true) {
        let button = app.buttons[identifier]
        if scrollIntoView {
            for _ in 0..<3 {
                if button.waitForExistence(timeout: 1), button.isHittable { break }
                app.swipeUp()
            }
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == 1"),
            object: button
        )
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 5), .completed)
        XCTAssertTrue(button.isHittable)
        button.tap()
    }

    private func confirmIdentifiedToggle(_ identifier: String) {
        let toggle = app.switches[identifier]
        for _ in 0..<3 {
            if toggle.waitForExistence(timeout: 1), toggle.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(toggle.isEnabled)
        XCTAssertTrue(toggle.isHittable)
        // A rightward gesture sets a native switch to ON idempotently. This is
        // more reliable than tapping a fixed coordinate when Form rows move as
        // conditional confirmation controls appear.
        toggle.swipeRight()
    }

    private func tapNavigationBarButton(_ label: String) {
        let button = app.navigationBars.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(button.isHittable)
        button.tap()
    }

    private func identifiedElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

}
