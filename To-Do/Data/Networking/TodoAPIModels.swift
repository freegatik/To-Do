//
//  TodoAPIModels.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation

/// Обёртка ответа от dummyjson
struct TodoResponseDTO: Decodable, Sendable {
    let todos: [TodoDTO]
}

/// Сырые данные задачи из API
struct TodoDTO: Decodable, Sendable {
    let id: Int
    let todo: String
    let completed: Bool
    let userId: Int
}

