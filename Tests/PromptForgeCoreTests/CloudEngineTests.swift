import XCTest
@testable import PromptForgeCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class CloudEngineTests: XCTestCase {
    private let baseURL = URL(string: "https://api.test")!

    private func okBody(_ text: String) -> Data {
        Data(#"{"content":[{"type":"text","text":"\#(text)"}]}"#.utf8)
    }

    func testSendsWellFormedRequest() async throws {
        let transport = RecordingTransport(status: 200, body: okBody("ok"))
        let engine = CloudEngine(
            secretStore: InMemorySecretStore(key: "sk-test"),
            model: "claude-haiku-4-5",
            baseURL: baseURL,
            transport: transport
        )

        _ = try await engine.rewrite(metaPrompt: "META PROMPT")

        let request = try XCTUnwrap(transport.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.test/v1/messages")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-haiku-4-5")
        XCTAssertNotNil(json["max_tokens"])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.first?["role"] as? String, "user")
        XCTAssertEqual(messages.first?["content"] as? String, "META PROMPT")
    }

    func testParsesTextFromResponse() async throws {
        let engine = CloudEngine(
            secretStore: InMemorySecretStore(key: "sk-test"),
            baseURL: baseURL,
            transport: RecordingTransport(status: 200, body: okBody("REWRITTEN"))
        )
        let result = try await engine.rewrite(metaPrompt: "x")
        XCTAssertEqual(result, "REWRITTEN")
    }

    func testConcatenatesMultipleTextBlocks() async throws {
        let body = Data(#"{"content":[{"type":"text","text":"A"},{"type":"text","text":"B"}]}"#.utf8)
        let engine = CloudEngine(
            secretStore: InMemorySecretStore(key: "sk-test"),
            baseURL: baseURL,
            transport: RecordingTransport(status: 200, body: body)
        )
        XCTAssertEqual(try await engine.rewrite(metaPrompt: "x"), "AB")
    }

    func testEmptyContentThrowsEmptyResponse() async {
        let engine = CloudEngine(
            secretStore: InMemorySecretStore(key: "sk-test"),
            baseURL: baseURL,
            transport: RecordingTransport(status: 200, body: Data(#"{"content":[]}"#.utf8))
        )
        await assertThrowsRewriteError(.emptyResponse) {
            try await engine.rewrite(metaPrompt: "x")
        }
    }

    func testMissingKeyThrowsAuthenticationFailedWithoutCallingTransport() async {
        let transport = RecordingTransport(status: 200, body: okBody("ok"))
        let engine = CloudEngine(
            secretStore: InMemorySecretStore(key: nil),
            baseURL: baseURL,
            transport: transport
        )
        await assertThrowsRewriteError(.authenticationFailed) {
            try await engine.rewrite(metaPrompt: "x")
        }
        XCTAssertEqual(transport.callCount, 0)
    }

    func test401ThrowsAuthenticationFailed() async {
        let engine = CloudEngine(
            secretStore: InMemorySecretStore(key: "sk-test"),
            baseURL: baseURL,
            transport: RecordingTransport(status: 401, body: Data("{}".utf8))
        )
        await assertThrowsRewriteError(.authenticationFailed) {
            try await engine.rewrite(metaPrompt: "x")
        }
    }

    func testAPIErrorMapsToApiWithMessage() async {
        let body = Data(#"{"type":"error","error":{"type":"rate_limit_error","message":"slow down"}}"#.utf8)
        let engine = CloudEngine(
            secretStore: InMemorySecretStore(key: "sk-test"),
            baseURL: baseURL,
            transport: RecordingTransport(status: 429, body: body)
        )
        await assertThrowsRewriteError(.api(status: 429, message: "slow down")) {
            try await engine.rewrite(metaPrompt: "x")
        }
    }

    func testTimeoutMapsToTimedOut() async {
        let engine = CloudEngine(
            secretStore: InMemorySecretStore(key: "sk-test"),
            baseURL: baseURL,
            transport: RecordingTransport(error: URLError(.timedOut))
        )
        await assertThrowsRewriteError(.timedOut) {
            try await engine.rewrite(metaPrompt: "x")
        }
    }

    func testConnectionErrorMapsToNetwork() async {
        let engine = CloudEngine(
            secretStore: InMemorySecretStore(key: "sk-test"),
            baseURL: baseURL,
            transport: RecordingTransport(error: URLError(.notConnectedToInternet))
        )
        // The reason text comes from URLError, so match only the case.
        do {
            _ = try await engine.rewrite(metaPrompt: "x")
            XCTFail("expected a network error")
        } catch let error as RewriteError {
            guard case .network = error else {
                return XCTFail("expected .network, got \(error)")
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testLabelDefaultsToFriendlyName() {
        let engine = CloudEngine(secretStore: InMemorySecretStore(), model: "claude-haiku-4-5")
        XCTAssertEqual(engine.label.displayName, "Cloud · Haiku")
    }

    func testFriendlyNameMapping() {
        XCTAssertEqual(CloudEngine.friendlyName(forModel: "claude-haiku-4-5"), "Haiku")
        XCTAssertEqual(CloudEngine.friendlyName(forModel: "claude-opus-4-8"), "Opus")
        XCTAssertEqual(CloudEngine.friendlyName(forModel: "some-unknown-model"), "some-unknown-model")
    }
}
