//
//  TransactionDateFormatter.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  Parses the API's "yyyy-MM-dd" posted dates and formats section headers like
//  "FRI, MAY 29, 2026" to match the live app's grouped list.
//

import Foundation

/// `nonisolated` so date parsing is usable from the `LocalTransactionService`
/// actor (e.g. when sorting) as well as the main actor.
nonisolated enum TransactionDateFormatter {

    /// Parses the wire format. Uses a fixed POSIX locale and UTC so parsing is
    /// stable regardless of the device's locale/time zone.
    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        // Strict parsing: a malformed date like "2021-13-45" returns nil (and so
        // routes to the raw-string fallback) instead of silently rolling over into
        // a wrong-but-valid day.
        formatter.isLenient = false
        return formatter
    }()

    /// Formats a header date, e.g. "FRI, MAY 29, 2026".
    private static let headerFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "EEE, MMM d, yyyy"
        return formatter
    }()

    static func date(from string: String) -> Date? {
        parser.date(from: string)
    }

    /// Returns the uppercased header string for a parsed date, falling back to
    /// the raw value if it can't be parsed (so nothing is ever dropped).
    static func headerString(from postedDate: String) -> String {
        guard let date = parser.date(from: postedDate) else { return postedDate }
        return headerFormatter.string(from: date).uppercased()
    }
}
