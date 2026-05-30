//
//  Scotiabank_Transactions_SwiftUI___UIKITUITests.swift
//  Scotiabank Transactions SwiftUI + UIKIT UI Tests
//
//  End-to-end UI tests covering the core flow: the list loads, tapping a row
//  opens the detail sheet, and Close dismisses it back to the list.
//

import XCTest

final class TransactionsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTappingTransactionOpensAndClosesDetail() throws {
        let app = XCUIApplication()
        app.launch()

        // Tap the first transaction row, targeted by its stable accessibility
        // identifier so the tap lands on a real row and never on a section-header
        // cell (whichever element type SwiftUI's `List` surfaces it as).
        let firstRow = app.descendants(matching: .any)["transactionRow"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "Transaction list should load")
        firstRow.tap()

        // Detail sheet shows the navigation title and a Close button. Generous
        // timeouts: the sheet animates in and the UIKit detail builds its layout
        // programmatically, which can take a beat on a cold/loaded simulator.
        let detailTimeout = 10.0
        XCTAssertTrue(app.navigationBars["Transaction Details"].waitForExistence(timeout: detailTimeout))

        // The status header shows one of the two required titles (CREDIT/DEBIT). The
        // header combines its checkmark + text into one element, so check both the
        // static-text and other-element queries.
        let statusShown = app.staticTexts["Debit transaction"].waitForExistence(timeout: detailTimeout)
            || app.staticTexts["Credit transaction"].exists
            || app.otherElements["Debit transaction"].exists
            || app.otherElements["Credit transaction"].exists
        XCTAssertTrue(statusShown, "Detail should show a Credit/Debit transaction status title")

        // ToolTip expand/collapse: tapping "Show more" reveals "Show less", and back.
        let showMore = app.buttons["Show more"]
        XCTAssertTrue(showMore.waitForExistence(timeout: detailTimeout), "ToolTip should start collapsed")
        showMore.tap()
        let showLess = app.buttons["Show less"]
        XCTAssertTrue(showLess.waitForExistence(timeout: 5), "Tapping Show more should expand the ToolTip")
        showLess.tap()
        XCTAssertTrue(showMore.waitForExistence(timeout: 5), "Tapping Show less should collapse the ToolTip")

        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Detail should show a Close button")
        close.tap()

        // Back on the list: the detail is dismissed and the list is interactive
        // again. The list's inline title is surfaced by SwiftUI as static text
        // (not a queryable navigation bar), so assert on that plus the detail's
        // dismissal, which is the robust signal that Close returned us home.
        XCTAssertTrue(app.navigationBars["Transaction Details"].waitForNonExistence(timeout: 5),
                      "Tapping Close should dismiss the transaction detail")
        XCTAssertTrue(app.staticTexts["Transactions"].waitForExistence(timeout: 5),
                      "Closing the detail should return to the Transactions list")
    }
}
