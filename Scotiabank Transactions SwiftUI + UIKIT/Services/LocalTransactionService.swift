//
//  LocalTransactionService.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  Concrete `TransactionServicing` backed by the bundled `transaction-list.json`,
//  but deliberately behaving like a paginated network API: it decodes the file
//  once, sorts it newest-first, and serves it back one cursor-delimited page at a
//  time. Swapping in a real `RemoteTransactionService` (same protocol) would
//  require no changes elsewhere.
//
//  An `actor` so the one-time decode/sort cache is shared safely across calls.
//

import Foundation

actor LocalTransactionService: TransactionServicing {

    private let bundle: Bundle
    private let fileName: String
    /// Simulates per-page network latency so the loading footer is visible while
    /// the next page streams in. Set to 0 in tests for deterministic completion.
    private let artificialDelay: Duration

    /// Decoded + sorted history, computed once on first access.
    private var cache: [Transaction]?
    /// `key -> index` into `cache`, built once with it, so resolving a paging
    /// cursor is O(1) instead of a linear scan per page.
    private var indexByKey: [String: Int] = [:]

    init(bundle: Bundle = .main,
         fileName: String = "transaction-list",
         artificialDelay: Duration = .zero) {
        self.bundle = bundle
        self.fileName = fileName
        self.artificialDelay = artificialDelay
    }

    // MARK: - TransactionServicing

    func fetchTransactions(after cursor: String?, limit: Int) async throws -> TransactionPage {
        let all = try loadCached()
        if artificialDelay > .zero {
            try await Task.sleep(for: artificialDelay)
        }
        // Resolve the cursor (the key of the last item the caller already has) to a
        // start index via the precomputed map — O(1). An unknown/absent cursor
        // starts at the beginning, so the page stays valid even if data shifted.
        let start = cursor.flatMap { indexByKey[$0] }.map { $0 + 1 } ?? 0
        return Self.slice(all, from: start, limit: limit)
    }

    // MARK: - Caching

    /// Decodes and sorts once, then reuses the result (plus its key→index map).
    private func loadCached() throws -> [Transaction] {
        if let cache { return cache }
        let decoded = try Self.loadTransactions(bundle: bundle, fileName: fileName)
        let sorted = Self.sortedNewestFirst(decoded)
        cache = sorted
        indexByKey = Dictionary(
            sorted.enumerated().map { ($1.key, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return sorted
    }

    /// Returns the cursor-delimited page of `items` starting at `start`, with a
    /// `nextCursor` (the last row's key) only when more rows remain.
    private static func slice(_ items: [Transaction], from start: Int, limit: Int) -> TransactionPage {
        guard start < items.count, limit > 0 else {
            return TransactionPage(transactions: [], nextCursor: nil)
        }
        let end = min(start + limit, items.count)
        let page = Array(items[start..<end])
        return TransactionPage(transactions: page, nextCursor: end < items.count ? page.last?.key : nil)
    }

    // MARK: - Helpers (also used directly by unit tests)

    /// Synchronous decode of the bundled JSON. `nonisolated` so it's callable from
    /// the actor's cache path and directly from unit tests.
    nonisolated static func loadTransactions(bundle: Bundle, fileName: String) throws -> [Transaction] {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw TransactionServiceError.fileNotFound
        }
        do {
            let data = try Data(contentsOf: url)
            let response = try JSONDecoder().decode(TransactionListResponse.self, from: data)
            return response.transactions
        } catch {
            throw TransactionServiceError.decodingFailed
        }
    }

    /// Stable newest-first ordering: by posted date descending, ties broken by the
    /// original order so paging is deterministic. `nonisolated` (pure helper).
    nonisolated static func sortedNewestFirst(_ transactions: [Transaction]) -> [Transaction] {
        transactions.enumerated()
            .sorted { lhs, rhs in
                let l = TransactionDateFormatter.date(from: lhs.element.postedDate) ?? .distantPast
                let r = TransactionDateFormatter.date(from: rhs.element.postedDate) ?? .distantPast
                if l != r { return l > r }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
