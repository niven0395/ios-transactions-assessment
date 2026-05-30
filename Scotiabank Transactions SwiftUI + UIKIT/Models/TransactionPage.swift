//
//  TransactionPage.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  One page of transactions returned by the service, modelled the way a real
//  paginated banking API would return it: a slice of rows plus an opaque cursor
//  pointing at the next page (nil when the history has been fully read).
//

import Foundation

nonisolated struct TransactionPage: Sendable, Equatable {
    let transactions: [Transaction]
    /// Opaque token for the next page. `nil` means there are no more pages.
    let nextCursor: String?

    var hasMore: Bool { nextCursor != nil }
}
