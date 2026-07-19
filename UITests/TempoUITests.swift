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

    private func identifiedElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

}
