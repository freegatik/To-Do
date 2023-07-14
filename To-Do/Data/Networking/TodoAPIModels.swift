//
//  TodoAPIModels.swift
//  To-Do
//
//  Created by Anton Solovev on 09.07.2023.
//

import Foundation

struct TodoResponseDTO: Decodable, Sendable {
    let todos: [TodoDTO]
}

struct TodoDTO: Decodable, Sendable {
    let id: Int
    let todo: String
    let completed: Bool
    let userId: Int
}

