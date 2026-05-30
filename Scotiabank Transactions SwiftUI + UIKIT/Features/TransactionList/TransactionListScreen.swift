//
//  TransactionListScreen.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  The home screen. SwiftUI owns the chrome — the branded header, load/empty/error
//  states, and the detail sheet — and the scrolling list itself (a native SwiftUI
//  `List`). Tapping a row presents the UIKit detail.
//

import SwiftUI

struct TransactionListScreen: View {

    @State private var viewModel: TransactionListViewModel
    @State private var selectedTransaction: Transaction?

    init(service: TransactionServicing) {
        _viewModel = State(initialValue: TransactionListViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TransactionListHeader(accountName: viewModel.accountName)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
                .toolbar(.hidden, for: .navigationBar)
                .task {
                    await viewModel.loadFirstPage()
                    // UI-test seam: deep-link to a transaction's detail on launch,
                    // e.g. `AUTO_OPEN_KEY=<key>` in the test/launch environment.
                    if let key = ProcessInfo.processInfo.environment["AUTO_OPEN_KEY"] {
                        selectedTransaction = await viewModel.transaction(withKey: key)
                    }
                }
                .sheet(item: $selectedTransaction) { transaction in
                    TransactionDetailRepresentable(transaction: transaction) {
                        selectedTransaction = nil
                    }
                    .ignoresSafeArea()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            TransactionListSkeleton()

        case let .loaded(sections):
            TransactionListView(
                sections: sections,
                isLoadingNextPage: viewModel.isLoadingNextPage,
                nextPageFailed: viewModel.nextPageFailed,
                onSelect: { selectedTransaction = $0 },
                onReachedEnd: { Task { await viewModel.loadNextPageIfNeeded() } },
                onRetry: { Task { await viewModel.retryNextPage() } }
            )

        case .empty:
            ContentUnavailableView(
                "No Transactions",
                systemImage: "creditcard",
                description: Text("You don't have any transactions yet.")
            )

        case let .failed(message):
            ContentUnavailableView {
                Label("Something went wrong", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await viewModel.loadFirstPage() } }
                    .buttonStyle(.glassProminent)
            }
        }
    }
}

/// The brand-red banner at the top of the home screen: a small "Transactions"
/// label above the account name, pinned above the scrolling list so it stays
/// visible. The red extends up behind the status bar with rounded bottom corners.
private struct TransactionListHeader: View {

    let accountName: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("Transactions")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            // A space keeps the banner's height stable while the first page loads.
            Text(accountName ?? " ")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.l)
        .background {
            Theme.Palette.brandRed
                .clipShape(.rect(bottomLeadingRadius: Theme.Spacing.l,
                                 bottomTrailingRadius: Theme.Spacing.l))
                .ignoresSafeArea(edges: .top)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TransactionListScreen(service: LocalTransactionService())
}
