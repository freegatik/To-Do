//
//  TodoListViewController.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import UIKit
import AVFoundation
import Speech

protocol AudioSessionProtocol: AnyObject {
    func requestRecordPermission(_ handler: @escaping (Bool) -> Void)
    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

extension AVAudioSession: AudioSessionProtocol { }

protocol SpeechRecognizerProtocol: AnyObject {
    var isAvailable: Bool { get }
    func startRecognitionTask(
        with request: SFSpeechRecognitionRequest,
        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void
    ) -> SpeechRecognitionTaskProtocol
}

extension SFSpeechRecognizer: SpeechRecognizerProtocol {
    func startRecognitionTask(
        with request: SFSpeechRecognitionRequest,
        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void
    ) -> SpeechRecognitionTaskProtocol {
        recognitionTask(with: request, resultHandler: resultHandler)
    }
}

protocol SpeechRecognitionTaskProtocol: AnyObject {
    func cancel()
}

extension SFSpeechRecognitionTask: SpeechRecognitionTaskProtocol { }

protocol AudioInputNodeProtocol: AnyObject {
    func outputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat
    func removeTap(onBus bus: AVAudioNodeBus)
    func installTap(
        onBus bus: AVAudioNodeBus,
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat?,
        block: @escaping AVAudioNodeTapBlock
    )
}

extension AVAudioInputNode: AudioInputNodeProtocol { }

protocol AudioEngineProtocol: AnyObject {
    var inputNodeWrapper: AudioInputNodeProtocol { get }
    func prepare()
    func start() throws
    func stop()
}

extension AVAudioEngine: AudioEngineProtocol {
    var inputNodeWrapper: AudioInputNodeProtocol { inputNode }
}

/// Экран списка задач с кастомной версткой под макет
final class TodoListViewController: UIViewController {
    var presenter: TodoListPresenterProtocol!

    private var viewModels: [TodoListItemViewModel] = []
    private var contextMenuController: TodoContextMenuViewController?
    private var pendingContextMenuAnchorRect: CGRect?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = .appWhite
        label.text = "Задачи"
        return label
    }()

