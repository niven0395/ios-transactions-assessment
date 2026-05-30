//
//  TooltipContent.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  The ToolTip's copy and its expand/collapse rule from the brief, kept as pure,
//  view-free logic — exactly like `TransactionStatus` — so the rule is unit-tested
//  directly. The UIKit `TooltipCardView` renders it.
//

import Foundation

nonisolated enum TooltipContent {

    /// Always-visible message.
    static let baseMessage = "Transactions are processed Monday to Friday (excluding holidays)."
    /// Revealed when expanded.
    static let expandedMessage = "Transactions made before 8:30 pm ET Monday to Friday (excluding holidays) will show up in your account the same day."

    /// The message shown for a given expansion state — base alone when collapsed,
    /// base + expanded when open.
    static func message(isExpanded: Bool) -> String {
        isExpanded ? "\(baseMessage) \(expandedMessage)" : baseMessage
    }

    /// The toggle's label for a given state.
    static func toggleLabel(isExpanded: Bool) -> String {
        isExpanded ? "Show less" : "Show more"
    }
}
