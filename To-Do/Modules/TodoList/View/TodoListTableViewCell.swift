//
//  TodoListTableViewCell.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import UIKit

/// Кастомная ячейка для строки задачи
final class TodoListTableViewCell: UITableViewCell {
    static let reuseIdentifier = "TodoListTableViewCell"

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        imageView.tintColor = .appWhite
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .appWhite
        label.numberOfLines = 2
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor.appWhite.withAlphaComponent(0.7)
        label.numberOfLines = 2
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor.appWhite.withAlphaComponent(0.5)
        return label
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.appStroke.withAlphaComponent(0.5)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var labelsStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, detailsLabel, dateLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        accessoryType = .none
        backgroundColor = .clear
        contentView.backgroundColor = .appBlack
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.attributedText = nil
        titleLabel.text = nil
        detailsLabel.text = nil
        dateLabel.text = nil
    }

    /// Настраиваем элементы из view‑модели
    func configure(with viewModel: TodoListItemViewModel) {
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
        dateLabel.isHidden = false

        let secondaryAlpha: CGFloat = viewModel.isCompleted ? 0.5 : 1
        detailsLabel.alpha = detailsLabel.isHidden ? 0 : secondaryAlpha
        dateLabel.alpha = secondaryAlpha

        if viewModel.isCompleted {
            iconImageView.image = UIImage(systemName: "checkmark.circle.fill")
            iconImageView.tintColor = .appYellow
        } else {
            iconImageView.image = UIImage(systemName: "circle")
            iconImageView.tintColor = UIColor.appWhite.withAlphaComponent(0.6)
        }
    }
}

private extension TodoListTableViewCell {
    func setupLayout() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(labelsStack)
        contentView.addSubview(separatorView)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            labelsStack.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            labelsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            labelsStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            labelsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            separatorView.leadingAnchor.constraint(equalTo: labelsStack.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: labelsStack.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5 / UIScreen.main.scale)
        ])
    }
}
