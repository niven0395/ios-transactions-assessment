# Scotiabank Transactions — iOS Coding Assessment

A small iOS app that lists credit-card transactions and shows a detail screen for
each one. Built to the assignment brief, with a deliberate **SwiftUI + UIKit**
split and an **iOS 26 (Liquid Glass)** UI.

## What it does (per the brief)

- Loads transactions from the bundled **`transaction-list.json`** through a
  network-style service abstraction (no live API call).
- Shows each transaction's **merchant name + description + amount**; debits are
  signed with `-`, credits are green.
- Tapping a row presents the **Transaction Details** screen (Figure 1):
  - **green** checkmark + **"Credit transaction"** for credits,
  - **red** checkmark + **"Debit transaction"** for debits.
- A **ToolTip** that expands / collapses on **Show more / Show less**.
- A **Close** button that dismisses the detail back to the list.

## Architecture

**MVVM** over a protocol-oriented service/repository layer with dependency
injection, so the data source is swappable and the logic is unit-testable. **Both
screens are view-model-driven** — the SwiftUI list via `TransactionListViewModel`,
the UIKit detail via `TransactionDetailViewModel` — so the same Model→ViewModel→View
split applies uniformly across the SwiftUI/UIKit boundary.

```
App/            App entry; injects the service at the composition root
Models/         Transaction (Decodable, snake_case, forward-compatible enum)
Services/       TransactionServicing (protocol) + LocalTransactionService (bundled JSON, async/await)
ViewModels/     TransactionListViewModel (list: load/empty/error + pagination)
                TransactionDetailViewModel (detail: render-ready status/from/amount)
Common/         CurrencyFormatter, TransactionDateFormatter, date grouping, fixtures
DesignSystem/   Theme — semantic colours (Light/Dark) + brand red + credit green
Features/
  TransactionList/    SwiftUI list + loading skeleton + retry footer
  TransactionDetail/  UIKit detail (below) + the expand/collapse ToolTip
```

### Why SwiftUI **and** UIKit

The app shell, navigation, the scrolling **transaction list**, and state handling
are **SwiftUI** — the list is a native `List` with sticky date section headers,
hidden separators, and `.onAppear`-driven infinite scroll. The **Transaction
Detail screen is UIKit** — `TransactionDetailViewController` is a fully
programmatic view controller built with hand-rolled **Auto Layout** (a scrolling
card, the status header, detail rows, and the expand/collapse **ToolTip**). It's
bridged into the SwiftUI detail sheet with `UIViewControllerRepresentable`
(wrapped in a `UINavigationController` for its title bar), forwarding **Close**
back up so SwiftUI still owns dismissal.

### Scalability — paginated loading

The app never loads the whole history at once. The service is shaped like a
**paginated banking API** even though it reads a local file, so a real networked
source could drop straight in:

```
func fetchTransactions(after cursor: String?, limit: Int) async throws -> TransactionPage
```

- **Cursor-based paging** (`TransactionPage.nextCursor`) — the cursor is the last
  row's key, so it's stable even if new transactions arrive at the head. `nil`
  cursor means "no more pages." `LocalTransactionService` is an `actor` that
  decodes + sorts once, keeps a `key → index` map so cursor resolution is **O(1)**
  per page (not a linear scan), and serves cursor-delimited slices.
