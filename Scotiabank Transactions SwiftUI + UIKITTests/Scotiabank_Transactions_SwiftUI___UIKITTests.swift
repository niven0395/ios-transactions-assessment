//
//  Scotiabank_Transactions_SwiftUI___UIKITTests.swift
//  Scotiabank Transactions SwiftUI + UIKIT Tests
//
//  Unit tests for the pure, testable core: model decoding, formatting, date
//  grouping, cursor pagination (service + view model). Uses the Swift Testing
//  framework (`@Test`/`#expect`). UI is verified by running the app.
//

import Foundation
import Testing
@testable import Scotiabank_Transactions_SwiftUI___UIKIT

// MARK: - Test doubles

/// In-memory `TransactionServicing` that mirrors the real cursor-pagination
/// behaviour over a backing array, so the view model is exercised with no I/O.
/// `all` is treated as already newest-first.
private struct MockTransactionService: TransactionServicing {
    var all: [Transaction] = []
    var shouldFail = false

    func fetchTransactions(after cursor: String?, limit: Int) async throws -> TransactionPage {
        if shouldFail { throw DummyError() }
        let start: Int
        if let cursor, let index = all.firstIndex(where: { $0.key == cursor }) {
            start = index + 1
        } else {
            start = 0
        }
        guard start < all.count, limit > 0 else {
            return TransactionPage(transactions: [], nextCursor: nil)
        }
        let end = min(start + limit, all.count)
        let page = Array(all[start..<end])
        return TransactionPage(transactions: page, nextCursor: end < all.count ? page.last?.key : nil)
    }
}

private struct DummyError: Error {}

/// Builds `count` distinct transactions, newest-first by date.
private func makeTransactions(_ count: Int) -> [Transaction] {
    (0..<count).map { i in
        Transaction.sample(
            key: "k\(i)",
            merchantName: "Merchant \(i)",
            description: "Desc \(i)",
            // Descending dates: i=0 newest.
            postedDate: String(format: "2021-05-%02d", max(1, 31 - i))
        )
    }
}

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

// MARK: - Decoding

@Suite("Transaction decoding")
struct TransactionDecodingTests {

    private func decode(_ json: String) throws -> [Transaction] {
        try JSONDecoder().decode(TransactionListResponse.self, from: Data(json.utf8)).transactions
    }

    @Test("Decodes all fields of a well-formed transaction")
    func decodesFields() throws {
        let json = """
        { "transactions": [{
            "key": "abc=", "transaction_type": "DEBIT",
            "merchant_name": "Cash Advance Fee", "description": "Cash advance",
            "amount": { "value": 200.20, "currency": "CAD" },
            "posted_date": "2021-05-31",
            "from_account": "Momentum Regular Visa", "from_card_number": "4537350001688012"
        }] }
        """
        let txn = try #require(try decode(json).first)
        #expect(txn.key == "abc=")
        #expect(txn.transactionType == .debit)
        #expect(txn.merchantName == "Cash Advance Fee")
        #expect(txn.description == "Cash advance")
        #expect(txn.amount.value == 200.20)
        #expect(txn.cardSuffix == "8012")
    }

    @Test("Unknown transaction_type decodes to .unknown instead of failing")
    func unknownTypeFallsBack() throws {
        let json = """
        { "transactions": [{
            "key": "k", "transaction_type": "REFUND", "merchant_name": "M",
            "amount": { "value": 1, "currency": "CAD" }, "posted_date": "2021-01-01",
            "from_account": "A", "from_card_number": "0000"
        }] }
        """
        #expect(try #require(try decode(json).first).transactionType == .unknown)
    }

    @Test("Missing description is nil; primaryText falls back to merchant name and there is no secondary line")
    func missingDescription() throws {
        let json = """
        { "transactions": [{
            "key": "k", "transaction_type": "CREDIT", "merchant_name": "Payroll Deposit",
            "amount": { "value": 1, "currency": "CAD" }, "posted_date": "2021-01-01",
            "from_account": "A", "from_card_number": "1234"
        }] }
        """
        let txn = try #require(try decode(json).first)
        #expect(txn.description == nil)
        #expect(txn.primaryText == "Payroll Deposit")
        #expect(txn.secondaryText == nil)
    }

