//
//  PureLogicEdgeTests.swift
//  Scotiabank Transactions SwiftUI + UIKIT Tests
//
//  Edge cases for the pure helpers that the happy-path suite leaves open, plus the
//  two correctness fixes: strict date parsing (no silent roll-over) and a single
//  minus sign on debits.
//

import Foundation
import Testing
@testable import Scotiabank_Transactions_SwiftUI___UIKIT

// MARK: - Date parsing (strict)

@Suite("Date parsing edge cases")
struct DateParsingEdgeTests {

    @Test("Parses a wire date at UTC midnight, locale/timezone-stable")
    func parsesUTCMidnight() throws {
        let date = try #require(TransactionDateFormatter.date(from: "2026-05-29"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(parts.year == 2026)
        #expect(parts.month == 5)
        #expect(parts.day == 29)
        #expect(parts.hour == 0)
        #expect(parts.minute == 0)
    }

    @Test("Out-of-range dates return nil instead of rolling over")
    func strictParsing() {
        #expect(TransactionDateFormatter.date(from: "2021-13-45") == nil)   // month 13, day 45
        #expect(TransactionDateFormatter.date(from: "2021-02-30") == nil)   // Feb 30
    }

    @Test("An out-of-range date falls back to the raw header string")
    func headerFallback() {
        #expect(TransactionDateFormatter.headerString(from: "2021-13-45") == "2021-13-45")
    }
}

// MARK: - Currency formatting (edges + single sign)

@Suite("Currency formatting edge cases")
struct CurrencyEdgeTests {

    @Test("Zero formats with two decimals")
    func zero() {
        #expect(CurrencyFormatter.string(from: Amount(value: 0, currency: "CAD")) == "$0.00")
    }

    @Test("A negative credit amount is signed exactly once (no double minus)")
    func negativeCreditSingleMinus() {
        let negative = Amount(value: -50, currency: "CAD")
        #expect(CurrencyFormatter.signedString(from: negative, type: .credit) == "-$50.00")
        // A negative value on a debit shows no sign (charges are never signed).
        #expect(CurrencyFormatter.signedString(from: negative, type: .debit) == "$50.00")
    }

    @Test("Unknown-type amounts are unsigned")
    func unknownUnsigned() {
        #expect(CurrencyFormatter.signedString(from: Amount(value: 50, currency: "CAD"),
                                               type: .unknown) == "$50.00")
    }
}

// MARK: - Grouping (ordering + append branches)

@Suite("Grouping edge cases")
struct GroupingEdgeTests {

    @Test("Unparseable dates are grouped after all parseable ones")
    func unparseableSortAfterParseable() {
        let txns = [
            Transaction.sample(key: "new", postedDate: "2021-05-31"),
            Transaction.sample(key: "bad", postedDate: "not-a-date"),
            Transaction.sample(key: "old", postedDate: "2021-01-01"),
        ]
        let sections = TransactionGrouping.group(txns)
        #expect(sections.map(\.id) == ["2021-05-31", "2021-01-01", "not-a-date"])
    }

    @Test("Appending a new day extends the tail without merging")
    func appendNewDayNoMerge() {
        let base = TransactionGrouping.group([Transaction.sample(key: "a", postedDate: "2021-05-31")])
        let result = TransactionGrouping.append(
            [Transaction.sample(key: "b", postedDate: "2021-05-30")], to: base
        )
        #expect(result.map(\.id) == ["2021-05-31", "2021-05-30"])
        #expect(result.last?.transactions.map(\.key) == ["b"])
    }

    @Test("Appending onto an empty base is the same as grouping from scratch")
    func appendOntoEmptyBase() {
        let rows = [
            Transaction.sample(key: "a", postedDate: "2021-05-31"),
            Transaction.sample(key: "b", postedDate: "2021-05-30"),
        ]
        #expect(TransactionGrouping.append(rows, to: []) == TransactionGrouping.group(rows))
    }
}
