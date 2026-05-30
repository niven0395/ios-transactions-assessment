//
//  CurrencyFormatter.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  Formats `Amount` values for display. Kept separate from the model and view
//  models so the rules live in one place and are unit-tested directly.
//

import Foundation

enum CurrencyFormatter {

    /// `$1,234.50`-style currency style. Uses the modern `Decimal.FormatStyle`
    /// (not `NumberFormatter`), fixed to `en_CA` so output is deterministic for the
    /// UI, VoiceOver, and tests. en_CA renders CAD with the bare `$` symbol, exactly
    /// matching the designs ("$200.20").
    private static let style = Decimal.FormatStyle.Currency(code: "CAD",
                                                            locale: Locale(identifier: "en_CA"))

    /// Returns e.g. "$200.20".
    ///
    /// The currency format style wraps the output in invisible Unicode bidi
    /// "format" characters (e.g. isolates around the symbol). We strip them so the
    /// result is deterministic and clean for the UI, VoiceOver, and tests; the
    /// app is English/LTR so removing them has no visual effect.
    static func string(from amount: Amount) -> String {
        amount.value.formatted(style).unicodeScalars
            .filter { $0.properties.generalCategory != .format }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
    }

    /// Signed variant for the list screen. This is a credit-card account, so the
    /// amount reflects the balance owing: a CREDIT is a payment toward the card
    /// (lowers the balance) and shows a leading "-" (e.g. "-$2,961.91"), while a
    /// DEBIT is a charge (raises the balance) and shows no sign (e.g. "$200.20").
    /// Matches the live Scotiabank credit-card app.
    static func signedString(from amount: Amount, type: TransactionType) -> String {
        // Format the magnitude so the sign is applied exactly once: a credit whose
        // value is already negative must read "-$50.00", never "--$50.00".
        let base = string(from: Amount(value: abs(amount.value), currency: amount.currency))
        return type == .credit ? "-\(base)" : base
    }
}
