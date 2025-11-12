//
//  MockTodoAPIClient.swift
//  To-DoTests
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation
@testable import To_Do

/// Протокольная заглушка API клиента, фиксирующая обращения и управляемый результат
final class MockTodoAPIClient: TodoAPIClientProtocol {
    var result: Result<[TodoDTO], Error> = .success([])
    private(set) var fetchCallCount = 0

    func fetchTodos(completion: @escaping (Result<[TodoDTO], Error>) -> Void) {
        fetchCallCount += 1
        completion(result)
    }

    func reset() {
        fetchCallCount = 0
        result = .success([])
    }
}

