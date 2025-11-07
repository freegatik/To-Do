//
//  MockTodoAPIClient.swift
//  To-DoTests
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation
@testable import To_Do

final class MockTodoAPIClient: TodoAPIClientProtocol {
    var result: Result<[TodoDTO], Error> = .success([])

    func fetchTodos(completion: @escaping (Result<[TodoDTO], Error>) -> Void) {
        completion(result)
    }
}

