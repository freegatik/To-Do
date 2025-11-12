//
//  TodoItem.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation

/// Простая модель задачи без привязки к UI
struct TodoItem: Identifiable, Equatable {
    let id: Int64
    var title: String
    var details: String?
    let createdAt: Date
    var isCompleted: Bool

    /// Создаём задачу вручную
    init(
        id: Int64,
        title: String,
        details: String?,
        createdAt: Date,
        isCompleted: Bool
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.createdAt = createdAt
        self.isCompleted = isCompleted
    }

    /// Переводим DTO из сети в модель
    init(dto: TodoDTO, createdAt: Date = Date()) {
        self.init(
            id: Int64(dto.id),
            title: dto.todo.trimmingCharacters(in: .whitespacesAndNewlines),
            details: dto.completed ? "Completed task from user \(dto.userId)" : nil,
            createdAt: createdAt,
            isCompleted: dto.completed
        )
    }
}

