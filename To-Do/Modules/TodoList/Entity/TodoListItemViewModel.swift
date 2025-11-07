//
//  TodoListItemViewModel.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation

/// View-модель одной строки списка
struct TodoListItemViewModel {
    let id: Int64
    let title: String
    let details: String?
    let date: String
    let isCompleted: Bool
}

