//
//  Transaction.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  Domain model for a single credit-card transaction, decoded from the bundled
//  `transaction-list.json`. The shape mirrors the JSON exactly; display
//  formatting lives in `Common/` so the model stays a pure data type.
//

import Foundation

/// The type of a transaction.
///
/// Backed by `String` with a custom decoder so an unrecognised value decodes to
/// `.unknown` rather than failing the whole response — this keeps the app
/// forward-compatible if the backend introduces new types later.
nonisolated enum TransactionType: String, Decodable, Sendable {
    case credit = "CREDIT"
    case debit = "DEBIT"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TransactionType(rawValue: raw) ?? .unknown
    }
}

/// A monetary amount with its ISO currency code.
///
/// `value` is a `Decimal` (not `Double`): money should never be modelled as binary
/// floating point. It decodes straight from the JSON number and is exact to the
/// cent for the displayed amounts.
nonisolated struct Amount: Decodable, Equatable, Hashable, Sendable {
    let value: Decimal
    let currency: String
}

/// A single transaction as shown in the list and detail screens.
///
/// `Identifiable` (via `key`) so it works directly with SwiftUI `sheet(item:)`
/// and `Hashable` so it can back a diffable data source snapshot in UIKit.
nonisolated struct Transaction: Decodable, Equatable, Hashable, Identifiable, Sendable {
    var id: String { key }

    let key: String
    let transactionType: TransactionType
    let merchantName: String
    let description: String?
    let amount: Amount
    let postedDate: String
    let fromAccount: String
    let fromCardNumber: String

    enum CodingKeys: String, CodingKey {
        case key
        case transactionType = "transaction_type"
        case merchantName = "merchant_name"
        case description
        case amount
        case postedDate = "posted_date"
        case fromAccount = "from_account"
        case fromCardNumber = "from_card_number"
    }
}

/// Top-level wrapper matching the JSON root object `{ "transactions": [...] }`.
nonisolated struct TransactionListResponse: Decodable, Sendable {
    let transactions: [Transaction]
}

// MARK: - Display helpers

extension Transaction {
    /// The last four digits of the card, e.g. `8012`, for the detail "From" line.
    var cardSuffix: String {
        String(fromCardNumber.suffix(4))
    }

    /// A clearer title for the two merchant patterns whose raw description is
    /// ambiguous (the same "Cash advance payment" text is reused for opposite
    /// directions: a cash advance going out vs. a payment toward the card).
    /// `nil` for every other row, which keeps its raw description. Narrowly
    /// scoped on purpose — not a general category system.
    private var derivedTitle: String? {
        let name = merchantName.lowercased()
        if name.contains("card/loc pay") { return "Payment" }                  // CREDIT: money in
        if name.contains("transit") { return "Payment from Branch" }           // CREDIT: in-branch payment
        if name.contains("cash advance to") { return "Cash advance" }          // DEBIT: money out
        if name.contains("cash advance fee") { return merchantName }           // fee: title is the merchant, ignore the ambiguous description
        return nil
    }

    /// Primary line for the row: the clarified title for the ambiguous patterns,
    /// otherwise the human-readable description, otherwise the raw merchant name
    /// (some rows have no description).
    var primaryText: String {
        if let derivedTitle { return derivedTitle }
        if let description, !description.isEmpty { return description }
        return merchantName
    }

    /// Secondary line beneath `primaryText`: the raw merchant name, shown whenever
    /// it isn't already the primary line. `nil` signals the row to hide its
    /// subtitle entirely.
    var secondaryText: String? {
        primaryText == merchantName ? nil : merchantName
    }
}
