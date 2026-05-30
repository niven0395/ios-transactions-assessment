//
//  ScotiabankTransactionsApp.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  App entry point. The transaction source is created here and injected into the
//  root screen, so swapping the bundled-JSON service for a real API later is a
//  one-line change with no other edits.
//

import SwiftUI

@main
struct ScotiabankTransactionsApp: App {

    /// Inject the concrete service once, at the composition root.
    /// Keep per-page latency minimal so transactions appear effectively instantly.
    private let service: TransactionServicing = LocalTransactionService(
        artificialDelay: .milliseconds(50)
    )

    /// Drives the brief branded splash. The list loads underneath while it shows,
    /// so this is a brand moment, not an added wait.
    @State private var isShowingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                TransactionListScreen(service: service)

                if isShowingSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // Hold the wordmark just long enough to read, then fade into the list.
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeOut(duration: 0.35)) { isShowingSplash = false }
            }
        }
    }
}
