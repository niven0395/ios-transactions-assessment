//
//  TransactionServicing.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  Abstraction over the source of transactions. The app talks to this protocol
//  only, so the concrete source (the bundled JSON today, a real REST API
//  tomorrow) can be swapped without touching the view model or views.
//
//  The API is deliberately shaped like a paginated banking backend: callers
//  *page* through history with an opaque cursor. Even though the data is a local
//  file, treating it this way means a real networked source can drop straight in.
//  Tests inject a mock conforming here.
//

import Foundation

enum TransactionServiceError: Error, Equatable {
    case fileNotFound
    case decodingFailed
}

protocol TransactionServicing: Sendable {
    /// Returns one page of transactions, newest first.
    ///
    /// - Parameters:
    ///   - cursor: the `nextCursor` from the previous page, or `nil` for the
    ///     first page.
    ///   - limit: maximum number of transactions to return.
    func fetchTransactions(after cursor: String?, limit: Int) async throws -> TransactionPage
}
