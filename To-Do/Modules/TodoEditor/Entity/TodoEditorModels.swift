//
//  TodoEditorModels.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation

/// Режим работы редактора: создаём или редактируем задачу
enum TodoEditorMode {
    case create
    case edit(TodoItem)
}

/// Чем закончилась работа редактора
enum TodoEditorResult {
    case created(TodoItem)
    case updated(TodoItem)
    case cancelled
}

/// View‑модель, описывающая состояние экрана редактирования.
struct TodoEditorViewModel {
    let title: String
    let details: String
    let isCompleted: Bool
    let createdAtText: String?
    let actionButtonTitle: String
}

/// Обратная связь для модуля списка после закрытия редактора.
protocol TodoEditorModuleOutput: AnyObject {
    func todoEditorDidFinish(with result: TodoEditorResult)
}

