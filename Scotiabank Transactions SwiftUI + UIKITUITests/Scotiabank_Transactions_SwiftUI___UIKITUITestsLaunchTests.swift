//
//  Scotiabank_Transactions_SwiftUI___UIKITUITestsLaunchTests.swift
//  Scotiabank Transactions SwiftUI + UIKIT UI Tests
//
//  Captures a launch-screen screenshot attachment for each UI configuration.
//

import XCTest

final class TransactionsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool { true }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