    private let searchContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 39 / 255, green: 39 / 255, blue: 41 / 255, alpha: 1)
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        view.accessibilityIdentifier = "todoList.searchContainer"
        return view
    }()

    private let searchIconView: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        let imageView = UIImageView(image: UIImage(systemName: "magnifyingglass", withConfiguration: configuration))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = UIColor.appWhite.withAlphaComponent(0.5)
        return imageView
    }()

    private let voiceButton: UIButton = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        let image = UIImage(systemName: "mic.fill", withConfiguration: configuration)
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(image, for: .normal)
        button.tintColor = UIColor.appWhite.withAlphaComponent(0.5)
        button.layer.masksToBounds = true
        button.accessibilityIdentifier = "todoList.voiceButton"
        button.accessibilityLabel = "Голосовой ввод"
        return button
    }()

    private let searchTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textColor = .appWhite
        textField.tintColor = .appYellow
        textField.font = .systemFont(ofSize: 17)
        textField.keyboardAppearance = .dark
        textField.attributedPlaceholder = NSAttributedString(
            string: "Search",
            attributes: [.foregroundColor: UIColor.appWhite.withAlphaComponent(0.5)]
        )
        textField.accessibilityIdentifier = "todoList.searchField"
        textField.returnKeyType = .search
        return textField
    }()

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInsetAdjustmentBehavior = .never
        return tableView
    }()

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16)
        label.textColor = UIColor.appWhite.withAlphaComponent(0.6)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isHidden = true
        label.accessibilityIdentifier = "todoList.emptyState"
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let bottomBar: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemChromeMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()

    private let bottomBarSeparator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.appStroke.withAlphaComponent(0.6)
        return view
    }()

    private let tasksCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11)
        label.textColor = .appWhite
        label.textAlignment = .center
        label.alpha = 0.9
        return label
    }()

    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let configuration = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        var buttonConfiguration = UIButton.Configuration.plain()
        buttonConfiguration.image = UIImage(systemName: "square.and.pencil", withConfiguration: configuration)
        buttonConfiguration.baseForegroundColor = .appYellow
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 9, bottom: 9, trailing: 9)
        button.configuration = buttonConfiguration
        button.tintColor = .appYellow
        button.accessibilityIdentifier = "todoList.addButton"
        return button
    }()

    private let bottomFadeView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    private let bottomFadeLayer = CAGradientLayer()

    private let refreshControl = UIRefreshControl()
    private var bottomBarHeightConstraint: NSLayoutConstraint?
    private var bottomFadeHeightConstraint: NSLayoutConstraint?
    private var lastSafeAreaBottomInset: CGFloat = -1

    private lazy var dismissKeyboardTap: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        recognizer.cancelsTouchesInView = false
        return recognizer
    }()

    var audioSessionProvider: () -> AudioSessionProtocol = { AVAudioSession.sharedInstance() }
    var speechAuthorizationRequest: (@escaping (SFSpeechRecognizerAuthorizationStatus) -> Void) -> Void = { handler in
        SFSpeechRecognizer.requestAuthorization(handler)
    }
    var speechRecognizerFactory: () -> SpeechRecognizerProtocol? = {
        SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    }
    var audioEngineFactory: () -> AudioEngineProtocol = { AVAudioEngine() }
    var recognitionRequestFactory: () -> SFSpeechAudioBufferRecognitionRequest = { SFSpeechAudioBufferRecognitionRequest() }
    var recognitionTaskFactory: (
        SpeechRecognizerProtocol,
        SFSpeechRecognitionRequest,
        @escaping (_ recognizedText: String?, _ isFinal: Bool, _ error: Error?) -> Void
    ) -> SpeechRecognitionTaskProtocol = { recognizer, request, handler in
        recognizer.startRecognitionTask(with: request, resultHandler: { result, error in
            handler(result?.bestTranscription.formattedString, result?.isFinal ?? false, error)
        })
    }

    private var speechRecognizer: SpeechRecognizerProtocol?
    private lazy var audioEngine: AudioEngineProtocol = audioEngineFactory()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SpeechRecognitionTaskProtocol?
    private var isListening = false
    private var isAudioTapInstalled = false
    private var lastRecognizedText: String?
    private var suppressSelectionForRow: IndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupLayout()
        presenter.viewDidLoad()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopVoiceRecognition()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBottomAreaLayoutIfNeeded()
        bottomFadeLayer.frame = bottomFadeView.bounds
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateBottomAreaLayoutIfNeeded()
    }
}

// Разметка экрана и базовые ограничения
private extension TodoListViewController {
    /// Собираем основные элементы интерфейса и подключаем жесты
    func setupLayout() {
        view.backgroundColor = .appBlack
        view.addGestureRecognizer(dismissKeyboardTap)
        setupHeader()
        setupSearch()
        setupTableView()
        setupEmptyState()
        setupBottomFade()
        setupBottomBar()
        setupActivityIndicator()
    }

    /// Верхний заголовок списка
    func setupHeader() {
        view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    /// Контейнер поиска с иконкой и кнопкой голосового ввода
    func setupSearch() {
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextDidChange(_:)), for: .editingChanged)

        view.addSubview(searchContainerView)
        searchContainerView.addSubview(searchIconView)
        searchContainerView.addSubview(searchTextField)
        searchContainerView.addSubview(voiceButton)

        NSLayoutConstraint.activate([
            searchContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            searchContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            searchContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            searchContainerView.heightAnchor.constraint(equalToConstant: 36),

            searchIconView.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: 12),
            searchIconView.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            searchIconView.widthAnchor.constraint(equalToConstant: 18),
            searchIconView.heightAnchor.constraint(equalToConstant: 18),

            voiceButton.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -12),
            voiceButton.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            voiceButton.widthAnchor.constraint(equalToConstant: 24),
            voiceButton.heightAnchor.constraint(equalToConstant: 24),