    @Test("With a description on a non-derived merchant, primaryText is the description and secondaryText is the merchant name")
    func presentDescription() throws {
        let json = """
        { "transactions": [{
            "key": "k", "transaction_type": "DEBIT",
            "merchant_name": "Some Store", "description": "Bill payment",
            "amount": { "value": 200.20, "currency": "CAD" }, "posted_date": "2021-01-01",
            "from_account": "A", "from_card_number": "1234"
        }] }
        """
        let txn = try #require(try decode(json).first)
        #expect(txn.primaryText == "Bill payment")
        #expect(txn.secondaryText == "Some Store")
    }

    @Test("A 'Cash Advance To' debit derives the title 'Cash advance', overriding the ambiguous description")
    func derivesCashAdvanceTitle() {
        let txn = Transaction.sample(
            type: .debit,
            merchantName: "Mb - Cash Advance To - 405922607182",
            description: "Cash advance payment"
        )
        #expect(txn.primaryText == "Cash advance")
        #expect(txn.secondaryText == "Mb - Cash Advance To - 405922607182")
    }

    @Test("A 'Card/loc Pay' credit derives the title 'Payment', overriding the ambiguous description")
    func derivesPaymentTitle() {
        let txn = Transaction.sample(
            type: .credit,
            merchantName: "Mb-credit Card/loc Pay. From - 405922607182",
            description: "Cash advance payment"
        )
        #expect(txn.primaryText == "Payment")
        #expect(txn.secondaryText == "Mb-credit Card/loc Pay. From - 405922607182")
    }

    @Test("A 'Scotiabank Transit' payment derives the title 'Payment from Branch'")
    func derivesPaymentFromBranchTitle() {
        let txn = Transaction.sample(
            type: .credit,
            merchantName: "Payment-thank You Scotiabank Transit 40592 Markham On",
            description: "Payment (Scotiabank)"
        )
        #expect(txn.primaryText == "Payment from Branch")
        #expect(txn.secondaryText == "Payment-thank You Scotiabank Transit 40592 Markham On")
    }

    @Test("A 'Cash Advance Fee' row shows only the merchant name, with no subtitle, ignoring any description")
    func cashAdvanceFeeHasNoSubtitle() {
        let txn = Transaction.sample(
            type: .debit,
            merchantName: "Cash Advance Fee",
            description: "Cash advance payment"
        )
        #expect(txn.primaryText == "Cash Advance Fee")
        #expect(txn.secondaryText == nil)
    }
}

// MARK: - Formatting

@Suite("Currency formatting")
struct CurrencyFormatterTests {

    @Test("Formats with symbol and two decimals")
    func basicFormat() {
        #expect(CurrencyFormatter.string(from: Amount(value: 200.2, currency: "CAD")) == "$200.20")
    }

    @Test("Credits (payments) are signed with a leading minus, debits (charges) are not")
    func signedFormat() {
        let amount = Amount(value: 50, currency: "CAD")
        #expect(CurrencyFormatter.signedString(from: amount, type: .credit) == "-$50.00")
        #expect(CurrencyFormatter.signedString(from: amount, type: .debit) == "$50.00")
    }

    @Test("Thousands separators are applied")
    func thousands() {
        #expect(CurrencyFormatter.string(from: Amount(value: 2213.79, currency: "CAD")) == "$2,213.79")
    }
}

@Suite("Date header formatting")
struct DateFormatterTests {

    @Test("Formats a posted date as an uppercased header")
    func header() {
        #expect(TransactionDateFormatter.headerString(from: "2026-05-29") == "FRI, MAY 29, 2026")
    }

    @Test("Unparseable dates fall back to the raw string")
    func fallback() {
        #expect(TransactionDateFormatter.headerString(from: "not-a-date") == "not-a-date")
    }
}

// MARK: - Grouping

@Suite("Transaction grouping")
struct GroupingTests {

    @Test("Groups by day, newest first, preserving in-day order")
    func grouping() {
        let txns = [
            Transaction.sample(key: "a", postedDate: "2021-03-29"),
            Transaction.sample(key: "b", postedDate: "2021-05-31"),
            Transaction.sample(key: "c", postedDate: "2021-03-29"),
        ]
        let sections = TransactionGrouping.group(txns)
        #expect(sections.count == 2)
        #expect(sections[0].id == "2021-05-31")
        #expect(sections[1].transactions.map(\.key) == ["a", "c"])
    }

    @Test("Empty input produces no sections")
    func empty() {
        #expect(TransactionGrouping.group([]).isEmpty)
    }
}

// MARK: - Local service (cursor pagination)

@Suite("Local transaction service")
struct LocalServiceTests {

