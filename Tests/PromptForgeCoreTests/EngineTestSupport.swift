import Foundation
import XCTest
@testable import PromptForgeCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An in-memory `SecretStore` for engine tests.
final class InMemorySecretStore: SecretStore {
    private var key: String?

    init(key: String? = nil) {
        self.key = key
    }

    func setAPIKey(_ key: String) throws {
        self.key = key
    }

    func apiKey() throws -> String? {
        key
    }

    func deleteAPIKey() throws {
        key = nil
    }
}

/// An `HTTPTransport` that records the request and returns whatever its
/// responder produces, so engine tests run with no real network.
final class RecordingTransport: HTTPTransport {
    private let responder: (URLRequest) throws -> (Data, HTTPURLResponse)
    private(set) var lastRequest: URLRequest?
    private(set) var callCount = 0

    init(_ responder: @escaping (URLRequest) throws -> (Data, HTTPURLResponse)) {
        self.responder = responder
    }

    /// Convenience: always return the given status and body.
    convenience init(status: Int, body: Data) {
        self.init { request in
            (body, makeHTTPResponse(request.url, status))
        }
    }

    /// Convenience: always throw the given error.
    convenience init(error: Error) {
        self.init { _ in throw error }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        callCount += 1
        return try responder(request)
    }
}

/// Build an `HTTPURLResponse` for a request URL and status code.
func makeHTTPResponse(_ url: URL?, _ status: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url ?? URL(string: "https://example.com")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: nil
    )!
}

/// Assert that an async expression throws a specific `RewriteError`.
func assertThrowsRewriteError<T>(
    _ expected: RewriteError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ expression: () async throws -> T
) async {
    do {
        _ = try await expression()
        XCTFail("expected \(expected) to be thrown", file: file, line: line)
    } catch let error as RewriteError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("unexpected error type: \(error)", file: file, line: line)
    }
}
