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
    var isUITestEnvironment = ProcessInfo.processInfo.arguments.contains("--uitest")

    private var isCompleted = false

    private let backButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.left")
        configuration.imagePadding = 6
        configuration.baseForegroundColor = .appYellow
        configuration.attributedTitle = AttributedString("Назад", attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 17)]))
        let button = UIButton(configuration: configuration, primaryAction: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "editor.back"
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
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .systemFont(ofSize: 34, weight: .bold)
        textView.textColor = .appWhite
        textView.tintColor = .appYellow
        textView.keyboardAppearance = .dark
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.accessibilityIdentifier = "editor.title"
        return textView
    }()

    private let titlePlaceholder: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Название задачи"
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = UIColor.appWhite.withAlphaComponent(0.2)
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor.appWhite.withAlphaComponent(0.5)
        return label
    }()

    private let statusBadge: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .appYellow
        label.text = "Выполнено"
        label.isHidden = true
        return label
    }()

    private let bodyTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .appWhite
        textView.tintColor = .appYellow
        textView.keyboardAppearance = .dark
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.accessibilityIdentifier = "editor.body"
        return textView
    }()

    private let bodyPlaceholder: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Описание"
        label.font = .systemFont(ofSize: 16)
        label.textColor = UIColor.appWhite.withAlphaComponent(0.3)
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
    private var bodyTopToStatusConstraint: NSLayoutConstraint!
    private var bodyTopToDateConstraint: NSLayoutConstraint!
    private var keyboardTokens: [NSObjectProtocol] = []

#if DEBUG
    private(set) var lastExitConfirmationHandlers: (save: (() -> Void)?, discard: (() -> Void)?) = (nil, nil)
    private(set) var lastAlertActionHandlers: [ExitSelectionForTests: (() -> Void)] = [:]
    static var popoverFallbackHandler: ((UIAlertController, UIButton) -> Void)?
#endif

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
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

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
}

// Собираем экран редактора и расставляем ограничения
private extension TodoEditorViewController {
    /// Формируем UI из элементов макета и подключаем жесты
    func setupLayout() {
        view.backgroundColor = .appBlack
        navigationController?.setNavigationBarHidden(true, animated: false)

        titleTextView.delegate = self
        bodyTextView.delegate = self

        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)

        view.addSubview(backButton)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(titleTextView)
        contentView.addSubview(titlePlaceholder)
        contentView.addSubview(dateLabel)
        contentView.addSubview(statusBadge)
        contentView.addSubview(bodyTextView)
        contentView.addSubview(bodyPlaceholder)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
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
            titlePlaceholder.topAnchor.constraint(equalTo: titleTextView.topAnchor, constant: 2)
        ])

        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: titleTextView.bottomAnchor, constant: 12),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dateLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor)
        ])

        NSLayoutConstraint.activate([
            statusBadge.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 6),
            statusBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
        ])

        bodyTopToStatusConstraint = bodyTextView.topAnchor.constraint(equalTo: statusBadge.bottomAnchor, constant: 16)
        bodyTopToDateConstraint = bodyTextView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 16)
        bodyTopToStatusConstraint.isActive = true

        NSLayoutConstraint.activate([
            bodyTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bodyTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bodyTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        NSLayoutConstraint.activate([
            bodyPlaceholder.leadingAnchor.constraint(equalTo: bodyTextView.leadingAnchor),
            bodyPlaceholder.topAnchor.constraint(equalTo: bodyTextView.topAnchor, constant: 6)
        ])

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// Управление вводом и состоянием плейсхолдеров
private extension TodoEditorViewController {
    /// Пересчитываем динамическую высоту текстовых полей
    func updateTextHeights() {
        let titleSize = titleTextView.sizeThatFits(CGSize(width: titleTextView.bounds.width, height: .greatestFiniteMagnitude))
        titleHeightConstraint.constant = max(44, titleSize.height)

        let bodySize = bodyTextView.sizeThatFits(CGSize(width: bodyTextView.bounds.width, height: .greatestFiniteMagnitude))
        bodyHeightConstraint.constant = max(120, bodySize.height)

        view.layoutIfNeeded()
    }

    /// Скрываем плейсхолдеры, когда пользователь ввел текст
    func updatePlaceholders() {
        let titleEmpty = titleTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        titlePlaceholder.isHidden = !titleEmpty

        let bodyEmpty = bodyTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        bodyPlaceholder.isHidden = !bodyEmpty
    }

    /// Следим за клавиатурой, чтобы поднимать контент
    func registerKeyboardNotifications() {
        let willShow = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self,
                  let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber else { return }
            UIView.animate(withDuration: duration.doubleValue) {
                let inset = frame.height - self.view.safeAreaInsets.bottom + 16
                self.scrollView.contentInset.bottom = inset
                self.scrollView.verticalScrollIndicatorInsets.bottom = inset
            }
        }

        let willHide = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self,
                  let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber else { return }
            UIView.animate(withDuration: duration.doubleValue) {
                self.scrollView.contentInset.bottom = 0
                self.scrollView.verticalScrollIndicatorInsets.bottom = 0
            }
        }

        keyboardTokens = [willShow, willHide]
    }

    /// Отключаем наблюдателей клавиатуры при уходе со сцены
    func unregisterKeyboardNotifications() {
        keyboardTokens.forEach(NotificationCenter.default.removeObserver)
        keyboardTokens.removeAll()
    }
}

