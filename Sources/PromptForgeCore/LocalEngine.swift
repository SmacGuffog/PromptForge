import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The local rewrite engine: Ollama's OpenAI-compatible endpoint, Qwen 2.5 7B
/// by default.
///
/// It sends the meta-prompt as a single user message to the local Ollama server
/// and returns the model's text. When Ollama is not reachable it reports a clear
/// `engineUnavailable` error rather than a generic network failure.
///
/// Marked `@unchecked Sendable`: all stored properties are immutable and the
/// URLSession-backed transport is thread-safe.
public struct LocalEngine: RewriteEngine, @unchecked Sendable {
    public let label: EngineLabel

    private let transport: HTTPTransport
    private let model: String
    private let baseURL: URL

    /// Create a local engine.
    ///
    /// - Parameters:
    ///   - model: the Ollama model tag. Defaults to Qwen 2.5 7B.
    ///   - modelDisplayName: the label shown in history. Defaults to the model
    ///     tag.
    ///   - baseURL: the Ollama base URL, injectable for testing.
    ///   - transport: the HTTP transport, injectable for testing.
    public init(
        model: String = Settings.defaultLocalModel,
        modelDisplayName: String? = nil,
        baseURL: URL = URL(string: "http://localhost:11434")!,
        transport: HTTPTransport = URLSessionHTTPTransport()
    ) {
        self.model = model
        self.baseURL = baseURL
        self.transport = transport
        self.label = EngineLabel(kind: .local, model: modelDisplayName ?? model)
    }

    public func rewrite(metaPrompt: String) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                model: model,
                messages: [ChatRequest.Message(role: "user", content: metaPrompt)],
                stream: false
            )
        )

        let (data, response) = try await send(request)

        switch response.statusCode {
        case 200:
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            let text = decoded.choices.first?.message.content ?? ""
            guard !text.isEmpty else { throw RewriteError.emptyResponse }
            return text
        default:
            throw RewriteError.api(status: response.statusCode, message: Self.errorMessage(from: data))
        }
    }

    // MARK: Helpers

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await transport.send(request)
        } catch let error as URLError {
            throw Self.mapURLError(error)
        }
    }

    static func mapURLError(_ error: URLError) -> RewriteError {
        switch error.code {
        case .timedOut:
            return .timedOut
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost,
             .notConnectedToInternet, .dnsLookupFailed:
            return .engineUnavailable(reason: "Could not reach Ollama at the configured address. Is it running?")
        default:
            return .network(reason: error.localizedDescription)
        }
    }

    static func errorMessage(from data: Data) -> String {
        if let decoded = try? JSONDecoder().decode(OllamaError.self, from: data) {
            return decoded.error
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}

// MARK: Wire types

private struct ChatRequest: Encodable {
    let model: String
    let messages: [Message]
    let stream: Bool

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct ChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

private struct OllamaError: Decodable {
    let error: String
}
