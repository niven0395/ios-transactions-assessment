//
//  TooltipCardView.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  The brief's ToolTip (Figure 1), built programmatically in UIKit: a megaphone
//  icon, an info message, and a "Show more"/"Show less" toggle that reveals the
//  extra line with an animation. The copy/rule lives in `TooltipContent` so it
//  stays unit-tested; this view only renders and animates it.
//

import UIKit

final class TooltipCardView: UIView {

    /// Called after the expand/collapse state flips, so the owner can animate the
    /// surrounding layout (the card — and the scroll content — grow/shrink).
    var onToggle: (() -> Void)?

    private var isExpanded = false

    private let iconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "BuddyTipIcon")?.withRenderingMode(.alwaysOriginal))
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.isAccessibilityElement = false
        return imageView
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.text = TooltipContent.message(isExpanded: false)
        return label
    }()

    private let toggleButton: UIButton = {
        let button = UIButton(type: .system)
        // Semibold + Dynamic Type, matching the design's emphasised link.
        let semibold = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize,
                                         weight: .semibold)
        button.titleLabel?.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.setTitleColor(Theme.Palette.linkUI, for: .normal)
        button.contentHorizontalAlignment = .leading
        button.setTitle(TooltipContent.toggleLabel(isExpanded: false), for: .normal)
        button.accessibilityHint = "Expands the message"
        return button
    }()

    init() {
        super.init(frame: .zero)
        setUpHierarchy()
        // A CGColor doesn't auto-adapt to Light/Dark, so refresh the border whenever
        // the interface style changes (the modern replacement for the deprecated
        // `traitCollectionDidChange(_:)`).
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: TooltipCardView, _) in
            view.layer.borderColor = UIColor.separator.cgColor
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setUpHierarchy() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 12          // Figure 1: the ToolTip box is more lightly rounded than the outer card.
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor
        // Soft shadow so the box lifts off the card, as in the design.
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 3)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 24),
        ])

        toggleButton.addAction(UIAction { [weak self] _ in self?.toggle() }, for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [messageLabel, toggleButton])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = Theme.Spacing.s

        let rowStack = UIStackView(arrangedSubviews: [iconView, textStack])
        rowStack.axis = .horizontal
        rowStack.alignment = .top
        rowStack.spacing = Theme.Spacing.m
        rowStack.isLayoutMarginsRelativeArrangement = true
        rowStack.directionalLayoutMargins = .init(top: Theme.Spacing.m, leading: Theme.Spacing.m,
                                                  bottom: Theme.Spacing.m, trailing: Theme.Spacing.m)
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func toggle() {
        isExpanded.toggle()
        messageLabel.text = TooltipContent.message(isExpanded: isExpanded)
        toggleButton.setTitle(TooltipContent.toggleLabel(isExpanded: isExpanded), for: .normal)
        toggleButton.accessibilityHint = isExpanded ? "Collapses the message" : "Expands the message"
        onToggle?()
    }
}
