//
//  Transaction+Fixtures.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  Sample data for SwiftUI previews and unit tests. Kept in the app target so
//  previews can use it; tests reach it via `@testable import`.
//

import Foundation

extension Transaction {
    static func sample(
        key: String = "sample-key",
        type: TransactionType = .credit,
        merchantName: String = "Payment-thank You Scotiabank",
        description: String? = "Payment (Scotiabank)",
        value: Decimal = 200.20,
        postedDate: String = "2021-05-31",
        fromAccount: String = "Momentum Regular Visa",
        fromCardNumber: String = "4537350001688012"
    ) -> Transaction {
        Transaction(
            key: key,
            transactionType: type,
            merchantName: merchantName,
            description: description,
            amount: Amount(value: value, currency: "CAD"),
            postedDate: postedDate,
            fromAccount: fromAccount,
            fromCardNumber: fromCardNumber
        )
    }

    static let previewCredit = sample(key: "c1", type: .credit)
    static let previewDebit = sample(
        key: "d1", type: .debit, merchantName: "Cash Advance Fee",
        description: "Cash advance", value: 5, postedDate: "2021-03-30"
    )
}
