import Foundation

/// The one seam the whole app hangs on.
///
/// A rewrite engine takes a fully assembled meta-prompt and returns rewritten
/// text. That is its entire job. It does not build the meta-prompt (the
/// Translator does that, in one place) and it knows nothing about the UI,
/// history, or style guides.
///
/// Two concrete engines conform to this protocol: `CloudEngine` (Anthropic) and
/// `LocalEngine` (Ollama). Everything above this seam holds a value typed as
/// `RewriteEngine` and never refers to a concrete engine, so switching cloud and
/// local is swapping the conforming type behind this protocol and nothing else.
public protocol RewriteEngine: Sendable {
    /// The engine and specific model, for tagging history entries.
    var label: EngineLabel { get }

    /// Rewrite the given meta-prompt and return the result.
    ///
    /// - Parameter metaPrompt: the complete prompt to send to the model,
    ///   already assembled by the Translator.
    /// - Returns: the rewritten text.
    /// - Throws: `RewriteError` on any failure.
    func rewrite(metaPrompt: String) async throws -> String
}

/// A failure from a rewrite engine, shaped so the UI can show something useful.
public enum RewriteError: Error, Equatable, Sendable {
    /// The engine could not be reached at all, for example Ollama is not
    /// running locally. The reason is a short human-readable detail.
    case engineUnavailable(reason: String)

    /// The engine rejected the credentials, for example a missing or invalid
    /// Anthropic API key.
    case authenticationFailed

    /// A transport-level problem interrupted the request. The reason is a short
    /// human-readable detail.
    case network(reason: String)

    /// The request did not complete before its deadline.
    case timedOut

    /// The engine responded successfully but returned no usable text.
    case emptyResponse

    /// The provider returned an error response. Carries the HTTP status and a
    /// short message for display and logging.
    case api(status: Int, message: String)
}

extension RewriteError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .engineUnavailable(let reason):
            return "The rewrite engine is unavailable. \(reason)"
        case .authenticationFailed:
            return "Authentication failed. Check the API key in Settings."
        case .network(let reason):
            return "A network problem interrupted the request. \(reason)"
        case .timedOut:
            return "The request timed out before the engine responded."
        case .emptyResponse:
            return "The engine returned an empty response."
        case .api(let status, let message):
            return "The engine reported an error (status \(status)). \(message)"
        }
    }
}
