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
        XCTAssertTrue(app.otherElements["onboarding.v2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Lanjut"].exists)
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
        app.buttons["Lanjut"].tap()
        app.buttons["Lanjut"].tap()
        app.switches["Saya berusia 18 tahun atau lebih"].tap()
        app.buttons["Lanjut"].tap()
        for _ in 0..<8 { app.buttons["Lanjut"].tap() }
        app.buttons["Masuk ke Hari Ini"].tap()
        XCTAssertTrue(app.tabBars.buttons["Hari Ini"].waitForExistence(timeout: 5))
    }
}
