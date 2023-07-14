//
//  TodoEntity+CoreData.swift
//  To-Do
//
//  Created by Anton Solovev on 07.07.2023.
//

import Foundation
import CoreData

extension TodoEntity {
    func update(with item: TodoItem) {
        id = item.id
        title = item.title
        details = item.details
        createdAt = item.createdAt
        isCompleted = item.isCompleted
    }

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