            searchTextField.leadingAnchor.constraint(equalTo: searchIconView.trailingAnchor, constant: 8),
            searchTextField.trailingAnchor.constraint(equalTo: voiceButton.leadingAnchor, constant: -8),
            searchTextField.topAnchor.constraint(equalTo: searchContainerView.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchContainerView.bottomAnchor)
        ])

        voiceButton.addTarget(self, action: #selector(voiceButtonTapped), for: .touchUpInside)
    }

    /// Настраиваем таблицу задач и pull-to-refresh
    func setupTableView() {
        tableView.register(TodoListTableViewCell.self, forCellReuseIdentifier: TodoListTableViewCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.refreshControl = refreshControl
        tableView.accessibilityIdentifier = "todoList.table"

        refreshControl.tintColor = .appYellow
        refreshControl.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchContainerView.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// Показываем текст вместо таблицы, если список пуст
    func setupEmptyState() {
        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    /// Создаем градиентный фейд под таблицей, чтобы кнопка выглядела встроенно
    func setupBottomFade() {
        view.addSubview(bottomFadeView)
        bottomFadeLayer.colors = [
            UIColor.appBlack.withAlphaComponent(0).cgColor,
            UIColor.appBlack.cgColor
        ]
        bottomFadeLayer.locations = [0, 1]
        bottomFadeView.layer.addSublayer(bottomFadeLayer)

        bottomFadeHeightConstraint = bottomFadeView.heightAnchor.constraint(equalToConstant: 96)

        NSLayoutConstraint.activate([
            bottomFadeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomFadeHeightConstraint!
        ])
    }

    /// Настраиваем нижнюю панель с кнопкой добавления и счётчиком задач
    func setupBottomBar() {
        view.addSubview(bottomBar)
        bottomBar.contentView.addSubview(bottomBarSeparator)
        bottomBar.contentView.addSubview(tasksCountLabel)
        bottomBar.contentView.addSubview(addButton)

        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        bottomBar.contentView.backgroundColor = UIColor.appGray.withAlphaComponent(0.92)
        bottomBar.contentView.layoutMargins = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)

        bottomBarHeightConstraint = bottomBar.heightAnchor.constraint(equalToConstant: 56 + view.safeAreaInsets.bottom)

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBarHeightConstraint!,

            bottomBarSeparator.topAnchor.constraint(equalTo: bottomBar.contentView.topAnchor),
            bottomBarSeparator.leadingAnchor.constraint(equalTo: bottomBar.contentView.leadingAnchor),
            bottomBarSeparator.trailingAnchor.constraint(equalTo: bottomBar.contentView.trailingAnchor),
            bottomBarSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            addButton.trailingAnchor.constraint(equalTo: bottomBar.contentView.layoutMarginsGuide.trailingAnchor),
            addButton.centerYAnchor.constraint(equalTo: bottomBar.contentView.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 68),
            addButton.heightAnchor.constraint(equalToConstant: 44),

            tasksCountLabel.centerXAnchor.constraint(equalTo: bottomBar.contentView.layoutMarginsGuide.centerXAnchor),
            tasksCountLabel.centerYAnchor.constraint(equalTo: bottomBar.contentView.centerYAnchor)
        ])

        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        var buttonConfiguration = UIButton.Configuration.plain()
        buttonConfiguration.image = UIImage(systemName: "square.and.pencil", withConfiguration: symbolConfiguration)
        buttonConfiguration.preferredSymbolConfigurationForImage = symbolConfiguration
        buttonConfiguration.baseForegroundColor = .appYellow
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 9, bottom: 9, trailing: 9)
        addButton.configuration = buttonConfiguration
        addButton.tintColor = .appYellow

        updateTasksCount()
    }

    /// Центрируем индикатор загрузки по экрану
    func setupActivityIndicator() {
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    /// Пересчитываем отступы и высоту панели при смене safe area
    func updateBottomAreaLayoutIfNeeded() {
        let safeBottom = view.safeAreaInsets.bottom
        let desiredHeight = 56 + safeBottom
        if lastSafeAreaBottomInset == safeBottom,
           bottomBarHeightConstraint?.constant == desiredHeight {
            return
        }

        lastSafeAreaBottomInset = safeBottom
        bottomBarHeightConstraint?.constant = desiredHeight
        bottomFadeHeightConstraint?.constant = desiredHeight + 48

        bottomBar.contentView.layoutMargins = UIEdgeInsets(
            top: 12,
            left: 20,
            bottom: max(12, safeBottom + 8),
            right: 20
        )

        var contentInset = tableView.contentInset
        if contentInset.bottom != desiredHeight + 32 {
            contentInset.bottom = desiredHeight + 32
            tableView.contentInset = contentInset
        }

        var indicatorInsets = tableView.verticalScrollIndicatorInsets
        if indicatorInsets.bottom != desiredHeight {
            indicatorInsets.bottom = desiredHeight
            tableView.verticalScrollIndicatorInsets = indicatorInsets
        }
    }
}

