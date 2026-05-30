//
//  ConcurrencyAndServiceEdgeTests.swift
//  Scotiabank Transactions SwiftUI + UIKIT Tests
//
//  The harder guarantees this architecture was built to provide, which the happy-
//  path suite doesn't reach: view-model reentrancy/staleness, pagination dedup,
//  partial-failure resilience, the deep-link lookup, and the service's cursor/
//  decoding edge cases. Driven by `GatedMockService` so they're deterministic.
//  The deep-link lookup pages through history with `fetchTransactions`.
//

import Foundation
import Testing
@testable import Scotiabank_Transactions_SwiftUI___UIKIT

@MainActor
private func flatCount(_ state: TransactionListViewModel.State) -> Int {
    guard case let .loaded(sections) = state else { return 0 }
    return sections.reduce(0) { $0 + $1.transactions.count }
}

@MainActor
private func flatKeys(_ state: TransactionListViewModel.State) -> [String] {
    guard case let .loaded(sections) = state else { return [] }
    return sections.flatMap { $0.transactions.map(\.key) }
}

// MARK: - View model: concurrency & resilience

@MainActor
@Suite("View model concurrency & resilience")
struct ViewModelConcurrencyTests {

    @Test("A stale in-flight first load does not clobber a fresh reload")
    func staleLoadDoesNotClobber() async {
        let stale = [Transaction.sample(key: "stale0", postedDate: "2021-01-01"),
                     Transaction.sample(key: "stale1", postedDate: "2021-01-02")]
        let fresh = makeSeq(2, prefix: "fresh")
        let mock = GatedMockService(all: fresh,
                                    gatedFetchOrdinals: [1],
                                    fetchOverrides: [1: stale])
        let vm = TransactionListViewModel(service: mock, pageSize: 5)

        // First load parks inside the gated fetch #1.
        let first = Task { await vm.loadFirstPage() }
        await mock.awaitArrival(ofFetch: 1)

        // A fresh reload supersedes it (generation bumps); fetch #2 returns `fresh`.
        await vm.loadFirstPage()
        #expect(flatKeys(vm.state) == ["fresh0", "fresh1"])

        // Releasing the stale fetch must NOT overwrite the fresh state.
        await mock.release(fetch: 1)
        await first.value
        #expect(flatKeys(vm.state) == ["fresh0", "fresh1"])
        #expect(flatCount(vm.state) == 2)
    }

    @Test("Overlapping next-page requests collapse into a single fetch")
    func overlapCollapsesToOneFetch() async {
        let mock = GatedMockService(all: makeSeq(5))
        let vm = TransactionListViewModel(service: mock, pageSize: 2)
        await vm.loadFirstPage()                 // fetch #1 → 2 rows
        #expect(flatCount(vm.state) == 2)

        async let a: Void = vm.loadNextPageIfNeeded()
        async let b: Void = vm.loadNextPageIfNeeded()
        _ = await (a, b)

        #expect(flatCount(vm.state) == 4)        // exactly one more page paged in
        #expect(await mock.fetchCount == 2)      // first page + one (not two) next-page fetch
    }

    @Test("A page failing mid-scroll keeps the rows already shown")
    func partialFailureKeepsLoaded() async {
        let mock = GatedMockService(all: makeSeq(5), failFetchOnCall: 3)
        let vm = TransactionListViewModel(service: mock, pageSize: 2)
        await vm.loadFirstPage()                 // 2
        await vm.loadNextPageIfNeeded()          // 4
        await vm.loadNextPageIfNeeded()          // fetch #3 throws

        guard case .loaded = vm.state else {
            Issue.record("Expected .loaded to be preserved, got \(vm.state)")
            return
        }
        #expect(flatCount(vm.state) == 4)
    }

    @Test("After a failed page the feed can resume and complete")
    func recoversAfterFailedPage() async {
        let mock = GatedMockService(all: makeSeq(5), failFetchOnCall: 3)
        let vm = TransactionListViewModel(service: mock, pageSize: 2)
        await vm.loadFirstPage()                 // 2
        await vm.loadNextPageIfNeeded()          // 4
        await vm.loadNextPageIfNeeded()          // fetch #3 throws → still 4
        #expect(flatCount(vm.state) == 4)

        await vm.loadNextPageIfNeeded()          // fetch #4 succeeds → 5
        #expect(flatCount(vm.state) == 5)
        #expect(!vm.hasMorePages)
        #expect(Set(flatKeys(vm.state)).count == 5)
    }

