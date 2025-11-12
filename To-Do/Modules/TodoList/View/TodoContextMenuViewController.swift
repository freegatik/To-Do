//
//  TodoContextMenuViewController.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import UIKit

/// Контекстное меню задачи по макету Figma
final class TodoContextMenuViewController: UIViewController {
    var onEdit: (() -> Void)?
    var onShare: (() -> Void)?
    var onDelete: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let viewModel: TodoContextMenuViewModel
    private let anchorRect: CGRect
    private var topConstraint: NSLayoutConstraint!
    private var centerXConstraint: NSLayoutConstraint!
    private var isPerformingAction = false

    private let dimView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.appBlack.withAlphaComponent(0.5)
        view.contentView.backgroundColor = .clear
        view.alpha = 0
        view.isUserInteractionEnabled = true
        return view
    }()

    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        return stack
    }()

    private let taskCard: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.appGray
        view.layer.cornerRadius = 12
        view.layer.cornerCurve = .continuous
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.35).cgColor
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = 16
        view.layer.shadowOffset = CGSize(width: 0, height: 12)
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let actionsContainer: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemChromeMaterialLight)
        let container = UIVisualEffectView(effect: effect)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 12
        container.layer.cornerCurve = .continuous
        container.clipsToBounds = true
        container.contentView.backgroundColor = UIColor(white: 237 / 255, alpha: 0.8)
        return container
    }()

    private let actionsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0
        return stack
    }()

    init(viewModel: TodoContextMenuViewModel, anchorRect: CGRect) {
        self.viewModel = viewModel
        self.anchorRect = anchorRect
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
        animatePresentation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreferredPosition()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !isPerformingAction {
            onDismiss?()
        }
    }
}

// Построение интерфейса и применение view model
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
        containerStack.spacing = 10
        containerStack.addArrangedSubview(taskCard)
        containerStack.addArrangedSubview(actionsContainer)
        actionsContainer.contentView.addSubview(actionsStack)
        taskCard.addSubview(titleLabel)
        taskCard.addSubview(detailsLabel)
        taskCard.addSubview(dateLabel)

        let fittedCardWidth = min(anchorRect.width, view.bounds.width - 32)
        let cardWidth = taskCard.widthAnchor.constraint(equalToConstant: fittedCardWidth)
        cardWidth.priority = UILayoutPriority(750)
        let actionsWidth = actionsContainer.widthAnchor.constraint(equalTo: taskCard.widthAnchor)
        actionsWidth.priority = UILayoutPriority(750)

        topConstraint = containerStack.topAnchor.constraint(equalTo: view.topAnchor)
        centerXConstraint = containerStack.centerXAnchor.constraint(equalTo: view.leadingAnchor)

        actionsContainer.contentView.layoutMargins = .zero
        let leadingConstraint = containerStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20)
        leadingConstraint.priority = UILayoutPriority(750)
        let trailingConstraint = containerStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        trailingConstraint.priority = UILayoutPriority(750)

        NSLayoutConstraint.activate([
            topConstraint,
            centerXConstraint,
            leadingConstraint,
            trailingConstraint,

            cardWidth,
            taskCard.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),

            actionsWidth,
            actionsContainer.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -72),

            actionsStack.leadingAnchor.constraint(equalTo: actionsContainer.contentView.leadingAnchor),
            actionsStack.trailingAnchor.constraint(equalTo: actionsContainer.contentView.trailingAnchor),
            actionsStack.topAnchor.constraint(equalTo: actionsContainer.contentView.topAnchor),
            actionsStack.bottomAnchor.constraint(equalTo: actionsContainer.contentView.bottomAnchor)
        ])

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: taskCard.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: taskCard.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: taskCard.trailingAnchor, constant: -18),

            detailsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            detailsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailsLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            dateLabel.topAnchor.constraint(equalTo: detailsLabel.bottomAnchor, constant: 10),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: taskCard.bottomAnchor, constant: -14)
        ])

        let actions: [MenuActionConfiguration] = [
            .init(
                title: "Редактировать",
                icon: .edit,
                textColor: UIColor.appBlack,
                iconTint: UIColor.appBlack,
                showsSeparator: true,
                selector: #selector(handleEdit),
                accessibilityIdentifier: "context.edit"
            ),
            .init(
                title: "Поделиться",
                icon: .share,
                textColor: UIColor.appBlack,
                iconTint: UIColor.appBlack,
                showsSeparator: true,
                selector: #selector(handleShare),
                accessibilityIdentifier: "context.share"
            ),
            .init(
                title: "Удалить",
                icon: .delete,
                textColor: UIColor.appRed,
                iconTint: UIColor.appRed,
                showsSeparator: false,
                selector: #selector(handleDelete),
                accessibilityIdentifier: "context.delete"
            )
        ]

        actions.forEach { configuration in
            let button = MenuActionButton(configuration: configuration)
            button.addTarget(self, action: configuration.selector, for: .touchUpInside)
            button.accessibilityIdentifier = configuration.accessibilityIdentifier
            actionsStack.addArrangedSubview(button)
        }

        centerXConstraint.constant = anchorRect.midX
        topConstraint.constant = anchorRect.minY
    }

    /// Настраиваем содержимое карточки и экшены по данным модели
    func applyViewModel() {
        titleLabel.attributedText = ContextMenuTypography.title(
            text: viewModel.title,
            isCompleted: viewModel.isCompleted
        )

        if let details = viewModel.details, !details.isEmpty {
            detailsLabel.attributedText = ContextMenuTypography.details(
                text: details,
                isCompleted: viewModel.isCompleted
            )
            detailsLabel.isHidden = false
        } else {
            detailsLabel.attributedText = nil
            detailsLabel.isHidden = true
        }

        dateLabel.attributedText = ContextMenuTypography.date(
            text: viewModel.date,
            isCompleted: viewModel.isCompleted
        )

        taskCard.layer.shadowOpacity = viewModel.isCompleted ? 0 : 1
    }

    /// Мягкая анимация появления меню и затемнения
    func animatePresentation() {
        containerStack.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        containerStack.alpha = 0

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            self.dimView.alpha = 1
            self.containerStack.alpha = 1
            self.containerStack.transform = .identity
        }
    }
}

