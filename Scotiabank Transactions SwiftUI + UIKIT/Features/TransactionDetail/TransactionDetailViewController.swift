//
//  TransactionDetailViewController.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  The transaction detail screen (Figure 1), built entirely programmatically in
//  UIKit (no storyboard) for the brief's "build the UI programmatically" bonus.
//
//  A single rounded card holds: a green checkmark + "Credit transaction" (red +
//  "Debit transaction" for debits), the source account, the amount, the ToolTip,
//  and a Close button pinned to the bottom of the card that dismisses the sheet.
//

import UIKit

final class TransactionDetailViewController: UIViewController {

    private let viewModel: TransactionDetailViewModel

    /// Invoked when Close is tapped; the SwiftUI layer owns dismissal (it clears
    /// the sheet's `selectedTransaction`), mirroring the list's closure bridging.
    var onClose: (() -> Void)?

    init(viewModel: TransactionDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.title = "Transaction Details"
        navigationItem.largeTitleDisplayMode = .never
        setUpHierarchy()
    }

    // MARK: - Layout

    private func setUpHierarchy() {
        let card = makeCard()
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let content = makeContentStack()
        let closeButton = makeCloseButton()

        view.addSubview(card)
        card.addSubview(scrollView)
        card.addSubview(closeButton)
        scrollView.addSubview(content)

        let cardInset = Theme.Spacing.m   // 16pt gutter from the screen edges, as in Figure 1.

        NSLayoutConstraint.activate([
            // The card itself, inset within the safe area.
            card.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: cardInset),
            card.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -cardInset),
            card.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Spacing.s),
            card.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Spacing.m),

            // Close button pinned to the bottom of the card.
            closeButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Theme.Spacing.l),
            closeButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.l),
            closeButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Theme.Spacing.l),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),

            // Scroll view fills the card above the Close button so long content (or
            // large Dynamic Type) scrolls while the button stays put.
            scrollView.topAnchor.constraint(equalTo: card.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -Theme.Spacing.m),

            // Vertical-only scroll: content width is pinned to the scroll frame.
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    private func makeCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 20      // Figure 1: a generously rounded container card.
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.separator.cgColor
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius = 12
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        return card
    }

    private func makeContentStack() -> UIStackView {
        // Status header: checkmark + title, centred.
        let checkmark = UIImageView(image: UIImage(named: "SuccessIcon")?.withRenderingMode(.alwaysTemplate))
        checkmark.contentMode = .scaleAspectFit
        checkmark.tintColor = statusColor
        checkmark.isAccessibilityElement = false
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            checkmark.widthAnchor.constraint(equalToConstant: Theme.Spacing.checkmarkDiameter),
            checkmark.heightAnchor.constraint(equalToConstant: Theme.Spacing.checkmarkDiameter),
        ])

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.text = viewModel.statusTitle

        let header = UIStackView(arrangedSubviews: [checkmark, titleLabel])
        header.axis = .vertical
        header.alignment = .center
        header.spacing = Theme.Spacing.m
        // Combine the decorative checkmark + title into one VoiceOver element.
        header.isAccessibilityElement = true
        header.accessibilityLabel = viewModel.statusTitle

        // "From" — account name in the label colour, card suffix in grey, as in Figure 1.
        let valueFont = UIFont.preferredFont(forTextStyle: .title3)
        let fromValue = NSMutableAttributedString(
            string: viewModel.fromAccount,
            attributes: [.font: valueFont, .foregroundColor: UIColor.label]
        )
        fromValue.append(NSAttributedString(
            string: " (\(viewModel.cardSuffix))",
            attributes: [.font: valueFont, .foregroundColor: UIColor.secondaryLabel]
        ))
        let fromRow = makeRow(caption: "From") { $0.attributedText = fromValue }

        let amountRow = makeRow(caption: "Amount") {
            $0.text = viewModel.amountText
        }

        let details = UIStackView(arrangedSubviews: [fromRow, makeDivider(), amountRow])
        details.axis = .vertical
        details.spacing = Theme.Spacing.m

        let tooltip = TooltipCardView()
        tooltip.onToggle = { [weak self] in
            guard let self else { return }
            UIView.animate(withDuration: 0.35, delay: 0,
                           usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
                           options: [.allowUserInteraction]) {
                self.view.layoutIfNeeded()
            }
        }

        let content = UIStackView(arrangedSubviews: [header, details, tooltip])
        content.axis = .vertical
        content.alignment = .fill
        content.spacing = Theme.Spacing.l
        content.translatesAutoresizingMaskIntoConstraints = false
        content.isLayoutMarginsRelativeArrangement = true
        content.directionalLayoutMargins = .init(top: Theme.Spacing.xl, leading: Theme.Spacing.l,
                                                 bottom: Theme.Spacing.l, trailing: Theme.Spacing.l)
        // Generous gap below the centred header before the detail rows, as in Figure 1.
        content.setCustomSpacing(Theme.Spacing.xl, after: header)
        return content
    }

    /// One labelled detail row: a grey caption above a value label.
    private func makeRow(caption: String, configureValue: (UILabel) -> Void) -> UIStackView {
        let captionLabel = UILabel()
        captionLabel.font = .preferredFont(forTextStyle: .subheadline)
        captionLabel.textColor = .secondaryLabel
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.text = caption

        let valueLabel = UILabel()
        valueLabel.font = .preferredFont(forTextStyle: .title3)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 0
        valueLabel.adjustsFontForContentSizeCategory = true
        configureValue(valueLabel)

        let row = UIStackView(arrangedSubviews: [captionLabel, valueLabel])
        row.axis = .vertical
        row.alignment = .fill
        row.spacing = Theme.Spacing.xs
        return row
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 2
        divider.heightAnchor.constraint(equalToConstant: 1.0 / scale).isActive = true
        divider.setContentHuggingPriority(.required, for: .vertical)
        return divider
    }

    private func makeCloseButton() -> UIButton {
        var config = UIButton.Configuration.filled()   // Figure 1: a solid brand-red button.
        config.baseBackgroundColor = Theme.Palette.brandRedUI
        config.baseForegroundColor = .white
        config.cornerStyle = .fixed
        config.background.cornerRadius = 12
        config.contentInsets = .init(top: Theme.Spacing.m, leading: Theme.Spacing.m,
                                     bottom: Theme.Spacing.m, trailing: Theme.Spacing.m)
        var title = AttributedString("Close")
        title.font = .preferredFont(forTextStyle: .headline)
        config.attributedTitle = title

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)
        return button
    }

    // MARK: - Derived values

    private var statusColor: UIColor {
        switch viewModel.statusTone {
        case .positive: Theme.Palette.creditUI
        case .negative: .systemRed
        case .neutral: .secondaryLabel
        }
    }
}
