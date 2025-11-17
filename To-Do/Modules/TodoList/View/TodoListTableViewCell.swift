//
//  TodoListTableViewCell.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import UIKit

/// Ячейка списка в стиле макета
final class TodoListTableViewCell: UITableViewCell {
    static let reuseIdentifier = "TodoListTableViewCell"

    private let statusButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.appStroke.cgColor
        button.backgroundColor = .clear
        button.tintColor = .appYellow
        button.accessibilityIdentifier = "todoList.cell.status"
        button.isAccessibilityElement = true
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .appWhite
        label.numberOfLines = 2
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor.appWhite.withAlphaComponent(0.85)
        label.numberOfLines = 3
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor.appWhite.withAlphaComponent(0.5)
        return label
    }()

    private lazy var textStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, detailsLabel, dateLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.appStroke.withAlphaComponent(0.33)
        return view
    }()

    private var onToggleStatus: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .appBlack
        contentView.preservesSuperviewLayoutMargins = false
        contentView.layoutMargins = .zero
        setupLayout()
        statusButton.accessibilityTraits.insert(.button)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.attributedText = nil
        titleLabel.text = nil
        detailsLabel.text = nil
        detailsLabel.isHidden = false
        dateLabel.text = nil
        statusButton.accessibilityValue = nil
        separatorView.isHidden = false
        contentView.backgroundColor = .appBlack
        titleLabel.textColor = .appWhite
        detailsLabel.textColor = UIColor.appWhite.withAlphaComponent(0.85)
        detailsLabel.alpha = 1
        dateLabel.textColor = UIColor.appWhite.withAlphaComponent(0.5)
        dateLabel.alpha = 1
        statusButton.layer.borderColor = UIColor.appStroke.cgColor
        statusButton.backgroundColor = .clear
        statusButton.setImage(nil, for: .normal)
    }

    /// Настраиваем ячейку данными
    func configure(with viewModel: TodoListItemViewModel) {
        if viewModel.isCompleted {
            let attributed = NSMutableAttributedString(string: viewModel.title)
            attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attributed.length))
            attributed.addAttribute(.foregroundColor, value: UIColor.appWhite.withAlphaComponent(0.5), range: NSRange(location: 0, length: attributed.length))
            titleLabel.attributedText = attributed
            titleLabel.alpha = 0.5
            titleLabel.textColor = UIColor.appWhite
            detailsLabel.textColor = UIColor.appWhite.withAlphaComponent(0.5)
            dateLabel.textColor = UIColor.appWhite.withAlphaComponent(0.5)
            statusButton.layer.borderColor = UIColor.appYellow.cgColor
            let configuration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            statusButton.setImage(UIImage(systemName: "checkmark", withConfiguration: configuration), for: .normal)
            statusButton.accessibilityValue = "completed"
            statusButton.backgroundColor = .clear
            contentView.backgroundColor = .appBlack
        } else {
            titleLabel.text = viewModel.title
            titleLabel.alpha = 1
            titleLabel.textColor = .appWhite
            detailsLabel.textColor = UIColor.appWhite.withAlphaComponent(0.85)
            dateLabel.textColor = UIColor.appWhite.withAlphaComponent(0.5)
            statusButton.layer.borderColor = UIColor.appStroke.cgColor
            statusButton.setImage(nil, for: .normal)
            statusButton.accessibilityValue = "active"
            statusButton.backgroundColor = .clear
            contentView.backgroundColor = .appBlack
        }

        if let details = viewModel.details {
            detailsLabel.isHidden = false
            detailsLabel.text = details
        } else {
            detailsLabel.isHidden = true
        }

        dateLabel.text = viewModel.date

        statusButton.accessibilityLabel = viewModel.isCompleted ? "Задача выполнена" : "Задача активна"
        statusButton.accessibilityHint = viewModel.isCompleted ? "Нажмите, чтобы отметить как невыполненную" : "Нажмите, чтобы отметить как выполненную"
    }

    /// Управляем отображением разделительной линии между задачами
    func setShowsSeparator(_ isVisible: Bool) {
        separatorView.isHidden = !isVisible
    }

    /// Подписываемся на нажатие по кнопке статуса задачи
    func setToggleHandler(_ handler: @escaping () -> Void) {
        onToggleStatus = handler
        statusButton.removeTarget(self, action: #selector(handleStatusTap), for: .touchUpInside)
        statusButton.addTarget(self, action: #selector(handleStatusTap), for: .touchUpInside)
    }

    /// Расширяем hit area кнопки статуса, чтобы в неё было проще попасть
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let buttonPoint = statusButton.convert(point, from: self)
        if statusButton.bounds.insetBy(dx: -10, dy: -10).contains(buttonPoint) {
            return statusButton
        }
        return super.hitTest(point, with: event)
    }
}

private extension TodoListTableViewCell {
    /// Расставляем элементы ячейки согласно макету
    func setupLayout() {
        contentView.addSubview(statusButton)
        contentView.addSubview(textStack)
        contentView.addSubview(separatorView)

        NSLayoutConstraint.activate([
            statusButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            statusButton.widthAnchor.constraint(equalToConstant: 24),
            statusButton.heightAnchor.constraint(equalToConstant: 24),

            textStack.leadingAnchor.constraint(equalTo: statusButton.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            separatorView.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: textStack.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    @objc
    /// Вызываем колбэк переключения статуса
    func handleStatusTap() {
        onToggleStatus?()
    }
}
