//
//  TodoContextMenuViewModel.swift
//  To-Do
//
//  Created by Anton Solovev on 15.07.2023.
//

import Foundation

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


