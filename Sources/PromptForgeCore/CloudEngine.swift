import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The cloud rewrite engine: the Anthropic Messages API, Haiku by default.
///
/// It reads the API key from the secret store at call time, so a key entered in
/// settings takes effect immediately. It sends the meta-prompt as a single user
/// message and returns the model's text, mapping transport and API failures onto
/// `RewriteError`.
///
/// Marked `@unchecked Sendable`: all stored properties are immutable and the
/// collaborators (the secret store and the URLSession-backed transport) are
/// thread-safe.
public struct CloudEngine: RewriteEngine, @unchecked Sendable {
    public let label: EngineLabel

    private let secretStore: SecretStore
    private let transport: HTTPTransport
    private let model: String
    private let maxTokens: Int
    private let baseURL: URL

    /// The Anthropic Messages API version this engine targets.
    public static let apiVersion = "2023-06-01"

    /// Create a cloud engine.
    ///
    /// - Parameters:
    ///   - secretStore: source of the Anthropic API key.
    ///   - model: the Anthropic model id. Defaults to Claude Haiku 4.5.
    ///   - modelDisplayName: the label shown in history. Defaults to a friendly
    ///     family name derived from the model id (for example "Haiku").
    ///   - maxTokens: output cap for the rewrite.
    ///   - baseURL: the API base URL, injectable for testing.
    ///   - transport: the HTTP transport, injectable for testing.
    public init(
        secretStore: SecretStore,
        model: String = Settings.defaultCloudModel,
        modelDisplayName: String? = nil,
        maxTokens: Int = 4096,
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        transport: HTTPTransport = URLSessionHTTPTransport()
    ) {
        self.secretStore = secretStore
        self.model = model
        self.maxTokens = maxTokens
        self.baseURL = baseURL
        self.transport = transport
        self.label = EngineLabel(kind: .cloud, model: modelDisplayName ?? Self.friendlyName(forModel: model))
    }

    public func rewrite(metaPrompt: String) async throws -> String {
        let apiKey = try resolveAPIKey()

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/messages"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = try JSONEncoder().encode(
            MessagesRequest(
                model: model,
                max_tokens: maxTokens,
                messages: [MessagesRequest.Message(role: "user", content: metaPrompt)]
            )
        )

        let (data, response) = try await send(request)

        switch response.statusCode {
        case 200:
            let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
            let text = decoded.content
                .compactMap { $0.type == "text" ? $0.text : nil }
                .joined()
            guard !text.isEmpty else { throw RewriteError.emptyResponse }
            return text
        case 401:
            throw RewriteError.authenticationFailed
        default:
            throw RewriteError.api(status: response.statusCode, message: Self.errorMessage(from: data))
        }
    }

    // MARK: Helpers

    private func resolveAPIKey() throws -> String {
        do {
            guard let key = try secretStore.apiKey(), !key.isEmpty else {
                throw RewriteError.authenticationFailed
            }
            return key
        } catch let error as RewriteError {
            throw error
        } catch {
            // Could not read the key at all; treat as an auth problem.
            throw RewriteError.authenticationFailed
        }
    }

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
        default:
            return .network(reason: error.localizedDescription)
        }
    }

    static func errorMessage(from data: Data) -> String {
        if let decoded = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            return decoded.error.message
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }

    /// Friendly family name for a model id, for example "claude-haiku-4-5"
    /// becomes "Haiku". Unknown ids are returned unchanged.
    static func friendlyName(forModel id: String) -> String {
        let lower = id.lowercased()
        if lower.contains("haiku") { return "Haiku" }
        if lower.contains("opus") { return "Opus" }
        if lower.contains("sonnet") { return "Sonnet" }
        if lower.contains("fable") { return "Fable" }
        if lower.contains("mythos") { return "Mythos" }
        return id
    }
}

// MARK: Wire types

private struct MessagesRequest: Encodable {
    let model: String
    let max_tokens: Int
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct MessagesResponse: Decodable {
    let content: [Block]

    struct Block: Decodable {
        let type: String
        let text: String?
    }
}

private struct APIErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let type: String
        let message: String
    }
}