// Обработка пользовательских событий и пересчёт позиций меню
private extension TodoContextMenuViewController {

    @objc
    /// Скрываем меню по тапу по затемнению
    func handleBackgroundTap() {
        dismiss(animated: true)
    }

    @objc
    /// Пробрасываем редактирование в координатор и закрываем контроллер
    func handleEdit() {
        performAndDismiss { [weak self] in
            self?.onEdit?()
        }
    }

    @objc
    /// Показываем системный share sheet с данными задачи
    func handleShare() {
        performAndDismiss { [weak self] in
            self?.onShare?()
        }
    }

    @objc
    /// Удаляем задачу из списка через презентер
    func handleDelete() {
        performAndDismiss { [weak self] in
            self?.onDelete?()
        }
    }

    /// Вычисляем финальное положение относительно anchorRect
    func updatePreferredPosition() {
        let safeInsets = view.safeAreaInsets
        let maxWidth = view.bounds.width - (safeInsets.left + safeInsets.right) - 40
        let fittingWidth = maxWidth > 0 ? maxWidth : view.bounds.width
        let targetSize = containerStack.systemLayoutSizeFitting(
            CGSize(width: fittingWidth, height: UIView.layoutFittingCompressedSize.height)
        )
        let halfWidth = min(targetSize.width, fittingWidth) / 2

        var centerX = anchorRect.midX
        let minCenterX = safeInsets.left + 20 + halfWidth
        let maxCenterX = view.bounds.width - safeInsets.right - 20 - halfWidth
        centerX = max(minCenterX, min(maxCenterX, centerX))
        centerXConstraint.constant = centerX

        let minTop = safeInsets.top + 16
        let maxTop = view.bounds.height - safeInsets.bottom - 16 - targetSize.height
        let desiredTop = anchorRect.minY
        let clampedTop = max(minTop, min(maxTop, desiredTop))
        topConstraint.constant = clampedTop
    }

    /// Выполняем действие и уведомляем об окончании по закрытию
    func performAndDismiss(action: @escaping () -> Void) {
        isPerformingAction = true
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            action()
            self.onDismiss?()
            self.isPerformingAction = false
        }
    }
}

// Конфигурация и представления кнопок контекстного меню
/// Параметры одной кнопки контекстного меню
private struct MenuActionConfiguration {
    let title: String
    let icon: MenuIcon
    let textColor: UIColor
    let iconTint: UIColor
    let showsSeparator: Bool
    let selector: Selector
    let accessibilityIdentifier: String
}

/// Типы иконок, доступные для действий меню
private enum MenuIcon {
    case edit
    case share
    case delete
}

/// Кнопка действия со встроенным разделителем и подсветкой
private final class MenuActionButton: UIButton {
    private let actionConfiguration: MenuActionConfiguration
    private let separatorView = UIView()

