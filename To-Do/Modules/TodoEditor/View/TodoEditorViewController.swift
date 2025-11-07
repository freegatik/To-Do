//
//  TodoEditorViewController.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import UIKit

/// Экран создания и редактирования задачи
final class TodoEditorViewController: UIViewController {
    var presenter: TodoEditorPresenterProtocol!

    private var isCompleted = false

    private let topBar = UIView()
    private let backButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        configuration.imagePlacement = .leading
        configuration.imagePadding = 4
        configuration.title = "Назад"
        configuration.image = UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        configuration.baseForegroundColor = .appYellow
        let button = UIButton(configuration: configuration, primaryAction: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = .systemFont(ofSize: 17)
        button.accessibilityIdentifier = "editor.back"
        return button
    }()

    private let saveButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        configuration.title = "Сохранить"
        configuration.baseForegroundColor = .appYellow
        let button = UIButton(configuration: configuration, primaryAction: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.accessibilityIdentifier = "editor.save"
        return button
    }()

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .interactive
        return scroll
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 34, weight: .bold)
        textView.textColor = .appWhite
        textView.tintColor = .appYellow
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.accessibilityIdentifier = "editor.title"
        return textView
    }()

    private let titlePlaceholder: UILabel = {
        let label = UILabel()
        label.text = "Название"
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = UIColor.appWhite.withAlphaComponent(0.25)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor.appWhite.withAlphaComponent(0.5)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bodyTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .appWhite
        textView.tintColor = .appYellow
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.accessibilityIdentifier = "editor.body"
        return textView
    }()

    private let bodyPlaceholder: UILabel = {
        let label = UILabel()
        label.text = "Описание"
        label.font = .systemFont(ofSize: 16)
        label.textColor = UIColor.appWhite.withAlphaComponent(0.3)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private var titleHeightConstraint: NSLayoutConstraint!
    private var bodyHeightConstraint: NSLayoutConstraint!
    private var keyboardTokens: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerKeyboardNotifications()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterKeyboardNotifications()
    }
}

// MARK: - Настройка

private extension TodoEditorViewController {
    func setupUI() {
        view.backgroundColor = .appBlack
        navigationController?.setNavigationBarHidden(true, animated: false)

        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)
        topBar.addSubview(backButton)
        topBar.addSubview(saveButton)
        backButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(titleTextView)
        contentView.addSubview(titlePlaceholder)
        contentView.addSubview(dateLabel)
        contentView.addSubview(bodyTextView)
        contentView.addSubview(bodyPlaceholder)
        view.addSubview(activityIndicator)

        titleTextView.delegate = self
        bodyTextView.delegate = self

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 50)
        ])

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 8),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor)
        ])

        NSLayoutConstraint.activate([
            saveButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            saveButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor)
        ])

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        titleHeightConstraint = titleTextView.heightAnchor.constraint(equalToConstant: 44)
        bodyHeightConstraint = bodyTextView.heightAnchor.constraint(equalToConstant: 120)
        titleHeightConstraint.isActive = true
        bodyHeightConstraint.isActive = true

        NSLayoutConstraint.activate([
            titleTextView.topAnchor.constraint(equalTo: contentView.topAnchor),
            titleTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])

        NSLayoutConstraint.activate([
            titlePlaceholder.leadingAnchor.constraint(equalTo: titleTextView.leadingAnchor),
            titlePlaceholder.topAnchor.constraint(equalTo: titleTextView.topAnchor, constant: 4)
        ])

        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: titleTextView.bottomAnchor, constant: 8),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dateLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor)
        ])

        NSLayoutConstraint.activate([
            bodyTextView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 16),
            bodyTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bodyTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bodyTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        NSLayoutConstraint.activate([
            bodyPlaceholder.topAnchor.constraint(equalTo: bodyTextView.topAnchor, constant: 6),
            bodyPlaceholder.leadingAnchor.constraint(equalTo: bodyTextView.leadingAnchor)
        ])

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func updateTextViews() {
        let titleSize = titleTextView.sizeThatFits(CGSize(width: titleTextView.bounds.width, height: .greatestFiniteMagnitude))
        titleHeightConstraint.constant = max(44, titleSize.height)

        let bodySize = bodyTextView.sizeThatFits(CGSize(width: bodyTextView.bounds.width, height: .greatestFiniteMagnitude))
        bodyHeightConstraint.constant = max(120, bodySize.height)

        view.layoutIfNeeded()
    }

    func updatePlaceholders() {
        let titleIsEmpty = titleTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        titlePlaceholder.isHidden = !titleIsEmpty

        let bodyIsEmpty = bodyTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        bodyPlaceholder.isHidden = !bodyIsEmpty
    }

    func registerKeyboardNotifications() {
        let willShow = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self,
                  let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            scrollView.contentInset.bottom = frame.height + 24
            scrollView.verticalScrollIndicatorInsets.bottom = frame.height + 24
        }

        let willHide = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
            self?.scrollView.contentInset.bottom = 0
            self?.scrollView.verticalScrollIndicatorInsets.bottom = 0
        }

        keyboardTokens = [willShow, willHide]
    }

    func unregisterKeyboardNotifications() {
        keyboardTokens.forEach { NotificationCenter.default.removeObserver($0) }
        keyboardTokens.removeAll()
    }

    @objc
    func saveTapped() {
        presenter.didTapSave(
            title: titleTextView.text ?? "",
            details: bodyTextView.text,
            isCompleted: isCompleted
        )
    }

    @objc
    func cancelTapped() {
        presenter.didTapCancel()
    }
}

// MARK: - TodoEditorViewProtocol

extension TodoEditorViewController: TodoEditorViewProtocol {
    func configure(with viewModel: TodoEditorViewModel) {
        saveButton.setTitle(viewModel.actionButtonTitle, for: .normal)
        titleTextView.text = viewModel.title
        bodyTextView.text = viewModel.details
        dateLabel.text = viewModel.createdAtText
        dateLabel.isHidden = viewModel.createdAtText == nil
        isCompleted = viewModel.isCompleted

        updatePlaceholders()
        updateTextViews()

        if (titleTextView.text?.isEmpty ?? true) {
            titleTextView.becomeFirstResponder()
        }
    }

    func showLoading(_ isLoading: Bool) {
        backButton.isEnabled = !isLoading
        saveButton.isEnabled = !isLoading
        if isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextViewDelegate

extension TodoEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateTextViews()
        updatePlaceholders()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        updatePlaceholders()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        updatePlaceholders()
    }
}


