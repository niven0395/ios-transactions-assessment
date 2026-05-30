//
//  TransactionDetailViewModelTests.swift
//  Scotiabank Transactions SwiftUI + UIKIT Tests
//
//  The detail screen's presentation model: it maps a `Transaction` into the
//  render-ready values the UIKit view binds to. Pinning these keeps the detail
//  screen's MVVM split honest and the brief's credit/debit rule under test from
//  the view-model side as well as `TransactionStatus`.
//

import Foundation
import Testing
@testable import Scotiabank_Transactions_SwiftUI___UIKIT

@MainActor
@Suite("Transaction detail view model")
struct TransactionDetailViewModelTests {

    @Test("CREDIT maps to the positive-toned 'Credit transaction' header")
    func credit() {
        let viewModel = TransactionDetailViewModel(transaction: .sample(type: .credit))
        #expect(viewModel.statusTitle == "Credit transaction")
        #expect(viewModel.statusTone == .positive)   // view maps .positive → green
    }

    @Test("DEBIT maps to the negative-toned 'Debit transaction' header")
    func debit() {
        let viewModel = TransactionDetailViewModel(transaction: .sample(type: .debit))
        #expect(viewModel.statusTitle == "Debit transaction")
        #expect(viewModel.statusTone == .negative)   // view maps .negative → red
    }

    @Test("An unknown type degrades to a neutral 'Transaction' header")
    func unknown() {
        let viewModel = TransactionDetailViewModel(transaction: .sample(type: .unknown))
        #expect(viewModel.statusTitle == "Transaction")
        #expect(viewModel.statusTone == .neutral)
    }

    @Test("Maps the From row, card suffix, and formatted amount from the model")
    func presentationValues() {
        let viewModel = TransactionDetailViewModel(transaction: .sample(
            value: 200.20,
            fromAccount: "Momentum Regular Visa",
            fromCardNumber: "4537350001688012"
        ))
        #expect(viewModel.fromAccount == "Momentum Regular Visa")
        #expect(viewModel.cardSuffix == "8012")        // last four of the card number
        #expect(viewModel.amountText == "$200.20")     // CurrencyFormatter, en_CA CAD
    }
}