// Обработчики пользовательских событий
private extension TodoEditorViewController {
    @objc
    /// Сохраняем или закрываем редактор при тапе "Назад"
    func backButtonTapped() {
        view.endEditing(true)
        presenter.handleBackAction(title: titleTextView.text ?? "", details: bodyTextView.text, isCompleted: isCompleted)
    }
}

// Реализация протокола отображения редактора
extension TodoEditorViewController: TodoEditorViewProtocol {
    /// Подставляем данные задачи и настраиваем состояние UI
    func configure(with viewModel: TodoEditorViewModel) {
        titleTextView.text = viewModel.title
        bodyTextView.text = viewModel.details
        dateLabel.text = viewModel.createdAtText
        dateLabel.isHidden = viewModel.createdAtText == nil
        bodyTopToDateConstraint.constant = dateLabel.isHidden ? 0 : 16
        isCompleted = viewModel.isCompleted
        if viewModel.isCompleted {
            statusBadge.isHidden = false
            statusBadge.text = "Выполнено"
            bodyTopToStatusConstraint.isActive = true
            bodyTopToDateConstraint.isActive = false
        } else {
            statusBadge.isHidden = true
            bodyTopToStatusConstraint.isActive = false
            bodyTopToDateConstraint.isActive = true
        }

        updatePlaceholders()
        updateTextHeights()

        if titleTextView.text?.isEmpty ?? true {
            titleTextView.becomeFirstResponder()
        }
    }

    /// Прячем/показываем индикатор и блокируем взаимодействия
    func showLoading(_ isLoading: Bool) {
        backButton.isEnabled = !isLoading
        if isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    /// Показываем алерт, если валидация или сохранение завершились ошибкой
    func showError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    /// Просим подтвердить выход, когда пользователь ввел данные, но не сохранил
    func presentExitConfirmation(canSave: Bool, onSave: @escaping () -> Void, onDiscard: @escaping () -> Void) {
        let saveWrapper: (() -> Void)? = canSave ? { onSave() } : nil
        let discardWrapper: () -> Void = { onDiscard() }
#if DEBUG
        lastExitConfirmationHandlers = (saveWrapper, discardWrapper)
#endif
        if isUITestEnvironment {
            if let saveWrapper {
                handleExitSelection(.save(saveWrapper))
            } else {
                handleExitSelection(.discard(discardWrapper))
            }
            return
        }

        let alert = UIAlertController(
            title: "Сохранить задачу?",
            message: "Вы хотите сохранить изменения перед выходом?",
            preferredStyle: .actionSheet
        )

        if let saveWrapper {
            let actionHandler: () -> Void = { [weak self] in
                self?.handleExitSelection(.save(saveWrapper))
            }
            alert.addAction(UIAlertAction(title: "Сохранить", style: .default) { _ in
                actionHandler()
            })
#if DEBUG
            lastAlertActionHandlers[.save] = actionHandler
#endif
        }

        let discardTitle = canSave ? "Не сохранять" : "Выйти без сохранения"
        let discardHandler: () -> Void = { [weak self] in
            self?.handleExitSelection(.discard(discardWrapper))
        }
        alert.addAction(UIAlertAction(title: discardTitle, style: .destructive) { _ in
            discardHandler()
        })
#if DEBUG
        lastAlertActionHandlers[.discard] = discardHandler
#endif

        let cancelHandler: () -> Void = { [weak self] in
            self?.handleExitSelection(.cancel)
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel) { _ in
            cancelHandler()
        })
#if DEBUG
        lastAlertActionHandlers[.cancel] = cancelHandler
#endif

        if let popover = alert.popoverPresentationController {
            popover.sourceView = backButton
            popover.sourceRect = backButton.bounds
        } else {
#if DEBUG
            TodoEditorViewController.popoverFallbackHandler?(alert, backButton)
#endif
        }

        present(alert, animated: true)
    }