    init(configuration: MenuActionConfiguration) {
        self.actionConfiguration = configuration
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityLabel = configuration.title
        setupConfiguration()
        setupSeparator()
        setupHighlightHandler()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Формируем конфигурацию кнопки, чтобы шрифт и иконка совпадали с макетом
    private func setupConfiguration() {
        var buttonConfiguration = UIButton.Configuration.plain()
        buttonConfiguration.title = actionConfiguration.title
        buttonConfiguration.attributedTitle = AttributedString(
            actionConfiguration.title,
            attributes: AttributeContainer([
                .font: ContextMenuTypography.actionFont,
                .foregroundColor: actionConfiguration.textColor
            ])
        )
        buttonConfiguration.baseForegroundColor = actionConfiguration.textColor
        buttonConfiguration.titleAlignment = .leading
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 14)
        buttonConfiguration.imagePlacement = .trailing
        buttonConfiguration.imagePadding = 12
        buttonConfiguration.image = MenuIconFactory.image(
            for: actionConfiguration.icon,
            color: actionConfiguration.iconTint
        )
        buttonConfiguration.background.backgroundColor = .clear
        configuration = buttonConfiguration
        contentHorizontalAlignment = .leading
        let heightConstraint = heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        heightConstraint.priority = UILayoutPriority(750)
        heightConstraint.isActive = true
    }

    /// Добавляем нижний разделитель для многострочных меню
    private func setupSeparator() {
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = UIColor.appStroke.withAlphaComponent(0.5)
        separatorView.isUserInteractionEnabled = false
        addSubview(separatorView)
        NSLayoutConstraint.activate([
            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            separatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        separatorView.isHidden = !actionConfiguration.showsSeparator
    }

    /// Настраиваем подсветку при удержании кнопки
    private func setupHighlightHandler() {
        configurationUpdateHandler = { button in
            button.backgroundColor = button.isHighlighted
                ? UIColor.white.withAlphaComponent(0.12)
                : .clear
        }
    }
}

private enum ContextMenuTypography {
    private static let titleBaseFont = UIFont.systemFont(ofSize: 17, weight: .regular)
    private static let detailsBaseFont = UIFont.systemFont(ofSize: 13, weight: .regular)
    private static let dateBaseFont = UIFont.systemFont(ofSize: 13, weight: .regular)
    private static let actionBaseFont = UIFont.systemFont(ofSize: 16, weight: .regular)

    private static let titleFont = UIFontMetrics(forTextStyle: .headline).scaledFont(for: titleBaseFont)
    private static let detailsFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: detailsBaseFont)
    private static let dateFont = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: dateBaseFont)
    static let actionFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: actionBaseFont)

    private static let titleActiveColor = UIColor.appWhite.withAlphaComponent(0.94)
    private static let titleCompletedColor = UIColor.appWhite.withAlphaComponent(0.55)
    private static let detailsActiveColor = UIColor.appWhite.withAlphaComponent(0.72)
    private static let detailsCompletedColor = UIColor.appWhite.withAlphaComponent(0.58)
    private static let dateActiveColor = UIColor.appWhite.withAlphaComponent(0.55)
    private static let dateCompletedColor = UIColor.appWhite.withAlphaComponent(0.45)

    static func title(text: String, isCompleted: Bool) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 22
        paragraph.maximumLineHeight = 22
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: isCompleted ? titleCompletedColor : titleActiveColor,
            .paragraphStyle: paragraph
        ]

        let attributed = NSMutableAttributedString(string: text, attributes: attributes)
        if isCompleted {
            attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attributed.length))
        }
        return attributed
    }

    static func details(text: String, isCompleted: Bool) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 19
        paragraph.maximumLineHeight = 19
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: detailsFont,
            .foregroundColor: isCompleted ? detailsCompletedColor : detailsActiveColor,
            .paragraphStyle: paragraph
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    static func date(text: String, isCompleted: Bool) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 18
        paragraph.maximumLineHeight = 18
        paragraph.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: isCompleted ? dateCompletedColor : dateActiveColor,
            .paragraphStyle: paragraph
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }
}

