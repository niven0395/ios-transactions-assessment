//
//  TransactionStatus.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  The detail screen's headline rule from the brief: a CREDIT shows a green
//  checkmark titled "Credit transaction", a DEBIT a red checkmark titled "Debit
//  transaction". Modelled here as pure, view-free logic so the rule is unit-tested
//  directly instead of being trapped inside the SwiftUI view. The view reads
//  `title` and maps `tone` to a colour.
//

import Foundation

/// The display status of a transaction on the detail screen.
nonisolated enum TransactionStatus: Sendable, Equatable {
    case credit
    case debit
    /// Forward-compatible fallback for any future/unrecognised type.
    case unknown

    init(_ type: TransactionType) {
        switch type {
        case .credit: self = .credit
        case .debit: self = .debit
        case .unknown: self = .unknown
        }
    }

    /// The detail-screen title, e.g. "Credit transaction".
    var title: String {
        switch self {
        case .credit: "Credit transaction"
        case .debit: "Debit transaction"
        case .unknown: "Transaction"
        }
    }

    /// Semantic colour role for the checkmark — kept colour-free so it's testable.
    /// The view maps `.positive` → green and `.negative` → red.
    enum Tone: Sendable { case positive, negative, neutral }

    var tone: Tone {
        switch self {
        case .credit: .positive
        case .debit: .negative
        case .unknown: .neutral
        }
    }
}

extension Transaction {
    /// The credit/debit display status used by the detail screen.
    var status: TransactionStatus { TransactionStatus(transactionType) }
}