    private enum ExitSelection {
        case save(() -> Void)
        case discard(() -> Void)
        case cancel
    }

    private func handleExitSelection(_ selection: ExitSelection) {
        switch selection {
        case .save(let action):
            action()
        case .discard(let action):
            action()
        case .cancel:
            break
        }
#if DEBUG
        lastExitConfirmationHandlers = (nil, nil)
        lastAlertActionHandlers.removeAll()
#endif
    }
}

// Реализуем делегата текстовых вью для синхронизации UI
extension TodoEditorViewController: UITextViewDelegate {
    /// Синхронизируем высоту и плейсхолдеры при каждом изменении текста
    func textViewDidChange(_ textView: UITextView) {
        updateTextHeights()
        updatePlaceholders()
    }

    /// Сразу скрываем плейсхолдеры при начале редактирования
    func textViewDidBeginEditing(_ textView: UITextView) {
        updatePlaceholders()
    }

    /// После окончания ввода обновляем состояние плейсхолдеров
    func textViewDidEndEditing(_ textView: UITextView) {
        updatePlaceholders()
    }
}

#if DEBUG
extension TodoEditorViewController {
    var backButtonForTests: UIButton { backButton }
    var titleTextViewForTests: UITextView { titleTextView }
    var bodyTextViewForTests: UITextView { bodyTextView }
    var scrollViewForTests: UIScrollView { scrollView }
    var dateLabelForTests: UILabel { dateLabel }
    var statusBadgeForTests: UILabel { statusBadge }
    var activityIndicatorForTests: UIActivityIndicatorView { activityIndicator }
    var titlePlaceholderForTests: UILabel { titlePlaceholder }
    var bodyPlaceholderForTests: UILabel { bodyPlaceholder }
    var titleHeightConstraintForTests: NSLayoutConstraint { titleHeightConstraint }
    var bodyHeightConstraintForTests: NSLayoutConstraint { bodyHeightConstraint }
    var bodyTopToStatusConstraintForTests: NSLayoutConstraint { bodyTopToStatusConstraint }
    var bodyTopToDateConstraintForTests: NSLayoutConstraint { bodyTopToDateConstraint }

    enum ExitSelectionForTests {
        case save
        case discard
        case cancel
    }

    func performExitSelectionForTests(_ selection: ExitSelectionForTests) {
        switch selection {
        case .save:
            if let action = lastExitConfirmationHandlers.save {
                handleExitSelection(.save(action))
            }
        case .discard:
            if let action = lastExitConfirmationHandlers.discard {
                handleExitSelection(.discard(action))
            }
        case .cancel:
            handleExitSelection(.cancel)
        }
    }

    func triggerExitSaveHandlerForTests() {
        performExitSelectionForTests(.save)
    }

    func triggerExitDiscardHandlerForTests() {
        performExitSelectionForTests(.discard)
    }

    @discardableResult
    func triggerAlertActionHandlerForTests(_ selection: ExitSelectionForTests) -> Bool {
        guard let handler = lastAlertActionHandlers[selection] else { return false }
        handler()
        return true
    }
}
#endif


