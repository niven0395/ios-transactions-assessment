//
//  TransactionGrouping.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  Pure functions that turn a flat `[Transaction]` into date-grouped sections
//  for the list. Kept free of UIKit/SwiftUI so the logic is unit-tested in
//  isolation and reused by both the view model and the diffable data source.
//

import Foundation

/// One date-grouped section of the transaction list. `id` (the raw posted date)
/// makes it usable directly as a diffable-data-source section identifier.
nonisolated struct TransactionSection: Equatable, Hashable, Identifiable, Sendable {
    /// Raw posted date, e.g. "2026-05-29" — stable and unique per day.
    let id: String
    /// Display header, e.g. "FRI, MAY 29, 2026".
    let title: String
    let transactions: [Transaction]
}

enum TransactionGrouping {

    /// Groups transactions by `postedDate`, newest day first. Within a day the
    /// original order from the API is preserved.
    ///
    /// Dates that fail to parse are still grouped (by their raw string) and
    /// sorted after the parseable ones, so nothing is ever dropped.
    static func group(_ transactions: [Transaction]) -> [TransactionSection] {
        let grouped = Dictionary(grouping: transactions, by: \.postedDate)

        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            switch (TransactionDateFormatter.date(from: lhs),
                    TransactionDateFormatter.date(from: rhs)) {
            case let (l?, r?): return l > r          // newest day first
            case (_?, nil): return true              // parseable before raw
            case (nil, _?): return false
            case (nil, nil): return lhs > rhs        // both unparseable: stable
            }
        }

        return sortedKeys.map { key in
            TransactionSection(
                id: key,
                title: TransactionDateFormatter.headerString(from: key),
                transactions: grouped[key] ?? []
            )
        }
    }

    /// Appends one freshly-fetched page onto already-grouped sections, in
    /// O(pageSize) rather than re-grouping the whole accumulated list.
    ///
    /// Pages arrive globally newest-first and contiguous (the service returns
    /// ordered cursor slices), so `newTransactions` only ever extends the tail:
    /// its first day either continues the current last section (same day → merge)
    /// or starts new sections after it. Callers should pass already-deduplicated
    /// items.
    static func append(_ newTransactions: [Transaction],
                       to sections: [TransactionSection]) -> [TransactionSection] {
        guard !newTransactions.isEmpty else { return sections }

        let incoming = group(newTransactions)        // O(pageSize)
        guard let last = sections.last else { return incoming }

        var result = sections
        var tail = incoming
        if let first = tail.first, first.id == last.id {
            // The page continues the current last day — merge into it.
            result[result.count - 1] = TransactionSection(
                id: last.id,
                title: last.title,
                transactions: last.transactions + first.transactions
            )
            tail.removeFirst()
        }
        result.append(contentsOf: tail)
        return result
    }
}
