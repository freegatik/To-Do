//
//  TodoListViewController.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import UIKit

/// Контроллер, который показывает список задач
final class TodoListViewController: UIViewController {
    var presenter: TodoListPresenterProtocol!

    private var viewModels: [TodoListItemViewModel] = []
    private var contextMenuController: TodoContextMenuViewController?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = .appWhite
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let searchContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .appGray
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let searchIconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        imageView.tintColor = UIColor.appWhite.withAlphaComponent(0.5)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let microphoneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        button.tintColor = UIColor.appWhite.withAlphaComponent(0.5)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isUserInteractionEnabled = false
        return button
    }()

    private let searchTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textColor = .appWhite
        textField.attributedPlaceholder = NSAttributedString(
            string: "Search",
            attributes: [.foregroundColor: UIColor.appWhite.withAlphaComponent(0.5)]
        )
        textField.tintColor = .appYellow
        textField.returnKeyType = .search
        textField.accessibilityIdentifier = "todoList.searchField"
        return textField
    }()

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .appBlack
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        return tableView
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = UIColor.appWhite.withAlphaComponent(0.6)
        label.font = .systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private let bottomBarBackground: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 0
        view.clipsToBounds = true
        return view
    }()

    private let tasksCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .appWhite
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        button.tintColor = .appYellow
        button.accessibilityIdentifier = "todoList.addButton"
        return button
    }()

    private let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupUI()
        presenter.viewDidLoad()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
}

// MARK: - Настройка

private extension TodoListViewController {
    func setupUI() {
        view.backgroundColor = .appBlack
        setupHeader()
        setupSearch()
        setupTableView()
        setupEmptyStateLabel()
        setupBottomBar()
        setupActivityIndicator()
    }

    func setupHeader() {
        view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }

    func setupSearch() {
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextDidChange), for: .editingChanged)
        searchTextField.accessibilityIdentifier = "todoList.searchBar"

        view.addSubview(searchContainerView)
        searchContainerView.addSubview(searchIconView)
        searchContainerView.addSubview(searchTextField)
        searchContainerView.addSubview(microphoneButton)

        NSLayoutConstraint.activate([
            searchContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            searchContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            searchContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            searchContainerView.heightAnchor.constraint(equalToConstant: 36),

            searchIconView.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: 8),
            searchIconView.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            searchIconView.widthAnchor.constraint(equalToConstant: 18),
            searchIconView.heightAnchor.constraint(equalToConstant: 18),

            microphoneButton.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -8),
            microphoneButton.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            microphoneButton.widthAnchor.constraint(equalToConstant: 20),
            microphoneButton.heightAnchor.constraint(equalToConstant: 20),

            searchTextField.leadingAnchor.constraint(equalTo: searchIconView.trailingAnchor, constant: 6),
            searchTextField.trailingAnchor.constraint(equalTo: microphoneButton.leadingAnchor, constant: -8),
            searchTextField.topAnchor.constraint(equalTo: searchContainerView.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchContainerView.bottomAnchor)
        ])
    }

    func setupTableView() {
        tableView.register(TodoListTableViewCell.self, forCellReuseIdentifier: TodoListTableViewCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.refreshControl = refreshControl
        tableView.accessibilityIdentifier = "todoList.table"
        refreshControl.tintColor = .appYellow
        refreshControl.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 100, right: 0)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 88
        tableView.tableFooterView = UIView()

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchContainerView.bottomAnchor, constant: 24),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func setupEmptyStateLabel() {
        emptyStateLabel.accessibilityIdentifier = "todoList.emptyState"
        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func setupBottomBar() {
        view.addSubview(bottomBarBackground)
        bottomBarBackground.contentView.addSubview(tasksCountLabel)
        bottomBarBackground.contentView.addSubview(addButton)
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            bottomBarBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBarBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBarBackground.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomBarBackground.heightAnchor.constraint(equalToConstant: 56),

            tasksCountLabel.centerXAnchor.constraint(equalTo: bottomBarBackground.contentView.centerXAnchor),
            tasksCountLabel.centerYAnchor.constraint(equalTo: bottomBarBackground.contentView.centerYAnchor),

            addButton.centerYAnchor.constraint(equalTo: bottomBarBackground.contentView.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: bottomBarBackground.contentView.trailingAnchor, constant: -24),
            addButton.widthAnchor.constraint(equalToConstant: 32),
            addButton.heightAnchor.constraint(equalToConstant: 32)
        ])

        updateTasksCount()
    }

    func setupActivityIndicator() {
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc
    func addButtonTapped() {
        presenter.didTapAdd()
    }

    @objc
    func refreshTriggered() {
        presenter.didPullToRefresh()
    }

    @objc
    func searchTextDidChange() {
        presenter.updateSearchQuery(searchTextField.text ?? "")
    }

    func updateTasksCount() {
        let count = viewModels.count
        let suffix: String
        switch count {
        case 1:
            suffix = "Задача"
        case 2...4:
            suffix = "Задачи"
        default:
            suffix = "Задач"
        }
        tasksCountLabel.text = "\(count) \(suffix)"
    }
}

// MARK: - Реализация TodoListViewProtocol

extension TodoListViewController: TodoListViewProtocol {
    func setNavigationTitle(_ title: String) {
        titleLabel.text = title
    }

    func showLoading(_ isLoading: Bool) {
        if isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
            refreshControl.endRefreshing()
        }
    }

    func showTodos(_ viewModels: [TodoListItemViewModel]) {
        emptyStateLabel.isHidden = true
        tableView.isHidden = false
        self.viewModels = viewModels
        updateTasksCount()
        tableView.reloadData()
    }

    func showEmptyState(message: String) {
        emptyStateLabel.isHidden = false
        emptyStateLabel.text = message
        tableView.isHidden = true
        viewModels = []
        updateTasksCount()
        tableView.reloadData()
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func showContextMenu(for viewModel: TodoContextMenuViewModel) {
        guard contextMenuController == nil else { return }
        let controller = TodoContextMenuViewController(viewModel: viewModel)
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
            self?.presenter.contextMenuDidDisappear()
        }
        contextMenuController = controller
        present(controller, animated: true)
    }

    func dismissContextMenu() {
        contextMenuController?.dismiss(animated: true)
        contextMenuController = nil
        presenter.contextMenuDidDisappear()
    }

    func share(text: String) {
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(controller, animated: true)
    }
}

// MARK: - Источник данных таблицы

extension TodoListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: TodoListTableViewCell.reuseIdentifier,
            for: indexPath
        ) as? TodoListTableViewCell else {
            return UITableViewCell()
        }
        cell.configure(with: viewModels[indexPath.row])
        attachLongPress(to: cell)
        return cell
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let model = viewModels[indexPath.row]
        let toggleAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, completion in
            self?.presenter.didToggleCompletion(at: indexPath.row)
            completion(true)
        }
        toggleAction.backgroundColor = UIColor.appYellow.withAlphaComponent(0.8)
        let toggleImageName = model.isCompleted ? "arrow.uturn.backward" : "checkmark"
        toggleAction.image = UIImage(systemName: toggleImageName)

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
        presenter.didLongPressItem(at: indexPath.row)
    }
}

// MARK: - Делегат таблицы

extension TodoListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.didSelectItem(at: indexPath.row)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        searchTextField.resignFirstResponder()
    }
}

// MARK: - UITextFieldDelegate

extension TodoListViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        presenter.updateSearchQuery(textField.text ?? "")
        return true
    }
}