    @Test("transaction(withKey:) resolves a paged-in row without a scan")
    func withKeyLocal() async {
        let mock = GatedMockService(all: makeSeq(5))
        let vm = TransactionListViewModel(service: mock, pageSize: 2)
        await vm.loadFirstPage()                 // k0, k1 paged in (fetch #1)
        let found = await vm.transaction(withKey: "k0")
        #expect(found?.key == "k0")
        #expect(await mock.fetchCount == 1)      // resolved locally, no extra fetch
    }

    @Test("transaction(withKey:) scans beyond the loaded pages")
    func withKeyScan() async {
        let mock = GatedMockService(all: makeSeq(5))
        let vm = TransactionListViewModel(service: mock, pageSize: 2)
        await vm.loadFirstPage()                 // only k0, k1 paged in (fetch #1)
        let found = await vm.transaction(withKey: "k4")
        #expect(found?.key == "k4")
        #expect(await mock.fetchCount > 1)       // needed the full-history scan
    }

    @Test("transaction(withKey:) returns nil for an unknown key")
    func withKeyNotFound() async {
        let mock = GatedMockService(all: makeSeq(5))
        let vm = TransactionListViewModel(service: mock, pageSize: 2)
        await vm.loadFirstPage()
        #expect(await vm.transaction(withKey: "does-not-exist") == nil)
    }

    @Test("transaction(withKey:) returns nil when the scan errors")
    func withKeyThrows() async {
        let mock = GatedMockService(all: makeSeq(5), failFetchOnCall: 1)
        let vm = TransactionListViewModel(service: mock, pageSize: 2)
        // No first page → the key isn't local, so a (failing) scan is required.
        #expect(await vm.transaction(withKey: "k4") == nil)
    }
}

// MARK: - Local service: cursor edge cases

@Suite("Local service edge cases")
struct LocalServiceEdgeTests {

    private func bundledFull() throws -> [Transaction] {
        LocalTransactionService.sortedNewestFirst(
            try LocalTransactionService.loadTransactions(bundle: .main, fileName: "transaction-list")
        )
    }

    @Test("Paging past the final cursor yields an empty terminal page")
    func pastEnd() async throws {
        let service = LocalTransactionService()
        let lastKey = try #require(try bundledFull().last?.key)
        let page = try await service.fetchTransactions(after: lastKey, limit: 10)
        #expect(page.transactions.isEmpty)
        #expect(page.nextCursor == nil)
    }

    @Test("A non-positive limit returns an empty page")
    func zeroLimit() async throws {
        let page = try await LocalTransactionService().fetchTransactions(after: nil, limit: 0)
        #expect(page.transactions.isEmpty)
        #expect(page.nextCursor == nil)
    }

    @Test("An unknown cursor restarts at the top")
    func unknownCursorRestarts() async throws {
        let service = LocalTransactionService()

        let firstPage = try await service.fetchTransactions(after: nil, limit: 3)
        let restart = try await service.fetchTransactions(after: "no-such-key", limit: 3)
        #expect(restart.transactions.map(\.key) == firstPage.transactions.map(\.key))
    }

    @Test("A single page covering the whole history has no next cursor")
    func exactlyFullPage() async throws {
        let full = try bundledFull()
        let page = try await LocalTransactionService().fetchTransactions(after: nil, limit: full.count)
        #expect(page.transactions.count == full.count)
        #expect(page.nextCursor == nil)
    }
}

// MARK: - Decoding error paths

@Suite("Decoding error paths")
struct DecodingErrorTests {

    @Test("Malformed bundled JSON is surfaced as decodingFailed")
    func decodingFailed() {
        #expect(throws: TransactionServiceError.decodingFailed) {
            try LocalTransactionService.loadTransactions(bundle: .testBundle, fileName: "bad")
        }
    }

    @Test("A valid bundled resource decodes")
    func validResource() throws {
        let txns = try LocalTransactionService.loadTransactions(bundle: .testBundle, fileName: "valid")
        #expect(txns.count == 2)
        #expect(txns.first?.key == "valid-1")
    }

    @Test("A row missing a required field fails decoding")
    func missingRequiredField() {
        // No `merchant_name`.
        let json = """
        { "transactions": [{ "key": "k", "transaction_type": "CREDIT",
          "amount": { "value": 1, "currency": "CAD" }, "posted_date": "2021-01-01",
          "from_account": "A", "from_card_number": "1234" }] }
        """
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(TransactionListResponse.self, from: Data(json.utf8))
        }
    }

    @Test("An empty transactions array decodes to no rows")
    func emptyArray() throws {
        let decoded = try JSONDecoder().decode(
            TransactionListResponse.self,
            from: Data(#"{ "transactions": [] }"#.utf8)
        )
        #expect(decoded.transactions.isEmpty)
    }
}
