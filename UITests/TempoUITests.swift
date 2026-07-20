import XCTest

final class TempoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-tempo-ui-testing-reset"]
        app.launch()
    }

    func testOnboardingStartsWithSevenStepFoundation() {
        XCTAssertTrue(identifiedElement("onboarding.v22").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboarding.adultConfirmed"].exists)
        XCTAssertTrue(nextButton.exists)
        XCTAssertFalse(nextButton.isEnabled)
    }

    func testOnboardingCanReachFourTabShell() {
        completeOnboarding()
        XCTAssertTrue(app.tabBars.buttons["Hari Ini"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Program"].exists)
        XCTAssertTrue(app.tabBars.buttons["Progres"].exists)
        XCTAssertTrue(app.tabBars.buttons["Pengaturan"].exists)
        XCTAssertFalse(app.tabBars.buttons["Profil"].exists)
    }

    func testOnboardingDraftSurvivesRelaunch() {
        confirmAdultAndAdvance()
        tapNext()
        XCTAssertFalse(app.buttons["onboarding.adultConfirmed"].exists)

        app.terminate()
        app = XCUIApplication()
        app.launch()

        XCTAssertTrue(identifiedElement("onboarding.v22").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.adultConfirmed"].exists)
        XCTAssertTrue(nextButton.exists)
    }

    func testProgramCalendarIsReachableAfterBaseline() {
        completeOnboarding()
        app.tabBars.buttons["Program"].tap()
        XCTAssertTrue(identifiedElement("tab.program").waitForExistence(timeout: 5))
        XCTAssertTrue(identifiedElement("program.week.summary").exists)
    }

    func testProgramWeekNavigationAndTodayResetAreReachable() {
        completeOnboarding()
        app.tabBars.buttons["Program"].tap()

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
        waitForValue(badge, value: "Minggu \(currentWeekNumber + 1)")

        tapIdentified("program.week.today")
        waitForValue(badge, value: currentWeek)

        next.tap()
        waitForValue(badge, value: "Minggu \(currentWeekNumber + 1)")
        let previous = app.buttons["program.week.previous"]
        XCTAssertTrue(previous.waitForExistence(timeout: 5))
        XCTAssertTrue(previous.isEnabled)
        previous.tap()
        waitForValue(badge, value: currentWeek)
    }

    func testPrimaryActivityUsesCompactReadinessBeforeOpening() {
        completeOnboarding()
        tapIdentified("today.primary.start")
        XCTAssertTrue(identifiedElement("today.readiness.confirm").waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["today.readiness.noSymptoms"].exists)
    }

    func testPainReadinessRoutesToHealthCheckAndClearRecheckRestoresImmediatePrivateFlow() {
        completeOnboarding()
        tapIdentified("today.primary.start")
        setSwitch("today.readiness.noSymptoms", to: false)
        tapIdentified("today.readiness.symptom.pain")
        tapIdentified("today.readiness.confirm")

        XCTAssertTrue(identifiedElement("health.check").waitForExistence(timeout: 5))
        confirmIdentifiedToggle("health.check.confirmed")
        confirmIdentifiedToggle("health.check.medicalFollowUp")
        tapIdentifiedButton("health.check.submit")

        XCTAssertTrue(app.tabBars.buttons["Hari Ini"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Hari Ini"].tap()
        completeQuickPrivateFlow()
        XCTAssertTrue(identifiedElement("private.session.v22").waitForExistence(timeout: 5))
    }

    func testSettingsActivityPreferenceCanBeUpdatedWithoutRepeatingOnboarding() {
        completeOnboarding()
        app.tabBars.buttons["Pengaturan"].tap()
        tapButton("Preferensi aktivitas")
        tapIdentified("profile.activityPreference.open")

        let preferenceSheet = identifiedElement("profile.activityPreference.sheet")
        XCTAssertTrue(preferenceSheet.waitForExistence(timeout: 5))
        tapIdentified("profile.activityPreference.breathingAndMobility")
        XCTAssertTrue(identifiedElement("profile.activityPreference.validation").waitForExistence(timeout: 5))
        tapNavigationBarButton("Selesai")
        XCTAssertTrue(preferenceSheet.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Latihan napas dan mobilitas"].waitForExistence(timeout: 5))
    }

    func testManualPostponeOpensTheLinkedReplacement() {
        completeOnboarding()
        app.tabBars.buttons["Program"].tap()

        tapIdentified("program.day.2")
        tapIdentified("program.plan.actionable")
        XCTAssertTrue(identifiedElement("plan.detail.postpone").waitForExistence(timeout: 5))
        tapIdentified("plan.detail.postpone")
        tapButton("Cari satu slot aman")

        XCTAssertTrue(identifiedElement("plan.detail.alreadyRescheduled").waitForExistence(timeout: 8))
        XCTAssertFalse(identifiedElement("plan.detail.postpone").exists)
        XCTAssertFalse(app.alerts["Rencana belum dapat diubah"].exists)
    }

    func testReplaceWithRecoveryUsesExplicitConfirmation() {
        completeOnboarding()
        app.tabBars.buttons["Program"].tap()
        tapIdentified("program.plan.actionable")
        tapIdentified("plan.detail.recovery")
        XCTAssertTrue(app.buttons["Ganti dengan pemulihan"].waitForExistence(timeout: 5))
        app.buttons["Ganti dengan pemulihan"].tap()
        XCTAssertTrue(identifiedElement("plan.detail.success").waitForExistence(timeout: 5))
    }

    func testMultipleSafetyHoldsNeedConfirmationBeforeClearRecheck() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-tempo-ui-testing-reset", "-tempo-ui-testing-multiple-safety-holds"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Pengaturan"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Pengaturan"].tap()
        tapButton("Keselamatan")
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
        waitForValue(submit, value: "Siap")
        tapIdentifiedButton("health.check.submit")
        XCTAssertTrue(app.tabBars.buttons["Pengaturan"].waitForExistence(timeout: 5))
    }

    func testQuickPrivateFlowRequiresAtMostThreeTapsAfterPanelAppears() {
        completeOnboarding()
        tapIdentified("today.quick.private")
        XCTAssertTrue(identifiedElement("immediate.action.v22").waitForExistence(timeout: 5))

        var interactionCount = 0
        tapIdentified("immediate.intensity.medium")
        interactionCount += 1
        tapIdentified("immediate.start")
        interactionCount += 1

        XCTAssertLessThanOrEqual(interactionCount, 3)
        XCTAssertTrue(identifiedElement("private.session.v22").waitForExistence(timeout: 5))
    }

    func testQuickFlowNeverDefaultsToReset() {
        completeOnboarding()
        tapIdentified("today.quick.private")
        XCTAssertTrue(identifiedElement("immediate.choice.privateSession").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["immediate.choice.privateSession"].isSelected)
        XCTAssertFalse(app.buttons["immediate.choice.reset"].isSelected)
    }

    func testImmediateResetRouteOpensFiveMinuteReset() {
        completeOnboarding()
        tapIdentified("today.quick.private")
        tapIdentified("immediate.choice.reset")
        tapIdentified("immediate.start")
        XCTAssertTrue(identifiedElement("breathing.session").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Reset lima menit"].exists)
    }

    func testImmediateGuidedRouteOpensGuidedCoach() {
        completeOnboarding()
        tapIdentified("today.quick.private")
        tapIdentified("immediate.choice.guided")
        tapIdentified("immediate.start")
        XCTAssertTrue(identifiedElement("guided.session.v22").waitForExistence(timeout: 5))
    }

    func testPrivateActiveControlsFitWithoutScrolling() {
        completeOnboarding()
        completeQuickPrivateFlow()
        tapIdentified("private.start")
        XCTAssertTrue(identifiedElement("private.controls").waitForExistence(timeout: 5))
        XCTAssertTrue(identifiedElement("private.intensity").exists)
        XCTAssertTrue(app.buttons["Jeda"].isHittable)
        XCTAssertTrue(app.buttons["Mendekati batas"].isHittable)
        XCTAssertTrue(app.buttons["Selesai"].isHittable)
    }

    func testPrivateManualPauseEntersRecoveryWithoutRedWarning() {
        completeOnboarding()
        completeQuickPrivateFlow()
        tapIdentified("private.start")
        tapButton("Jeda")
        XCTAssertTrue(identifiedElement("private.recovery").waitForExistence(timeout: 5))
        XCTAssertFalse(identifiedElement("private.pause.warning").exists)
    }

    func testPrivateThresholdUsesVisibleWarning() {
        completeOnboarding()
        completeQuickPrivateFlow()
        tapIdentified("private.start")
        tapIdentified("private.intensity.nearLimit")
        XCTAssertTrue(identifiedElement("private.pause.warning").waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'DARURAT'")).firstMatch.exists)
    }

    func testPrivateEmergencyUsesVisibleWarningWithoutMedicalEmergencyCopy() {
        completeOnboarding()
        completeQuickPrivateFlow()
        tapIdentified("private.start")
        tapButton("Mendekati batas")
        XCTAssertTrue(identifiedElement("private.pause.warning").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["STOP SEKARANG"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'DARURAT'")).firstMatch.exists)
    }

    func testGuidedPrecheckUsesTodayReadinessAndActiveControlsFit() {
        completeOnboarding()
        saveDefaultReadiness()
        tapIdentified("today.quick.private")
        tapIdentified("immediate.choice.guided")
        tapIdentified("immediate.start")
        XCTAssertTrue(identifiedElement("guided.session.v22").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Diisi dari readiness hari ini"].exists)
        tapIdentified("guided.start")
        tapButton("Saya siap lebih awal")
        XCTAssertTrue(identifiedElement("guided.active").waitForExistence(timeout: 5))
        XCTAssertTrue(identifiedElement("guided.controls").exists)
        XCTAssertTrue(app.buttons["Jeda"].isHittable)
        XCTAssertTrue(app.buttons["Mendekati batas"].isHittable)
        XCTAssertTrue(app.buttons["Selesai"].isHittable)
    }

    private func completeOnboarding() {
        confirmAdultAndAdvance()
        for _ in 0..<5 { tapNext() }
        let finishButton = app.buttons["onboarding.finish"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        XCTAssertTrue(finishButton.isEnabled)
        finishButton.tap()
        XCTAssertTrue(app.tabBars.buttons["Hari Ini"].waitForExistence(timeout: 8))
    }

    private func confirmAdultAndAdvance() {
        let adult = app.buttons["onboarding.adultConfirmed"]
        XCTAssertTrue(adult.waitForExistence(timeout: 5))
        adult.tap()
        XCTAssertTrue(nextButton.isEnabled)
        tapNext()
    }

    private func completeQuickPrivateFlow() {
        tapIdentified("today.quick.private")
        XCTAssertTrue(identifiedElement("immediate.action.v22").waitForExistence(timeout: 5))
        tapIdentified("immediate.start")
        XCTAssertTrue(identifiedElement("private.session.v22").waitForExistence(timeout: 5))
    }

    private func saveDefaultReadiness() {
        if identifiedElement("today.readiness.compact").exists {
            tapIdentified("today.readiness.compact")
        } else {
            tapIdentified("today.primary.start")
        }
        tapIdentified("today.readiness.confirm")
        XCTAssertTrue(identifiedElement("tab.today").waitForExistence(timeout: 5))
    }

    private var nextButton: XCUIElement { app.buttons["onboarding.next"] }

    private func tapNext() {
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        XCTAssertTrue(nextButton.isEnabled)
        nextButton.tap()
    }

    private func tapButton(_ label: String) {
        let button = app.buttons[label]
        for _ in 0..<4 {
            if button.waitForExistence(timeout: 1), button.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(button.isHittable)
        button.tap()
    }

    private func tapIdentified(_ identifier: String) {
        let element = identifiedElement(identifier)
        for _ in 0..<4 {
            if element.waitForExistence(timeout: 1), element.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(identifier)")
        XCTAssertTrue(element.isEnabled)
        XCTAssertTrue(element.isHittable)
        element.tap()
    }

    private func tapIdentifiedButton(_ identifier: String) {
        let button = app.buttons[identifier]
        for _ in 0..<4 {
            if button.waitForExistence(timeout: 1), button.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(button.isHittable)
        button.tap()
    }

    private func confirmIdentifiedToggle(_ identifier: String) {
        setSwitch(identifier, to: true)
    }

    private func setSwitch(_ identifier: String, to desired: Bool) {
        let toggle = app.switches[identifier]
        for _ in 0..<4 {
            if toggle.waitForExistence(timeout: 1), toggle.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(toggle.isEnabled)
        let isOn = (toggle.value as? String) == "1"
        if isOn != desired {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
    }

    private func tapNavigationBarButton(_ label: String) {
        let button = app.navigationBars.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(button.isHittable)
        button.tap()
    }

    private func waitForValue(_ element: XCUIElement, value: String) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    private func identifiedElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
