//
//  TodoContextMenuViewController.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import UIKit

/// Контекстное меню задачи поверх списка
final class TodoContextMenuViewController: UIViewController {
    var onEdit: (() -> Void)?
    var onShare: (() -> Void)?
    var onDelete: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let viewModel: TodoContextMenuViewModel

    private let dimView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        return view
    }()

    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let infoCard = UIView()
    private let titleLabel = UILabel()
    private let detailsLabel = UILabel()
    private let dateLabel = UILabel()

    init(viewModel: TodoContextMenuViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupLayout()
        applyViewModel()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        onDismiss?()
    }
}

private extension TodoContextMenuViewController {
    func setupLayout() {
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        dimView.addGestureRecognizer(tap)

        view.addSubview(containerStack)
        NSLayoutConstraint.activate([
            containerStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerStack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),
            containerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            containerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])

        setupInfoCard()
        containerStack.addArrangedSubview(infoCard)

        let actionsStack = UIStackView()
        actionsStack.axis = .vertical
        actionsStack.spacing = 1
        actionsStack.translatesAutoresizingMaskIntoConstraints = false

        let editButton = makeActionButton(title: "Редактировать", iconName: "square.and.pencil", tint: .appBlack)
        editButton.accessibilityIdentifier = "context.edit"
        editButton.addTarget(self, action: #selector(handleEdit), for: .touchUpInside)

        let shareButton = makeActionButton(title: "Поделиться", iconName: "square.and.arrow.up", tint: .appBlack)
        shareButton.accessibilityIdentifier = "context.share"
        shareButton.addTarget(self, action: #selector(handleShare), for: .touchUpInside)

        let deleteButton = makeActionButton(title: "Удалить", iconName: "trash", tint: .appRed)
        deleteButton.accessibilityIdentifier = "context.delete"
        deleteButton.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)

        actionsStack.addArrangedSubview(editButton)
        actionsStack.addArrangedSubview(shareButton)
        actionsStack.addArrangedSubview(deleteButton)

        containerStack.addArrangedSubview(actionsStack)
    }

    func setupInfoCard() {
        infoCard.translatesAutoresizingMaskIntoConstraints = false
        infoCard.backgroundColor = .appGray
        infoCard.layer.cornerRadius = 12
        infoCard.clipsToBounds = true

        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .appWhite
        titleLabel.numberOfLines = 0

        detailsLabel.font = .systemFont(ofSize: 12)
        detailsLabel.textColor = UIColor.appWhite.withAlphaComponent(0.7)
        detailsLabel.numberOfLines = 0

        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = UIColor.appWhite.withAlphaComponent(0.5)

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailsLabel, dateLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        infoCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -16)
        ])
    }

    func applyViewModel() {
        if viewModel.isCompleted {
            let attributed = NSMutableAttributedString(string: viewModel.title)
            attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attributed.length))
            titleLabel.attributedText = attributed
            titleLabel.alpha = 0.5
        } else {
            titleLabel.text = viewModel.title
            titleLabel.alpha = 1
        }

        if let details = viewModel.details {
            detailsLabel.isHidden = false
            detailsLabel.text = details
        } else {
            detailsLabel.isHidden = true
        }

        dateLabel.text = viewModel.date
    }

    func makeActionButton(title: String, iconName: String, tint: UIColor) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: iconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium))
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 10
        configuration.baseForegroundColor = tint
        configuration.baseBackgroundColor = UIColor.white.withAlphaComponent(0.85)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        let button = UIButton(configuration: configuration, primaryAction: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        return button
    }

    @objc
    func handleBackgroundTap() {
        dismiss(animated: true)
    }

    @objc
    func handleEdit() {
        dismiss(animated: true) { [weak self] in
            self?.onEdit?()
        }
    }

    @objc
    func handleShare() {
        dismiss(animated: true) { [weak self] in
            self?.onShare?()
        }
    }

    @objc
    func handleDelete() {
        dismiss(animated: true) { [weak self] in
            self?.onDelete?()
        }
    }
}


