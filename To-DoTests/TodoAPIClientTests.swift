//
//  TodoAPIClientTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 11.11.2025.
//

import XCTest
@testable import To_Do

/// Проверяем сетевой клиент загрузки задач
final class TodoAPIClientTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        URLProtocolMock.reset()
    }

    /// Успешный ответ 200 с валидным JSON возвращает массив задач
    func testFetchTodosSuccessDeliversDecodedTodos() {
        let expectation = expectation(description: "completion")
        URLProtocolMock.response = HTTPURLResponse(url: TodoAPIClientTests.testURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.testData = """
        {
          "todos": [
            {"id": 1, "todo": "Task 1", "completed": false, "userId": 10},
            {"id": 2, "todo": "Task 2", "completed": true, "userId": 11}
          ]
        }
        """.data(using: .utf8)

        makeClient().fetchTodos { result in
            switch result {
            case .success(let todos):
                XCTAssertEqual(todos.count, 2)
                XCTAssertEqual(todos.first?.todo, "Task 1")
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    /// При сетевой ошибке клиент отдаёт ту же ошибку вызывающему коду
    func testFetchTodosPropagatesNetworkError() {
        let expectation = expectation(description: "completion")
        let sampleError = URLError(.timedOut)
        URLProtocolMock.error = sampleError

        makeClient().fetchTodos { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertEqual((error as? URLError)?.code, sampleError.code)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    /// Неверный HTTP статус приводит к URLError.badServerResponse
    func testFetchTodosWithBadStatusReturnsBadServerResponse() {
        let expectation = expectation(description: "completion")
        URLProtocolMock.response = HTTPURLResponse(url: TodoAPIClientTests.testURL, statusCode: 500, httpVersion: nil, headerFields: nil)
        URLProtocolMock.testData = Data()

        makeClient().fetchTodos { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    /// При некорректном JSON возвращается ошибка декодирования
    func testFetchTodosWithInvalidJSONReturnsDecodingError() {
        let expectation = expectation(description: "completion")
        URLProtocolMock.response = HTTPURLResponse(url: TodoAPIClientTests.testURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolMock.testData = Data("{}".utf8)

        makeClient().fetchTodos { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertTrue(error is DecodingError)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    /// Создаём клиент с подменённой URLProtocol, чтобы контролировать ответы
    private func makeClient() -> TodoAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: configuration)
        return TodoAPIClient(session: session)
    }

    private static let testURL = URL(string: "https://dummyjson.com/todos")!
}

/// Заглушка URLProtocol, позволяющая эмулировать ответы сервера
private final class URLProtocolMock: URLProtocol {
    static var testData: Data?
    static var response: URLResponse?
    static var error: Error?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let response = Self.response ?? HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        if let data = Self.testData {
            client?.urlProtocol(self, didLoad: data)
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }

    static func reset() {
        testData = nil
        response = nil
        error = nil
    }
}

