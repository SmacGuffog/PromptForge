import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A minimal HTTP seam the engines send requests through.
///
/// Injecting this lets `CloudEngine` and `LocalEngine` be tested against canned
/// responses and errors, with no real network.
public protocol HTTPTransport {
    /// Send a request and return its body and HTTP response.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// The real transport, backed by `URLSession`.
public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