// Экранируем ответы презентера и обновляем UI
extension TodoListViewController: TodoListViewProtocol {
    func setNavigationTitle(_ title: String) {
        titleLabel.text = title
    }

    func showLoading(_ isLoading: Bool) {
        if isLoading {
            if !refreshControl.isRefreshing {
                activityIndicator.startAnimating()
            }
        } else {
            activityIndicator.stopAnimating()
            if refreshControl.isRefreshing {
                refreshControl.endRefreshing()
            }
        }
    }

    func showTodos(_ viewModels: [TodoListItemViewModel]) {
        self.viewModels = viewModels
        emptyStateLabel.isHidden = true
        tableView.isHidden = false
        updateTasksCount()
        tableView.reloadData()
        suppressSelectionForRow = nil
    }

    func showEmptyState(message: String) {
        emptyStateLabel.isHidden = false
        emptyStateLabel.text = message
        tableView.isHidden = true
        viewModels = []
        updateTasksCount()
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func showContextMenu(for viewModel: TodoContextMenuViewModel) {
        guard contextMenuController == nil else { return }
        let anchorRect = pendingContextMenuAnchorRect ?? CGRect(
            x: view.bounds.midX - 1,
            y: view.bounds.midY - 1,
            width: 2,
            height: 2
        )
        pendingContextMenuAnchorRect = nil
        let controller = TodoContextMenuViewController(viewModel: viewModel, anchorRect: anchorRect)
        controller.modalPresentationStyle = .overFullScreen
        controller.onEdit = { [weak self] in
            self?.presenter.handleContextAction(.edit)
        }
        controller.onShare = { [weak self] in
            self?.presenter.handleContextAction(.share)
        }
        controller.onDelete = { [weak self] in
            self?.presenter.handleContextAction(.delete)
        }
        controller.onDismiss = { [weak self] in
            self?.contextMenuController = nil
            self?.pendingContextMenuAnchorRect = nil
            self?.presenter.contextMenuDidDisappear()
        }
        contextMenuController = controller
        present(controller, animated: true)
    }

    func dismissContextMenu() {
        contextMenuController?.dismiss(animated: true)
        contextMenuController = nil
        pendingContextMenuAnchorRect = nil
        presenter.contextMenuDidDisappear()
    }

    func share(text: String) {
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(controller, animated: true)
    }
}

// Источник данных таблицы задач
extension TodoListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TodoListTableViewCell.reuseIdentifier, for: indexPath) as? TodoListTableViewCell else {
            return UITableViewCell()
        }
        guard viewModels.indices.contains(indexPath.row) else {
            return cell
        }
        cell.configure(with: viewModels[indexPath.row])
        cell.setToggleHandler { [weak self, weak cell, weak tableView] in
            guard
                let self = self,
                let tableView = tableView,
                let cell = cell,
                let indexPath = tableView.indexPath(for: cell),
                self.viewModels.indices.contains(indexPath.row)
            else {
                return
            }
            self.suppressSelectionForRow = indexPath
            self.presenter.didToggleCompletion(at: indexPath.row)
            DispatchQueue.main.async { [weak self] in
                self?.suppressSelectionForRow = nil
            }
        }
        attachLongPress(to: cell)
        return cell
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard viewModels.indices.contains(indexPath.row) else {
            return nil
        }
        let model = viewModels[indexPath.row]
        let toggleAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, completion in
            self?.presenter.didToggleCompletion(at: indexPath.row)
            completion(true)
        }
        toggleAction.backgroundColor = UIColor.appYellow.withAlphaComponent(0.85)
        toggleAction.image = UIImage(systemName: model.isCompleted ? "arrow.uturn.backward" : "checkmark")

        let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
            self?.presenter.didDeleteItem(at: indexPath.row)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")

        return UISwipeActionsConfiguration(actions: [deleteAction, toggleAction])
    }

    private func attachLongPress(to cell: UITableViewCell) {
        let hasRecognizer = cell.gestureRecognizers?.contains { $0 is UILongPressGestureRecognizer } ?? false
        guard !hasRecognizer else { return }
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        recognizer.minimumPressDuration = 0.4
        cell.addGestureRecognizer(recognizer)
    }

    @objc
    private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began,
              let cell = recognizer.view as? UITableViewCell,
              let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        let rowRect = tableView.rectForRow(at: indexPath)
        let convertedRect = tableView.convert(rowRect, to: view)
        pendingContextMenuAnchorRect = convertedRect
        presenter.didLongPressItem(at: indexPath.row)
    }
}

