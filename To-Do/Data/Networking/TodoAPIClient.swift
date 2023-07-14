//
//  TodoAPIClient.swift
//  To-Do
//
//  Created by Anton Solovev on 10.07.2023.
//

import Foundation

protocol TodoAPIClientProtocol {
    func fetchTodos(completion: @escaping (Result<[TodoDTO], Error>) -> Void)
}

final class TodoAPIClient: TodoAPIClientProtocol {
    static let todosEndpointURL = URL(string: "https://dummyjson.com/todos")!

    private enum Constants {
        static let todosURL = TodoAPIClient.todosEndpointURL
        static let backgroundQueue = DispatchQueue(label: "io.todo.api", qos: .userInitiated, attributes: .concurrent)
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

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
                    !data.isEmpty,
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