- **Infinite scroll**: the SwiftUI list calls back (`onReachedEnd`) a few rows
  before the bottom (a sentinel row's `.onAppear`); the view model fetches the next
  page and the list appends it, with a **loading-footer spinner** while it streams.
  Concurrent triggers are **deduped**, and a generation token guards against
  actor-reentrancy applying stale results.
- **Incremental grouping**: each page is grouped in **O(pageSize)** and merged onto
  the existing date sections (`TransactionGrouping.append`), so a long scroll stays
  linear rather than re-grouping the whole accumulated list per page.

### iOS 26 / Liquid Glass & modern Swift

- A brand-red banner header that extends behind the status bar with rounded bottom
  corners; the navigation bar is hidden in favour of this custom header.
- **Liquid Glass** on the error state's **Try Again** button
  (`.buttonStyle(.glassProminent)`). The detail **Close** button is a solid
  brand-red button, matching Figure 1.
- `ContentUnavailableView` for empty / error states.
- `@Observable` view model, **async/await** service, an `actor` data source, and
  structured concurrency with cancellation handled (a cancelled load is never
  surfaced as an error).
- Swift concurrency throughout: `Sendable` value-type models, `@MainActor`-isolated
  UI, and `nonisolated` pure helpers — annotated to be Swift 6-ready.

## Design decisions & assumptions

- **Date grouping + section headers** (e.g. `FRI, MAY 29, 2026`) aren't strictly
  required, but match the real Scotiabank app and keep a long history scannable.
- **Adaptive Light/Dark** via semantic colours; brand red and the credit green are
  fixed to stay on-brand and legible in both appearances.
- **Forward-compatible decoding**: an unknown `transaction_type` decodes to
  `.unknown` instead of failing the response; a missing `description` falls back
  to the merchant name.
- **Clean currency output**: iOS's currency formatter injects invisible bidi
  characters; these are stripped so output is deterministic for UI, VoiceOver and
  tests.
- **Accessibility**: Dynamic Type, ≥44pt row targets, one combined VoiceOver label
  per row, decorative icons hidden.

## Testing

- **Unit tests (Swift Testing)** — JSON decoding (incl. the `.unknown` fallback,
  missing description, and the direction-disambiguating derived titles),
  currency/date formatting (incl. strict date parsing and single-sign edges), date
  grouping, the detail **status header** (CREDIT → green "Credit transaction",
  DEBIT → red "Debit transaction") and the **ToolTip** expand/collapse copy,
  **cursor pagination** (the service walks the whole history in order with no
  duplicates, plus cursor edge cases), **incremental grouping** (appending pages
  matches a full re-group; an empty page is a no-op), the **detail view model**'s
  presentation mapping (status title/tone, From, card suffix, amount), and the
  **list view model** —
  first page, paging in the rest then stopping, empty/error states, **actor
  reentrancy / staleness** (a stale load can't clobber a fresh reload), **dedup**
  of overlapping page triggers, and **partial-failure recovery** — all via mock
  services that mirror the cursor API (gated, so no wall-clock sleeps).
- **UI tests (XCTest)** — list → tap row → detail → ToolTip Show more/less → Close
  round-trip, plus a launch screenshot. A launch-environment seam (`AUTO_OPEN_KEY`)
  deep-links straight to a transaction's detail for deterministic UI testing.

Run: `⌘U` in Xcode, or
`xcodebuild -scheme "Scotiabank Transactions SwiftUI + UIKIT" -destination 'platform=iOS Simulator,name=iPhone 17' test`

## Requirements

Xcode 26 · iOS 26.0+ deployment target (supports the full iOS 26 line).

## What I'd do next (given more time)

Ordered by what matters most at Scotiabank scale (millions of users, a large team,
a regulated Canadian bank):

- **Localization — English + French**: move user-facing strings to String Catalogs
  and let `CurrencyFormatter` follow the user locale (re-evaluating the bidi-strip
  once non-LTR/locale formatting is live). *Why:* for a federally-regulated Canadian
  bank, bilingual UI is effectively mandatory, not polish — it's the most impactful
  gap for this audience.
- **Observability**: an injectable `Analytics`/`Logger` protocol and OSLog signposts
  on page-fetch latency, plus a feature-flag seam and crash reporting. *Why:* at
  millions of users you can't ship safely without metrics, staged rollouts, and
  crash visibility — these are table stakes, not extras.
- **Modularization**: split into SPM packages (`TransactionsCore` model/service,
  `TransactionsUI`, `DesignSystem`). *Why:* with a large team, clear module
  boundaries and parallel build times are the engineering-scalability lever.
