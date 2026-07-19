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
        XCTAssertTrue(app.otherElements["tab.program"].waitForExistence(timeout: 5))
    }

    func testImmediatePrivateRouteUsesThreeDecisionFlow() {
        completeOnboarding()
        app.buttons["Aku mau onani sekarang"].tap()
        XCTAssertTrue(app.otherElements["immediate.action"].waitForExistence(timeout: 5))
        app.buttons["Sesi privat"].tap()
        app.buttons["Berikutnya"].tap()
        app.buttons["Berikutnya"].tap()
        app.buttons["Lanjutkan"].tap()
        XCTAssertTrue(app.otherElements["private.session.timer"].waitForExistence(timeout: 5))
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

    private var nextButton: XCUIElement { app.buttons["onboarding.next"] }

    private func tapNext() {
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        XCTAssertTrue(nextButton.isEnabled)
        nextButton.tap()
    }
}