// Делегат таблицы: выбранные строки, свайпы и жесты
extension TodoListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if suppressSelectionForRow == indexPath {
            suppressSelectionForRow = nil
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        guard viewModels.indices.contains(indexPath.row) else { return }
        presenter.didSelectItem(at: indexPath.row)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let todoCell = cell as? TodoListTableViewCell else { return }
        let isLastRow = indexPath.row == viewModels.count - 1
        todoCell.setShowsSeparator(!isLastRow)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        searchTextField.resignFirstResponder()
    }

    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        false
    }

    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        false
    }

    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        // Intentionally left empty to disable system menu.
    }

    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        nil
    }
}

#if DEBUG
extension TodoListViewController {
    func setAudioEngineForTests(_ engine: AudioEngineProtocol) {
        audioEngine = engine
    }

    func setRecognitionTaskForTests(_ task: SpeechRecognitionTaskProtocol?) {
        recognitionTask = task
    }

    func setRecognitionRequestForTests(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        recognitionRequest = request
    }

    func setListeningStateForTests(_ listening: Bool) {
        isListening = listening
    }

    func setAudioTapInstalledForTests(_ value: Bool) {
        isAudioTapInstalled = value
    }

    func setLastRecognizedTextForTests(_ text: String?) {
        lastRecognizedText = text
    }

    func setSpeechRecognizerForTests(_ recognizer: SpeechRecognizerProtocol?) {
        speechRecognizer = recognizer
    }

    var isListeningForTests: Bool {
        isListening
    }

    var lastRecognizedTextForTests: String? {
        lastRecognizedText
    }

    var suppressSelectionForRowForTests: IndexPath? {
        suppressSelectionForRow
    }
}
#endif

// Делегат текстового поля поиска
extension TodoListViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        presenter.updateSearchQuery(textField.text ?? "")
        return true
    }
}

// Обработчики пользовательских действий и вспомогательные методы
@MainActor
extension TodoListViewController {
    @objc
    private func addButtonTapped() {
        presenter.didTapAdd()
    }

    @objc
    private func refreshTriggered() {
        presenter.didPullToRefresh()
    }

    @objc
    private func searchTextDidChange(_ textField: UITextField) {
        presenter.updateSearchQuery(textField.text ?? "")
        updateTasksCount()
    }

    private func updateTasksCount() {
        let count = viewModels.count
        let suffix: String
        switch count % 100 {
        case 11...14:
            suffix = "задач"
        default:
            switch count % 10 {
            case 1: suffix = "задача"
            case 2...4: suffix = "задачи"
            default: suffix = "задач"
            }
        }
        let formattedSuffix = suffix.prefix(1).capitalized + suffix.dropFirst()
        tasksCountLabel.text = "\(count) \(formattedSuffix)"
    }

    @objc
    private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc
    private func voiceButtonTapped() {
        if isListening {
            stopVoiceRecognition()
        } else {
            requestSpeechAuthorizationAndStart()
        }
    }

