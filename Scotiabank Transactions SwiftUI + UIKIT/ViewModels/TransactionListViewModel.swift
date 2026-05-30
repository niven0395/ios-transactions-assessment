//
//  TransactionListViewModel.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  Drives the transaction list. Browsing is a cursor-paginated feed: the user
//  scrolls and the next page streams in, paging the full history. Each page is
//  grouped incrementally so a long scroll stays linear.
//

import Foundation
import Observation

@MainActor
@Observable
final class TransactionListViewModel {

    /// The phases the main content can be in. Modelling this explicitly keeps the
    /// view declarative — it just switches over `state`.
    enum State: Equatable {
        case loading
        case loaded([TransactionSection])
        case empty
        case failed(String)
    }

    private(set) var state: State = .loading
    /// Drives the list's loading footer while the next page streams in.
    private(set) var isLoadingNextPage = false
    /// Set when a *subsequent* page fetch fails (we already have rows to show).
    /// Drives the list's retry footer so a transient error isn't swallowed.
    private(set) var nextPageFailed = false
    /// Whether more pages remain to be fetched.
    private(set) var hasMorePages = true

    /// The card/account the feed belongs to, shown in the header. Every row shares
    /// one account; `nil` until the first page arrives.
    var accountName: String? { browse.items.first?.fromAccount }

    private let service: TransactionServicing
    private let pageSize: Int

    /// Paginated browse feed (full history).
    private var browse = Feed()

    /// Bumped on every reload so a page fetch that finishes after the session was
    /// replaced can detect it's stale and bail — guards against actor reentrancy
    /// clobbering fresh state.
    private var generation = 0

    init(service: TransactionServicing,
         pageSize: Int = 15) {
        self.service = service
        self.pageSize = pageSize
    }

    // MARK: - Loading

    /// Loads the first page of the browse feed. Safe to call from `.task`.
    func loadFirstPage() async {
        generation += 1
        browse.reset()
        state = .loading
        await fetchNextPage()
    }

    /// Requests the next page if one is available and not already loading. Called
    /// repeatedly by the list as the user nears the end — deduped so overlapping
    /// scroll triggers collapse into one fetch.
    func loadNextPageIfNeeded() async {
        await fetchNextPage(loadMore: true)
    }

    /// Retries the next page after a failed fetch (driven by the list's retry
    /// footer). Same path as a scroll-triggered load; the in-flight/has-more
    /// guards keep it safe to tap repeatedly.
    func retryNextPage() async {
        await fetchNextPage(loadMore: true)
    }

    private func fetchNextPage(loadMore: Bool = false) async {
        if loadMore {
            guard browse.hasMore, !browse.isFetching else { return }
        }

        let session = generation
        let cursor = browse.nextCursor
        browse.isFetching = true
        isLoadingNextPage = true
        nextPageFailed = false      // a fetch is in flight; clear any prior failure

        let page = try? await service.fetchTransactions(after: cursor, limit: pageSize)

        // A reload replaced this session while we awaited — the new session owns
        // all flags and state, so leave everything untouched.
        guard session == generation else { return }

        // This fetch is done: clear its in-flight flags so paging can resume.
        browse.isFetching = false
        isLoadingNextPage = false

        guard let page else {
            // Nothing to show yet → full-screen error. Otherwise surface a retry
            // footer so the user can recover without losing the rows they have.
            if browse.items.isEmpty {
                state = .failed(Self.loadErrorMessage)
            } else {
                nextPageFailed = true
            }
            return
        }

        browse.append(page)
        publishFeed()
    }

    // MARK: - Publishing

    private func publishFeed() {
        hasMorePages = browse.hasMore
        state = browse.sections.isEmpty ? .empty : .loaded(browse.sections)
    }

    // MARK: - Helpers

    /// Resolves a transaction by key across the full history (used by the
    /// AUTO_OPEN_KEY UI-test seam, since the row may not be paged in yet). Pages
    /// through history with `fetchTransactions` when the row isn't already loaded.
    func transaction(withKey key: String) async -> Transaction? {
        if let local = browse.items.first(where: { $0.key == key }) { return local }
        var cursor: String?
        repeat {
            guard let page = try? await service.fetchTransactions(after: cursor, limit: 100)
            else { return nil }
            if let match = page.transactions.first(where: { $0.key == key }) { return match }
            cursor = page.nextCursor
        } while cursor != nil
        return nil
    }

    private static let loadErrorMessage =
        "We couldn't load your transactions. Please try again."
}

// MARK: - Feed

extension TransactionListViewModel {

    /// The cursor-paginated browse feed. Holds the accumulated items, a dedup
    /// guard, and the incrementally-built sections, so a page merges in
    /// O(pageSize) instead of regrouping everything.
    private struct Feed {
        private(set) var items: [Transaction] = []
        private(set) var sections: [TransactionSection] = []
        private var keys: Set<String> = []          // dedup guard across pages
        var nextCursor: String?
        var hasMore = true
        var isFetching = false

        mutating func reset() { self = Feed() }

        /// Merges a fetched page in: dedups, appends, and extends the grouped
        /// sections with just the new rows.
        mutating func append(_ page: TransactionPage) {
            var fresh: [Transaction] = []
            for txn in page.transactions where keys.insert(txn.key).inserted {
                items.append(txn)
                fresh.append(txn)
            }
            sections = TransactionGrouping.append(fresh, to: sections)
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        }
    }
}
