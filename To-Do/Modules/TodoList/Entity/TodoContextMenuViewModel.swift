//
//  TodoContextMenuViewModel.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation

/// Данные для контекстного меню задачи
struct TodoContextMenuViewModel {
    let title: String
    let details: String?
    let date: String
    let isCompleted: Bool
}

enum TodoContextAction {
    case edit
    case share
    case delete
}