    /// Запрашиваем разрешения и, если всё хорошо, стартуем диктовку
    @objc
    func requestSpeechAuthorizationAndStart() {
        let audioSession = audioSessionProvider()
        audioSession.requestRecordPermission { [weak self] granted in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard granted else {
                    self.presentPermissionAlert()
                    return
                }
                self.speechAuthorizationRequest { status in
                    DispatchQueue.main.async {
                        switch status {
                        case .authorized:
                            self.startVoiceRecognition()
                        case .denied, .restricted, .notDetermined:
                            self.presentPermissionAlert()
                        @unknown default:
                            self.presentPermissionAlert()
                        }
                    }
                }
            }
        }
    }

    /// Полностью конфигурируем движок распознавания речи
    @objc
    func startVoiceRecognition() {
        if speechRecognizer == nil {
            speechRecognizer = speechRecognizerFactory()
        }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            presentErrorAlert(message: "Голосовой ввод недоступен.")
            return
        }

        stopVoiceRecognition()
        lastRecognizedText = searchTextField.text

        do {
            let audioSession = audioSessionProvider()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            presentErrorAlert(message: "Не удалось активировать микрофон: \(error.localizedDescription)")
            return
        }

        recognitionRequest = recognitionRequestFactory()
        guard let recognitionRequest = recognitionRequest else {
            presentErrorAlert(message: "Не удалось подготовить голосовой ввод.")
            return
        }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNodeWrapper
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        isAudioTapInstalled = false
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        isAudioTapInstalled = true

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            presentErrorAlert(message: "Не удалось запустить запись: \(error.localizedDescription)")
            audioEngine.stop()
            if isAudioTapInstalled {
                inputNode.removeTap(onBus: 0)
                isAudioTapInstalled = false
            }
            return
        }

        searchTextField.becomeFirstResponder()
        isListening = true
        updateVoiceButtonAppearance()

        recognitionTask = recognitionTaskFactory(recognizer, recognitionRequest) { [weak self] recognizedText, isFinal, error in
            guard let self = self else { return }
            if let recognizedText {
                DispatchQueue.main.async {
                    self.handleRecognizedText(recognizedText)
                }
            }

            if error != nil || isFinal {
                DispatchQueue.main.async {
                    self.stopVoiceRecognition()
                }
            }
        }
    }

    /// Останавливаем запись и восстанавливаем текст в поиске
    @objc
    func stopVoiceRecognition() {
        guard isListening || recognitionTask != nil else { return }
        let currentFieldText = searchTextField.text
        audioEngine.stop()
        if isAudioTapInstalled {
            audioEngine.inputNodeWrapper.removeTap(onBus: 0)
            isAudioTapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        do {
            try audioSessionProvider().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // ignore
        }
        isListening = false
        updateVoiceButtonAppearance()

        let normalizedStored = lastRecognizedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCurrent = currentFieldText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalText = normalizedStored?.isEmpty == false ? (lastRecognizedText ?? "")
            : normalizedCurrent?.isEmpty == false ? (currentFieldText ?? "")
            : ""

        if searchTextField.text != finalText {
            searchTextField.text = finalText
        }
        presenter.updateSearchQuery(finalText)
        lastRecognizedText = finalText.isEmpty ? nil : finalText
    }

    /// Синхронизируем визуальное состояние кнопки со статусом записи
    @objc
    func updateVoiceButtonAppearance() {
        UIView.animate(withDuration: 0.2) {
            if self.isListening {
                self.voiceButton.tintColor = .appYellow
                self.voiceButton.backgroundColor = UIColor.appYellow.withAlphaComponent(0.12)
                self.voiceButton.layer.cornerRadius = 12
            } else {
                self.voiceButton.tintColor = UIColor.appWhite.withAlphaComponent(0.5)
                self.voiceButton.backgroundColor = .clear
                self.voiceButton.layer.cornerRadius = 0
            }
        }
    }

    /// Показываем alert с подсказкой про разрешения
    @objc
    func presentPermissionAlert() {
        let alert = UIAlertController(
            title: "Нет доступа",
            message: "Разрешите приложению использовать микрофон и распознавание речи в настройках.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    /// Общее всплывающее окно для ошибок речевого ввода
    @objc
    func presentErrorAlert(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @MainActor
    func handleRecognizedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastRecognizedText = text
        searchTextField.text = text
        presenter.updateSearchQuery(text)
    }
}

