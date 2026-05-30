//
//  TransactionListView.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  The scrolling transaction list, built with a native SwiftUI `List`. It owns no
//  business logic — it's handed already-grouped sections plus a loading flag,
//  reports row taps, and asks for the next page as the user nears the end, all
//  through closures. The detail screen it presents is UIKit (see
//  `TransactionDetailRepresentable`).
//

import SwiftUI

struct TransactionListView: View {

    let sections: [TransactionSection]
    let isLoadingNextPage: Bool
    let nextPageFailed: Bool
    let onSelect: (Transaction) -> Void
    let onReachedEnd: () -> Void
    let onRetry: () -> Void

    /// Start fetching the next page this many rows before the very last one, so
    /// new data is on its way before the user hits the bottom.
    private static let prefetchDistance = 5

    /// The single row whose appearance should request the next page: the one
    /// `prefetchDistance` from the end of the list. Only this sentinel row fires,
    /// so overlapping triggers don't pile up.
    ///
    /// Found by walking sections from the end and counting rows, so it costs
    /// O(prefetchDistance) per render instead of flattening the whole (growing)
    /// feed on every `body` evaluation.
    private var triggerKey: Transaction.ID? {
        var remaining = Self.prefetchDistance
        for section in sections.reversed() {
            let count = section.transactions.count
            if remaining <= count {
                return section.transactions[count - remaining].id
            }
            remaining -= count
        }
        // Fewer than `prefetchDistance` rows total: trigger on the very first row.
        return sections.first?.transactions.first?.id
    }

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.transactions) { transaction in
                        Button {
                            onSelect(transaction)
                        } label: {
                            TransactionRow(transaction: transaction)
                                // Fill the row and define an explicit hit shape so a
                                // tap anywhere on the row triggers selection.
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        // Stable handle so UI tests can tap a real transaction row
                        // (not a section-header cell).
                        .accessibilityIdentifier("transactionRow")
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(
                            top: Theme.Spacing.m, leading: Theme.Spacing.m,
                            bottom: Theme.Spacing.m, trailing: Theme.Spacing.m
                        ))
                        .listRowBackground(Color(.systemBackground))
                        .onAppear {
                            if transaction.id == triggerKey { onReachedEnd() }
                        }
                    }
                } header: {
                    TransactionSectionHeader(title: section.title)
                        // Larger top gap + 16pt leading to line the date and its
                        // divider up with the rows below.
                        .listRowInsets(.init(
                            top: Theme.Spacing.l, leading: Theme.Spacing.m,
                            bottom: 0, trailing: Theme.Spacing.m
                        ))
                        .listRowBackground(Color(.systemBackground))
                }
                .textCase(nil)                  // keep "FRI, MAY 29, 2026" verbatim
                .listSectionSeparator(.hidden)
            }

            if isLoadingNextPage {
                LoadingFooterRow()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemBackground))
            } else if nextPageFailed {
                LoadingErrorFooterRow(onRetry: onRetry)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemBackground))
            }
        }
        .listStyle(.plain)                      // sticky date headers + flat look
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
    }
}

/// One transaction row: merchant/description on the left, the signed amount and a
/// chevron on the right.
private struct TransactionRow: View {

    let transaction: Transaction

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(transaction.primaryText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let secondary = transaction.secondaryText {
                    Text(secondary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Theme.Spacing.s)

            Text(CurrencyFormatter.signedString(from: transaction.amount,
                                                type: transaction.transactionType))
                .font(.headline)
                // CREDIT is green; DEBIT uses the primary label colour.
                .foregroundStyle(transaction.transactionType == .credit
                                 ? Theme.Palette.credit : .primary)
                .lineLimit(1)
                .layoutPriority(1)              // never truncate the amount

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)      // decorative
        }
        .frame(minHeight: Theme.Spacing.minTapTarget)   // HIG minimum row height
        // One coherent VoiceOver phrase per row, e.g.
        // "Bill payment, Mb - Cash Advance To - 1785, debit 200 dollars".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityPhrase)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityPhrase: String {
        let typeWord: String
        switch transaction.transactionType {
        case .credit: typeWord = "credit"
        case .debit: typeWord = "debit"
        case .unknown: typeWord = "transaction"
        }
        let detailPhrase = transaction.secondaryText.map { ", \($0)" } ?? ""
        return "\(transaction.primaryText)\(detailPhrase), "
            + "\(typeWord) \(CurrencyFormatter.string(from: transaction.amount))"
    }
}

/// A day's date header (e.g. "FRI, MAY 29, 2026") with the hairline divider seen
/// in the live app.
private struct TransactionSectionHeader: View {

    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Footer spinner shown at the bottom of the list while the next page streams in.
private struct LoadingFooterRow: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, Theme.Spacing.m)
        .accessibilityHidden(true)
    }
}

/// Footer shown when a next-page fetch fails: a short message and a retry button,
/// so a transient error doesn't silently strand the user with no more rows.
private struct LoadingErrorFooterRow: View {

    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text("Couldn't load more transactions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: onRetry)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.m)
    }
}

/// Placeholder rows shown while the first page loads. Reuses the real row layout
/// under `.redacted(.placeholder)` so the swap to live data has no layout jump.
/// Non-interactive and hidden from VoiceOver — it's purely visual scaffolding.
struct TransactionListSkeleton: View {

    // A handful of varied-length samples so the redaction bars aren't uniform.
    private static let placeholders: [Transaction] = [
        .sample(key: "s0", merchantName: "Payment-thank You", description: "Scotiabank"),
        .sample(key: "s1", type: .debit, merchantName: "Cash Advance Fee", description: "Cash advance"),
        .sample(key: "s2", merchantName: "Grocery Store Purchase", description: "Debit"),
        .sample(key: "s3", type: .debit, merchantName: "Restaurant", description: nil),
        .sample(key: "s4", merchantName: "Online Subscription", description: "Monthly"),
        .sample(key: "s5", type: .debit, merchantName: "Transfer Out", description: "To savings"),
        .sample(key: "s6", merchantName: "Refund", description: nil),
        .sample(key: "s7", type: .debit, merchantName: "Utility Bill", description: "Hydro")
    ]

    var body: some View {
        List(Self.placeholders) { transaction in
            TransactionRow(transaction: transaction)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowSeparator(.hidden)
                .listRowInsets(.init(
                    top: Theme.Spacing.m, leading: Theme.Spacing.m,
                    bottom: Theme.Spacing.m, trailing: Theme.Spacing.m
                ))
                .listRowBackground(Color(.systemBackground))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    TransactionListView(
        sections: TransactionGrouping.group([.previewCredit, .previewDebit]),
        isLoadingNextPage: false,
        nextPageFailed: false,
        onSelect: { _ in },
        onReachedEnd: {},
        onRetry: {}
    )
}

#Preview("Skeleton") {
    TransactionListSkeleton()
}
