import Foundation
@testable import PromptForgeCore

/// A test double for `RewriteEngine`. It returns a canned response and records
/// what it was asked to rewrite, so tests above the engine seam (the Translator,
/// for example) can run without a network or a real model.
///
/// It can also be told to throw, to exercise error paths.
final class FakeEngine: RewriteEngine, @unchecked Sendable {
    let label: EngineLabel

    /// The text returned from `rewrite(metaPrompt:)` when no error is set.
    var cannedResponse: String

    /// When set, `rewrite(metaPrompt:)` throws this instead of returning.
    var errorToThrow: RewriteError?

    /// The last meta-prompt passed to `rewrite(metaPrompt:)`.
    private(set) var receivedMetaPrompt: String?

    /// How many times `rewrite(metaPrompt:)` has been called.
    private(set) var callCount = 0

    init(
        label: EngineLabel = EngineLabel(kind: .cloud, model: "Fake"),
        cannedResponse: String = "REWRITTEN",
        errorToThrow: RewriteError? = nil
    ) {
        self.label = label
        self.cannedResponse = cannedResponse
        self.errorToThrow = errorToThrow
    }

    func rewrite(metaPrompt: String) async throws -> String {
        receivedMetaPrompt = metaPrompt
        callCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        return cannedResponse
    }
}