private enum MenuIconFactory {
    static func image(for icon: MenuIcon, color: UIColor) -> UIImage {
        let size = CGSize(width: 16, height: 16)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = UIScreen.main.scale

        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let ctx = rendererContext.cgContext
            ctx.saveGState()
            ctx.setAllowsAntialiasing(true)
            ctx.setShouldAntialias(true)
            ctx.setStrokeColor(color.cgColor)
            ctx.setFillColor(color.cgColor)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            switch icon {
            case .edit:
                drawEditIcon(in: ctx)
            case .share:
                drawShareIcon(in: ctx)
            case .delete:
                drawDeleteIcon(in: ctx, color: color)
            }

            ctx.restoreGState()
        }
    }

    private static func drawEditIcon(in context: CGContext) {
        let framePath = UIBezierPath()
        framePath.move(to: CGPoint(x: 7.333, y: 1.333))
        framePath.addLine(to: CGPoint(x: 6.0, y: 1.333))
        framePath.addCurve(
            to: CGPoint(x: 1.333, y: 6.0),
            controlPoint1: CGPoint(x: 2.667, y: 1.333),
            controlPoint2: CGPoint(x: 1.333, y: 2.667)
        )
        framePath.addLine(to: CGPoint(x: 1.333, y: 10.0))
        framePath.addCurve(
            to: CGPoint(x: 6.0, y: 14.667),
            controlPoint1: CGPoint(x: 1.333, y: 13.333),
            controlPoint2: CGPoint(x: 2.667, y: 14.667)
        )
        framePath.addLine(to: CGPoint(x: 10.0, y: 14.667))
        framePath.addCurve(
            to: CGPoint(x: 14.667, y: 10.0),
            controlPoint1: CGPoint(x: 13.333, y: 14.667),
            controlPoint2: CGPoint(x: 14.667, y: 13.333)
        )
        framePath.addLine(to: CGPoint(x: 14.667, y: 8.667))
        context.setLineWidth(1.2)
        context.addPath(framePath.cgPath)
        context.strokePath()

        let pencilPath = UIBezierPath()
        pencilPath.move(to: CGPoint(x: 10.693, y: 2.013))
        pencilPath.addLine(to: CGPoint(x: 5.440, y: 7.267))
        pencilPath.addCurve(
            to: CGPoint(x: 5.000, y: 8.147),
            controlPoint1: CGPoint(x: 5.240, y: 7.467),
            controlPoint2: CGPoint(x: 5.040, y: 7.860)
        )
        pencilPath.addLine(to: CGPoint(x: 4.713, y: 10.153))
        pencilPath.addCurve(
            to: CGPoint(x: 5.847, y: 11.287),
            controlPoint1: CGPoint(x: 4.607, y: 10.880),
            controlPoint2: CGPoint(x: 5.120, y: 11.387)
        )
        pencilPath.addLine(to: CGPoint(x: 7.853, y: 11.000))
        pencilPath.addCurve(
            to: CGPoint(x: 8.733, y: 10.560),
            controlPoint1: CGPoint(x: 8.133, y: 10.960),
            controlPoint2: CGPoint(x: 8.527, y: 10.760)
        )
        pencilPath.addLine(to: CGPoint(x: 13.987, y: 5.307))
        pencilPath.addCurve(
            to: CGPoint(x: 13.987, y: 2.013),
            controlPoint1: CGPoint(x: 14.893, y: 4.400),
            controlPoint2: CGPoint(x: 15.320, y: 3.347)
        )
        pencilPath.addCurve(
            to: CGPoint(x: 10.693, y: 2.013),
            controlPoint1: CGPoint(x: 12.653, y: 0.680),
            controlPoint2: CGPoint(x: 11.600, y: 1.107)
        )
        pencilPath.close()
        context.setLineWidth(1.2)
        context.addPath(pencilPath.cgPath)
        context.strokePath()

        let detailPath = UIBezierPath()
        detailPath.move(to: CGPoint(x: 9.940, y: 2.767))
        detailPath.addCurve(
            to: CGPoint(x: 13.233, y: 6.060),
            controlPoint1: CGPoint(x: 10.387, y: 4.360),
            controlPoint2: CGPoint(x: 11.633, y: 5.607)
        )
        context.setLineWidth(1.2)
        context.addPath(detailPath.cgPath)
        context.strokePath()
    }

    private static func drawShareIcon(in context: CGContext) {
        let basePath = UIBezierPath()
        basePath.move(to: CGPoint(x: 10.960, y: 5.933))
        basePath.addCurve(
            to: CGPoint(x: 14.340, y: 10.073),
            controlPoint1: CGPoint(x: 13.360, y: 6.140),
            controlPoint2: CGPoint(x: 14.340, y: 7.373)
        )
        basePath.addLine(to: CGPoint(x: 14.340, y: 10.160))
        basePath.addCurve(
            to: CGPoint(x: 10.167, y: 14.333),
            controlPoint1: CGPoint(x: 14.340, y: 13.140),
            controlPoint2: CGPoint(x: 13.147, y: 14.333)
        )
        basePath.addLine(to: CGPoint(x: 5.827, y: 14.333))
        basePath.addCurve(
            to: CGPoint(x: 1.653, y: 10.160),
            controlPoint1: CGPoint(x: 2.847, y: 14.333),
            controlPoint2: CGPoint(x: 1.653, y: 13.140)
        )
        basePath.addLine(to: CGPoint(x: 1.653, y: 10.073))
        basePath.addCurve(
            to: CGPoint(x: 4.980, y: 5.940),
            controlPoint1: CGPoint(x: 1.653, y: 7.393),
            controlPoint2: CGPoint(x: 2.620, y: 6.160)
        )
        context.setLineWidth(1.2)
        context.addPath(basePath.cgPath)
        context.strokePath()

        let stemPath = UIBezierPath()
        stemPath.move(to: CGPoint(x: 8.000, y: 10.000))
        stemPath.addLine(to: CGPoint(x: 8.000, y: 2.413))
        context.setLineWidth(1.2)
        context.addPath(stemPath.cgPath)
        context.strokePath()

        let arrowPath = UIBezierPath()
        arrowPath.move(to: CGPoint(x: 10.233, y: 3.900))
        arrowPath.addLine(to: CGPoint(x: 8.000, y: 1.667))
        arrowPath.addLine(to: CGPoint(x: 5.767, y: 3.900))
        context.setLineWidth(1.2)
        context.addPath(arrowPath.cgPath)
        context.strokePath()
    }

    private static func drawDeleteIcon(in context: CGContext, color: UIColor) {
        context.setStrokeColor(color.cgColor)

        let rimPath = UIBezierPath()
        rimPath.move(to: CGPoint(x: 14.000, y: 3.987))
        rimPath.addCurve(
            to: CGPoint(x: 7.320, y: 3.653),
            controlPoint1: CGPoint(x: 11.780, y: 3.767),
            controlPoint2: CGPoint(x: 9.547, y: 3.653)
        )
        rimPath.addCurve(
            to: CGPoint(x: 3.360, y: 3.853),
            controlPoint1: CGPoint(x: 6.000, y: 3.653),
            controlPoint2: CGPoint(x: 4.680, y: 3.720)
        )
        rimPath.addLine(to: CGPoint(x: 2.000, y: 3.987))
        context.setLineWidth(1.2)
        context.addPath(rimPath.cgPath)
        context.strokePath()

        let topPath = UIBezierPath()
        topPath.move(to: CGPoint(x: 5.667, y: 3.313))
        topPath.addLine(to: CGPoint(x: 5.813, y: 2.440))
        topPath.addCurve(
            to: CGPoint(x: 7.127, y: 1.333),
            controlPoint1: CGPoint(x: 5.920, y: 1.807),
            controlPoint2: CGPoint(x: 6.000, y: 1.333)
        )
        topPath.addLine(to: CGPoint(x: 8.873, y: 1.333))
        topPath.addCurve(
            to: CGPoint(x: 10.187, y: 2.447),
            controlPoint1: CGPoint(x: 10.000, y: 1.333),
            controlPoint2: CGPoint(x: 10.087, y: 1.833)
        )
        topPath.addLine(to: CGPoint(x: 10.333, y: 3.313))
        context.setLineWidth(1.2)
        context.addPath(topPath.cgPath)
        context.strokePath()

        let bodyPath = UIBezierPath()
        bodyPath.move(to: CGPoint(x: 12.567, y: 6.093))
        bodyPath.addLine(to: CGPoint(x: 12.133, y: 12.807))
        bodyPath.addCurve(
            to: CGPoint(x: 10.140, y: 14.667),
            controlPoint1: CGPoint(x: 12.060, y: 13.853),
            controlPoint2: CGPoint(x: 12.000, y: 14.667)
        )
        bodyPath.addLine(to: CGPoint(x: 5.860, y: 14.667))
        bodyPath.addCurve(
            to: CGPoint(x: 3.867, y: 12.807),
            controlPoint1: CGPoint(x: 4.000, y: 14.667),
            controlPoint2: CGPoint(x: 3.940, y: 13.853)
        )
        bodyPath.addLine(to: CGPoint(x: 3.433, y: 6.093))
        context.setLineWidth(1.2)
        context.addPath(bodyPath.cgPath)
        context.strokePath()

        let midPath = UIBezierPath()
        midPath.move(to: CGPoint(x: 6.887, y: 11.000))
        midPath.addLine(to: CGPoint(x: 9.107, y: 11.000))
        context.setLineWidth(1.2)
        context.addPath(midPath.cgPath)
        context.strokePath()

        let mid2Path = UIBezierPath()
        mid2Path.move(to: CGPoint(x: 6.333, y: 8.333))
        mid2Path.addLine(to: CGPoint(x: 9.667, y: 8.333))
        context.setLineWidth(1.2)
        context.addPath(mid2Path.cgPath)
        context.strokePath()
    }
}


