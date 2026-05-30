//
//  TransactionDetailViewModel.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  Presentation model for the detail screen (Figure 1). It maps a `Transaction`
//  into render-ready values so `TransactionDetailViewController` holds no
//  formatting or derivation logic — the same Model→ViewModel→View split the list
//  screen uses, now applied to the detail screen too.
//
//  Deliberately view-agnostic: it exposes a semantic `statusTone` rather than a
//  `UIColor`, so the rule is unit-tested directly and the colour mapping stays in
//  the view. Reuses the existing pure types (`TransactionStatus`,
//  `CurrencyFormatter`) — it adds no new domain logic.
//

import Foundation

@MainActor
final class TransactionDetailViewModel {

    /// Headline title, e.g. "Credit transaction" / "Debit transaction".
    let statusTitle: String
    /// Semantic tone for the checkmark; the view maps `.positive` → green, etc.
    let statusTone: TransactionStatus.Tone
    /// Source account name for the "From" row, e.g. "Momentum Regular Visa".
    let fromAccount: String
    /// Last four card digits shown beside the account, e.g. "8012".
    let cardSuffix: String
    /// Formatted amount for the "Amount" row, e.g. "$200.20".
    let amountText: String

    init(transaction: Transaction) {
        statusTitle = transaction.status.title
        statusTone = transaction.status.tone
        fromAccount = transaction.fromAccount
        cardSuffix = transaction.cardSuffix
        amountText = CurrencyFormatter.string(from: transaction.amount)
    }
}
