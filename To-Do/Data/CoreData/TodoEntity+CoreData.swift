//
//  TodoEntity+CoreData.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation
import CoreData

/// Помощь при переводе между Core Data и моделью
extension TodoEntity {
    /// Копируем значения из модели в Core Data
    func update(with item: TodoItem) {
        id = item.id
        title = item.title
        details = item.details
        createdAt = item.createdAt
        isCompleted = item.isCompleted
    }

    /// Собираем `TodoItem`, если поля заполнены
    func asItem() -> TodoItem? {
        guard
            let title,
            let createdAt
        else {
            return nil
        }

        return TodoItem(
            id: id,
            title: title,
            details: details,
            createdAt: createdAt,
            isCompleted: isCompleted
        )
    }
}

