//
//  TodoAPIClient.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation

/// Простой клиент для загрузки задач
protocol TodoAPIClientProtocol {
    /// Грузим задачи и отдаём в completion
    func fetchTodos(completion: @escaping (Result<[TodoDTO], Error>) -> Void)
}

/// Реализация на `URLSession`
final class TodoAPIClient: TodoAPIClientProtocol {
    private enum Constants {
        static let todosURL = URL(string: "https://dummyjson.com/todos")!
        static let backgroundQueue = DispatchQueue(label: "io.todo.api", qos: .userInitiated, attributes: .concurrent)
    }

    private let session: URLSession

    /// Можно передать свою `URLSession` для тестов
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Грузим JSON на фоне, проверяем статус и декодируем
    func fetchTodos(completion: @escaping (Result<[TodoDTO], Error>) -> Void) {
        Constants.backgroundQueue.async {
            let task = self.session.dataTask(with: Constants.todosURL) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }

                guard
                    let data,
                    let httpResponse = response as? HTTPURLResponse,
                    200..<300 ~= httpResponse.statusCode
                else {
                    let statusError = URLError(.badServerResponse)
                    DispatchQueue.main.async {
                        completion(.failure(statusError))
                    }
                    return
                }

                DispatchQueue.main.async {
                    do {
                        let result = try JSONDecoder().decode(TodoResponseDTO.self, from: data)
                        completion(.success(result.todos))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }

            task.resume()
        }
    }
}

