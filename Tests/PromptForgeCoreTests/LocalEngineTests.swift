import XCTest
@testable import PromptForgeCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class LocalEngineTests: XCTestCase {
    private let baseURL = URL(string: "http://localhost:11434")!

    private func okBody(_ content: String) -> Data {
        Data(#"{"choices":[{"message":{"role":"assistant","content":"\#(content)"}}]}"#.utf8)
    }

    func testSendsWellFormedRequest() async throws {
        let transport = RecordingTransport(status: 200, body: okBody("ok"))
        let engine = LocalEngine(model: "qwen2.5:7b", baseURL: baseURL, transport: transport)

        _ = try await engine.rewrite(metaPrompt: "META PROMPT")

        let request = try XCTUnwrap(transport.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:11434/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "qwen2.5:7b")
        XCTAssertEqual(json["stream"] as? Bool, false)
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.first?["role"] as? String, "user")
        XCTAssertEqual(messages.first?["content"] as? String, "META PROMPT")
    }

    func testParsesContentFromResponse() async throws {
        let engine = LocalEngine(
            baseURL: baseURL,
            transport: RecordingTransport(status: 200, body: okBody("LOCAL OUT"))
        )
        XCTAssertEqual(try await engine.rewrite(metaPrompt: "x"), "LOCAL OUT")
    }

    func testNoChoicesThrowsEmptyResponse() async {
        let engine = LocalEngine(
            baseURL: baseURL,
            transport: RecordingTransport(status: 200, body: Data(#"{"choices":[]}"#.utf8))
        )
        await assertThrowsRewriteError(.emptyResponse) {
            try await engine.rewrite(metaPrompt: "x")
        }
    }

    func testConnectionRefusedMapsToEngineUnavailable() async {
        let engine = LocalEngine(
            baseURL: baseURL,
            transport: RecordingTransport(error: URLError(.cannotConnectToHost))
        )
        do {
            _ = try await engine.rewrite(metaPrompt: "x")
            XCTFail("expected an engine-unavailable error")
        } catch let error as RewriteError {
            guard case .engineUnavailable = error else {
                return XCTFail("expected .engineUnavailable, got \(error)")
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testTimeoutMapsToTimedOut() async {
        let engine = LocalEngine(
            baseURL: baseURL,
            transport: RecordingTransport(error: URLError(.timedOut))
        )
        await assertThrowsRewriteError(.timedOut) {
            try await engine.rewrite(metaPrompt: "x")
        }
    }

    func testErrorStatusMapsToApiWithMessage() async {
        let body = Data(#"{"error":"model 'qwen2.5:7b' not found"}"#.utf8)
        let engine = LocalEngine(
            baseURL: baseURL,
            transport: RecordingTransport(status: 404, body: body)
        )
        await assertThrowsRewriteError(.api(status: 404, message: "model 'qwen2.5:7b' not found")) {
            try await engine.rewrite(metaPrompt: "x")
        }
    }

    func testLabelDefaultsToModelTag() {
        let engine = LocalEngine(model: "qwen2.5:7b")
        XCTAssertEqual(engine.label.displayName, "Local · qwen2.5:7b")
    }

    func testLabelUsesDisplayNameWhenProvided() {
        let engine = LocalEngine(model: "qwen2.5:7b", modelDisplayName: "Qwen 2.5 7B")
        XCTAssertEqual(engine.label.displayName, "Local · Qwen 2.5 7B")
    }
}