    @Test("Missing resource throws fileNotFound")
    func fileNotFound() {
        #expect(throws: TransactionServiceError.fileNotFound) {
            try LocalTransactionService.loadTransactions(bundle: .main, fileName: "does-not-exist")
        }
    }

    @Test("Sorts newest-first with a stable tie-break")
    func sorting() {
        let input = [
            Transaction.sample(key: "old", postedDate: "2021-01-01"),
            Transaction.sample(key: "new", postedDate: "2021-12-31"),
            Transaction.sample(key: "mid", postedDate: "2021-06-15"),
        ]
        let sorted = LocalTransactionService.sortedNewestFirst(input)
        #expect(sorted.map(\.key) == ["new", "mid", "old"])
    }

    @Test("Paging with a cursor walks the whole history in order, once")
    func pagination() async throws {
        let service = LocalTransactionService()   // bundled JSON via Bundle.main
        let full = LocalTransactionService.sortedNewestFirst(
            try LocalTransactionService.loadTransactions(bundle: .main, fileName: "transaction-list")
        )
        try #require(full.count > 10)

        var collected: [Transaction] = []
        var cursor: String?
        var pages = 0
        repeat {
            let page = try await service.fetchTransactions(after: cursor, limit: 10)
            collected.append(contentsOf: page.transactions)
            cursor = page.nextCursor
            pages += 1
            #expect(pages < 100)   // guard against an infinite loop
        } while cursor != nil

        #expect(collected.map(\.key) == full.map(\.key))            // same items, same order
        #expect(Set(collected.map(\.key)).count == collected.count) // no duplicates
    }
}

// MARK: - Incremental grouping

@Suite("Incremental grouping (append)")
struct IncrementalGroupingTests {

    @Test("Appending pages incrementally matches a full re-group")
    func matchesFullGroup() {
        // Two days spread across two pages, second page continuing the first day.
        let page1 = [
            Transaction.sample(key: "a", postedDate: "2021-05-31"),
            Transaction.sample(key: "b", postedDate: "2021-05-31"),
        ]
        let page2 = [
            Transaction.sample(key: "c", postedDate: "2021-05-31"),   // same day → merge
            Transaction.sample(key: "d", postedDate: "2021-05-30"),   // new day
        ]
        let incremental = TransactionGrouping.append(
            page2, to: TransactionGrouping.append(page1, to: [])
        )
        let full = TransactionGrouping.group(page1 + page2)
        #expect(incremental == full)
        #expect(incremental.first?.transactions.map(\.key) == ["a", "b", "c"])
        #expect(incremental.last?.transactions.map(\.key) == ["d"])
    }

    @Test("Appending an empty page leaves sections unchanged")
    func emptyPage() {
        let base = TransactionGrouping.group([Transaction.sample(key: "a")])
        #expect(TransactionGrouping.append([], to: base) == base)
    }
}

// MARK: - View model (pagination)

@MainActor
@Suite("Transaction list view model")
struct ViewModelTests {

    @Test("First page loads a page-sized slice with more remaining")
    func firstPage() async {
        let vm = TransactionListViewModel(service: MockTransactionService(all: makeTransactions(5)), pageSize: 2)
        await vm.loadFirstPage()
        #expect(flatCount(vm.state) == 2)
        #expect(vm.hasMorePages)
    }

    @Test("Scrolling pages in the rest, then stops with no duplicates")
    func paging() async {
        let vm = TransactionListViewModel(service: MockTransactionService(all: makeTransactions(5)), pageSize: 2)
        await vm.loadFirstPage()
        await vm.loadNextPageIfNeeded()   // 4
        await vm.loadNextPageIfNeeded()   // 5 (last)
        #expect(flatCount(vm.state) == 5)
        #expect(!vm.hasMorePages)

        await vm.loadNextPageIfNeeded()   // no-op past the end
        #expect(flatCount(vm.state) == 5)
        #expect(Set(flatKeys(vm.state)).count == 5)
    }

    @Test("Empty data yields the empty state")
    func empty() async {
        let vm = TransactionListViewModel(service: MockTransactionService(all: []))
        await vm.loadFirstPage()
        #expect(vm.state == .empty)
    }

    @Test("A failure yields the failed state")
    func failure() async {
        let vm = TransactionListViewModel(service: MockTransactionService(shouldFail: true))
        await vm.loadFirstPage()
        guard case .failed = vm.state else {
            Issue.record("Expected .failed, got \(vm.state)")
            return
        }
    }
}
