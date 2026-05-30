//
//  TransactionDetailRepresentable.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  Bridges the programmatic UIKit `TransactionDetailViewController` into the
//  SwiftUI `.sheet(item:)`. The VC is wrapped in a `UINavigationController` so it
//  gets the "Transaction Details" title bar; Close is forwarded back up via
//  `onClose`, keeping dismissal owned by SwiftUI.
//

import SwiftUI

struct TransactionDetailRepresentable: UIViewControllerRepresentable {

    let transaction: Transaction
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let detail = TransactionDetailViewController(
            viewModel: TransactionDetailViewModel(transaction: transaction)
        )
        detail.onClose = onClose
        let navigationController = UINavigationController(rootViewController: detail)
        navigationController.navigationBar.prefersLargeTitles = false
        return navigationController
    }

    func updateUIViewController(_ navigationController: UINavigationController, context: Context) {
        // Refresh the closure — it captures current SwiftUI state.
        (navigationController.viewControllers.first as? TransactionDetailViewController)?.onClose = onClose
    }
}

#Preview("Credit") {
    TransactionDetailRepresentable(transaction: .previewCredit, onClose: {})
        .ignoresSafeArea()
}

#Preview("Debit") {
    TransactionDetailRepresentable(transaction: .previewDebit, onClose: {})
        .ignoresSafeArea()
}
