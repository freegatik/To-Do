//
//  TodoEditorModels.swift
//  To-Do
//
//  Created by Anton Solovev on 23.07.2023.
//

import Foundation

enum TodoEditorMode {
    case create
    case edit(TodoItem)
}

enum TodoEditorResult {
    case created(TodoItem)
    case updated(TodoItem)
    case cancelled
}

struct TodoEditorViewModel {
    let title: String
    let details: String
    let isCompleted: Bool
    let createdAtText: String?
}

@MainActor
protocol TodoEditorModuleOutput: AnyObject {
    func todoEditorDidFinish(with result: TodoEditorResult)
}

