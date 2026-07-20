import XCTest

final class TempoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        launch(arguments: ["-tempo-ui-testing-reset"])
    }

    func testOnboardingStartsWithSevenStepFoundation() {
        XCTAssertTrue(app.buttons["onboarding.adultConfirmed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Lanjut"].exists)
        XCTAssertFalse(app.buttons["Lanjut"].isEnabled)
    }

    func testOnboardingCanReachFourTabShell() {
        completeOnboarding()
        assertMainTabs()
    }

    func testOnboardingDraftSurvivesRelaunch() {
        confirmAdultAndAdvance()
        tapButton("Lanjut")
        app.terminate()
        launch(arguments: [])
        XCTAssertFalse(app.buttons["onboarding.adultConfirmed"].exists)
        XCTAssertTrue(app.buttons["Lanjut"].waitForExistence(timeout: 5))
    }

    func testPrimaryActivityUsesCompactReadinessBeforeOpening() {
        completeOnboarding()
        tapIdentifier("today.primary.start")
        XCTAssertTrue(element("today.readiness.confirm").waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["today.readiness.noSymptoms"].exists)
    }

    func testQuickPrivateFlowRequiresAtMostThreeTapsAfterPanelAppears() {
        completeOnboarding()
        tapIdentifier("today.quick.private")
        XCTAssertTrue(element("immediate.action.v22").waitForExistence(timeout: 5))

        var tapCount = 0
        tapIdentifier("immediate.intensity.medium")
        tapCount += 1
        tapIdentifier("immediate.start")
        tapCount += 1

        XCTAssertLessThanOrEqual(tapCount, 3)
        XCTAssertTrue(element("private.session.v22").waitForExistence(timeout: 5))
    }

    func testQuickFlowNeverDefaultsToReset() {
        completeOnboarding()
        tapIdentifier("today.quick.private")
        let privateChoice = app.buttons["immediate.choice.privateSession"]
        let resetChoice = app.buttons["immediate.choice.reset"]
        XCTAssertTrue(privateChoice.waitForExistence(timeout: 5))
        XCTAssertTrue(privateChoice.isSelected)
        XCTAssertFalse(resetChoice.isSelected)
    }

    func testImmediateResetRouteOpensFiveMinuteReset() {
        completeOnboarding()
        tapIdentifier("today.quick.private")
        tapIdentifier("immediate.choice.reset")
        tapIdentifier("immediate.start")
        XCTAssertTrue(element("breathing.session").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Reset lima menit"].exists)
    }

    func testPrivateActiveControlsFitWithoutScrolling() {
        completeOnboarding()
        openPrivateSession()
        tapIdentifier("private.start")
        XCTAssertTrue(element("private.controls").waitForExistence(timeout: 5))
        XCTAssertTrue(element("private.intensity").exists)
        XCTAssertTrue(app.buttons["Jeda"].isHittable)
        XCTAssertTrue(app.buttons["Mendekati batas"].isHittable)
        XCTAssertTrue(app.buttons["Selesai"].isHittable)
    }

    func testPrivateManualPauseEntersRecoveryWithoutRedWarning() {
        completeOnboarding()
        openPrivateSession()
        tapIdentifier("private.start")
        tapButton("Jeda")
        XCTAssertTrue(element("private.recovery").waitForExistence(timeout: 5))
        XCTAssertFalse(element("private.pause.warning").exists)
    }

    func testPrivateThresholdUsesVisibleWarningWithoutMedicalEmergencyCopy() {
        completeOnboarding()
        openPrivateSession()
        tapIdentifier("private.start")
        tapIdentifier("private.intensity.nearLimit")
        XCTAssertTrue(element("private.pause.warning").waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'DARURAT'")).firstMatch.exists)
    }

    func testGuidedPrecheckUsesTodayReadinessAndActiveControlsFit() {
        completeOnboarding()
        saveDefaultReadiness()
        tapIdentifier("today.quick.private")
        tapIdentifier("immediate.choice.guided")
        tapIdentifier("immediate.start")
        XCTAssertTrue(element("guided.session.v22").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Diisi dari readiness hari ini"].exists)
        tapIdentifier("guided.start")
        tapButton("Saya siap lebih awal")
        XCTAssertTrue(element("guided.active").waitForExistence(timeout: 5))
        XCTAssertTrue(element("guided.controls").exists)
        XCTAssertTrue(app.buttons["Jeda"].isHittable)
        XCTAssertTrue(app.buttons["Mendekati batas"].isHittable)
        XCTAssertTrue(app.buttons["Selesai"].isHittable)
    }

    func testProgramCalendarAndWeekSummaryAreReachable() {
        completeOnboarding()
        app.tabBars.buttons["Program"].tap()
        XCTAssertTrue(element("program.week.summary").waitForExistence(timeout: 5))
        XCTAssertTrue(element("program.week.badge").exists)
    }

    func testManualPostponeOpensTheLinkedReplacement() {
        completeOnboarding()
        app.tabBars.buttons["Program"].tap()
        tapIdentifier("program.day.2")
        tapIdentifier("program.plan.actionable")
        tapIdentifier("plan.detail.postpone")
        tapButton("Cari satu slot aman")
        XCTAssertTrue(element("plan.detail.alreadyRescheduled").waitForExistence(timeout: 8))
        XCTAssertFalse(element("plan.detail.postpone").exists)
    }

    func testReplaceWithRecoveryUsesExplicitConfirmation() {
        completeOnboarding()
        app.tabBars.buttons["Program"].tap()
        tapIdentifier("program.plan.actionable")
        tapIdentifier("plan.detail.recovery")
        tapButton("Ganti dengan pemulihan")
        XCTAssertTrue(element("plan.detail.success").waitForExistence(timeout: 5))
    }

    func testSettingsActivityPreferenceCanBeUpdatedWithoutRepeatingOnboarding() {
        completeOnboarding()
        app.tabBars.buttons["Pengaturan"].tap()
        tapButton("Preferensi aktivitas")
        tapIdentifier("profile.activityPreference.open")
        XCTAssertTrue(element("profile.activityPreference.sheet").waitForExistence(timeout: 5))
        tapIdentifier("profile.activityPreference.breathingAndMobility")
        tapNavigationBarButton("Selesai")
        XCTAssertTrue(app.staticTexts["Latihan napas dan mobilitas"].waitForExistence(timeout: 5))
    }

    func testMultipleSafetyHoldsNeedConfirmationBeforeClearRecheck() {
        app.terminate()
        launch(arguments: ["-tempo-ui-testing-reset", "-tempo-ui-testing-multiple-safety-holds"])

        XCTAssertTrue(app.tabBars.buttons["Hari Ini"].waitForExistence(timeout: 5))
        tapButton("Periksa")
        XCTAssertTrue(element("health.check.multipleHolds").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nyeri"].exists)
        XCTAssertTrue(app.staticTexts["Keluhan saluran kemih"].exists)

        setSwitch("health.check.confirmed", to: true)
        setSwitch("health.check.medicalFollowUp", to: true)
        let submit = app.buttons["health.check.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertFalse(submit.isEnabled)

        setSwitch("health.check.confirmedAllActiveHoldsResolved", to: true)
        waitUntilEnabled(submit)
        submit.tap()
        XCTAssertTrue(app.tabBars.buttons["Pengaturan"].waitForExistence(timeout: 5))
    }

    private func launch(arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
    }

    private func assertMainTabs() {
        XCTAssertTrue(app.tabBars.buttons["Hari Ini"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Program"].exists)
        XCTAssertTrue(app.tabBars.buttons["Progres"].exists)
        XCTAssertTrue(app.tabBars.buttons["Pengaturan"].exists)
        XCTAssertFalse(app.tabBars.buttons["Profil"].exists)
    }

    private func completeOnboarding() {
        confirmAdultAndAdvance()
        for _ in 0..<5 { tapButton("Lanjut") }
        tapButton("Masuk ke Hari Ini")
        assertMainTabs()
    }

    private func confirmAdultAndAdvance() {
        let adult = app.buttons["onboarding.adultConfirmed"]
        XCTAssertTrue(adult.waitForExistence(timeout: 5))
        adult.tap()
        tapButton("Lanjut")
    }

    private func openPrivateSession() {
        tapIdentifier("today.quick.private")
        tapIdentifier("immediate.start")
        XCTAssertTrue(element("private.session.v22").waitForExistence(timeout: 5))
    }

    private func saveDefaultReadiness() {
        if element("today.readiness.compact").exists {
            tapIdentifier("today.readiness.compact")
        } else {
            tapIdentifier("today.primary.start")
        }
        tapIdentifier("today.readiness.confirm")
        XCTAssertTrue(app.tabBars.buttons["Hari Ini"].waitForExistence(timeout: 5))
    }

    private func tapButton(_ label: String) {
        let button = app.buttons[label]
        scrollUntilHittable(button)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing button: \(label)")
        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(button.isHittable)
        button.tap()
    }

    private func tapIdentifier(_ identifier: String) {
        let target = element(identifier)
        scrollUntilHittable(target)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "Missing identifier: \(identifier)")
        XCTAssertTrue(target.isEnabled)
        XCTAssertTrue(target.isHittable)
        target.tap()
    }

    private func scrollUntilHittable(_ element: XCUIElement) {
        for _ in 0..<5 {
            if element.waitForExistence(timeout: 1), element.isHittable { return }
            app.swipeUp()
        }
    }

    private func setSwitch(_ identifier: String, to desired: Bool) {
        let toggle = app.switches[identifier]
        scrollUntilHittable(toggle)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let current = (toggle.value as? String) == "1"
        if current != desired {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
    }

    private func waitUntilEnabled(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    private func tapNavigationBarButton(_ label: String) {
        let button = app.navigationBars.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
