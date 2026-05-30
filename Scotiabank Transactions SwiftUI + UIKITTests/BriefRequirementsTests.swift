//
//  BriefRequirementsTests.swift
//  Scotiabank Transactions SwiftUI + UIKIT Tests
//
//  Pins the assignment's two most explicit acceptance criteria as pure logic:
//   • CREDIT → green checkmark + "Credit transaction"; DEBIT → red + "Debit
//     transaction" (the detail screen's status header).
//   • The ToolTip's "Show more"/"Show less" expand/collapse text.
//  Both used to live only inside SwiftUI views; the logic is now testable here,
//  with the round-trip + toggle also exercised by the UI tests.
//

import Foundation
import Testing
@testable import Scotiabank_Transactions_SwiftUI___UIKIT

// MARK: - Detail status (credit/debit checkmark + title)

@Suite("Transaction status")
struct TransactionStatusTests {

    @Test("CREDIT shows the green title 'Credit transaction'")
    func credit() {
        let status = Transaction.sample(type: .credit).status
        #expect(status == .credit)
        #expect(status.title == "Credit transaction")
        #expect(status.tone == .positive)   // view maps .positive → green
    }

    @Test("DEBIT shows the red title 'Debit transaction'")
    func debit() {
        let status = Transaction.sample(type: .debit).status
        #expect(status == .debit)
        #expect(status.title == "Debit transaction")
        #expect(status.tone == .negative)   // view maps .negative → red
    }

    @Test("An unknown type degrades gracefully to a neutral 'Transaction'")
    func unknown() {
        let status = Transaction.sample(type: .unknown).status
        #expect(status == .unknown)
        #expect(status.title == "Transaction")
        #expect(status.tone == .neutral)
    }

    @Test("Credit and debit are visually distinct (the brief's core distinction)")
    func creditAndDebitDiffer() {
        #expect(TransactionStatus.credit.tone != TransactionStatus.debit.tone)
        #expect(TransactionStatus.credit.title != TransactionStatus.debit.title)
    }
}

// MARK: - ToolTip expand/collapse

@Suite("ToolTip expand/collapse")
struct TooltipTests {

    @Test("Collapsed shows only the base message")
    func collapsed() {
        #expect(TooltipContent.message(isExpanded: false) == TooltipContent.baseMessage)
        #expect(TooltipContent.toggleLabel(isExpanded: false) == "Show more")
    }

    @Test("Expanded appends the extra message after the base one")
    func expanded() {
        let expanded = TooltipContent.message(isExpanded: true)
        #expect(expanded == "\(TooltipContent.baseMessage) \(TooltipContent.expandedMessage)")
        #expect(expanded.contains(TooltipContent.baseMessage))
        #expect(expanded.contains(TooltipContent.expandedMessage))
        #expect(TooltipContent.toggleLabel(isExpanded: true) == "Show less")
    }

    @Test("The messages match the brief's exact copy")
    func exactCopy() {
        #expect(TooltipContent.baseMessage ==
                "Transactions are processed Monday to Friday (excluding holidays).")
        #expect(TooltipContent.expandedMessage ==
                "Transactions made before 8:30 pm ET Monday to Friday (excluding holidays) will show up in your account the same day.")
    }
}
