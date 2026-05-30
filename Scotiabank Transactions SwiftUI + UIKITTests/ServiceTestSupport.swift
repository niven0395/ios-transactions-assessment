//
//  ServiceTestSupport.swift
//  Scotiabank Transactions SwiftUI + UIKIT Tests
//
//  Shared test infrastructure for the harder view-model and service tests:
//   • `GatedMockService` — a configurable `TransactionServicing` that counts
//     fetches, can fail a specific call, can gate (suspend) a fetch until the test
//     releases it, and can return different data per call. This is what makes the
//     reentrancy/dedup/partial-failure behaviours testable deterministically (no
//     wall-clock sleeps).
//   • `TestBundleMarker` / `Bundle.testBundle` — reaches resources bundled into the
//     test target (Swift Testing has no XCTestCase, and `Bundle.main` is the app).
//

import Foundation
@testable import Scotiabank_Transactions_SwiftUI___UIKIT

/// A controllable `TransactionServicing` double. An `actor` so its counters and
/// gates are race-free even when the `@MainActor` view model drives two awaited
/// calls that overlap.
actor GatedMockService: TransactionServicing {

    /// Backing history, treated as already newest-first.
    private let all: [Transaction]
    /// Overrides the data returned for a specific (1-based) fetch ordinal — used to
    /// give a stale, gated first load *different* rows from the fresh reload that
    /// supersedes it, so the staleness guard's effect is observable.
    private let fetchOverrides: [Int: [Transaction]]
    /// Fetch ordinals (1-based) that should throw.
    private let failFetchOnCall: Int?
    /// Fetch ordinals that must suspend until the test calls `release`.
    private let gatedFetchOrdinals: Set<Int>

    private(set) var fetchCount = 0

    private var gateWaiters: [Int: CheckedContinuation<Void, Never>] = [:]
    private var arrivalWaiters: [Int: CheckedContinuation<Void, Never>] = [:]

    init(all: [Transaction] = [],
         failFetchOnCall: Int? = nil,
         gatedFetchOrdinals: Set<Int> = [],
         fetchOverrides: [Int: [Transaction]] = [:]) {
        self.all = all
        self.failFetchOnCall = failFetchOnCall
        self.gatedFetchOrdinals = gatedFetchOrdinals
        self.fetchOverrides = fetchOverrides
    }

    // MARK: TransactionServicing

    func fetchTransactions(after cursor: String?, limit: Int) async throws -> TransactionPage {
        fetchCount += 1
        let ordinal = fetchCount
        await gateIfNeeded(ordinal)
        if failFetchOnCall == ordinal { throw MockError() }
        let data = fetchOverrides[ordinal] ?? all
        return Self.slice(data, after: cursor, limit: limit)
    }

    // MARK: Test controls

    /// Suspends until the given fetch ordinal has reached its gate, so the test can
    /// act while that call is parked mid-flight.
    func awaitArrival(ofFetch ordinal: Int) async {
        if gateWaiters[ordinal] != nil { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            arrivalWaiters[ordinal] = cont
        }
    }

    /// Releases a gated fetch so it can complete.
    func release(fetch ordinal: Int) {
        gateWaiters[ordinal]?.resume()
        gateWaiters[ordinal] = nil
    }

    // MARK: Internals

    private func gateIfNeeded(_ ordinal: Int) async {
        guard gatedFetchOrdinals.contains(ordinal) else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            gateWaiters[ordinal] = cont
            arrivalWaiters[ordinal]?.resume()      // wake anyone waiting for arrival
            arrivalWaiters[ordinal] = nil
        }
    }

    /// Cursor-delimited slice, byte-equivalent to `LocalTransactionService.slice`:
    /// an unknown/absent cursor restarts at the top; `nextCursor` is set only when
    /// more rows remain.
    private static func slice(_ items: [Transaction], after cursor: String?, limit: Int) -> TransactionPage {
        let start: Int
        if let cursor, let index = items.firstIndex(where: { $0.key == cursor }) {
            start = index + 1
        } else {
            start = 0
        }
        guard start < items.count, limit > 0 else {
            return TransactionPage(transactions: [], nextCursor: nil)
        }
        let end = min(start + limit, items.count)
        let page = Array(items[start..<end])
        return TransactionPage(transactions: page, nextCursor: end < items.count ? page.last?.key : nil)
    }
}

struct MockError: Error {}

/// Builds `count` distinct transactions, newest-first by date (`i = 0` is newest).
func makeSeq(_ count: Int, prefix: String = "k") -> [Transaction] {
    (0..<count).map { i in
        Transaction.sample(
            key: "\(prefix)\(i)",
            merchantName: "Merchant \(i)",
            description: "Desc \(i)",
            postedDate: String(format: "2021-05-%02d", max(1, 31 - i))
        )
    }
}

/// Marker type whose bundle is the unit-test bundle, so resource-backed tests can
/// load `valid.json` / `bad.json` that ship inside the test target.
final class TestBundleMarker {}

extension Bundle {
    static let testBundle = Bundle(for: TestBundleMarker.self)
}
