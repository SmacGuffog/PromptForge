import Foundation

/// The orchestrator, and the single place translation behaviour is tuned.
///
/// Given a raw prompt and a target, the Translator asks the Style Guide Store
/// for that target's guide, assembles the meta-prompt (guide plus raw prompt
/// plus rewrite instructions) in exactly one place, hands it to the active
/// engine, and on success records the result in history.
///
/// It holds the engine through the `RewriteEngine` protocol and never refers to
/// a concrete engine. Switching cloud and local is assigning a different
/// conforming value to `engine`.
public final class Translator {
    private let guides: StyleGuideProviding
    private let history: HistoryRecording
    private let now: () -> Date

    /// The active rewrite engine. Swap this to switch cloud and local.
    public var engine: RewriteEngine

    public init(
        guides: StyleGuideProviding,
        engine: RewriteEngine,
        history: HistoryRecording,
        now: @escaping () -> Date = Date.init
    ) {
        self.guides = guides
        self.engine = engine
        self.history = history
        self.now = now
    }

    /// Translate a raw prompt for a target.
    ///
    /// - Parameters:
    ///   - rawPrompt: the rough prompt, as dictated or typed.
    ///   - target: the target tool to optimise for.
    /// - Returns: the optimised prompt.
    /// - Throws: a `RewriteError` from the engine, or an error from the store.
    public func translate(rawPrompt: String, target: Target) async throws -> String {
        let guide = try guides.loadGuide(for: target)
        let metaPrompt = Self.buildMetaPrompt(guide: guide, rawPrompt: rawPrompt, target: target)
        let output = try await engine.rewrite(metaPrompt: metaPrompt)

        let entry = HistoryEntry(
            rawInput: rawPrompt,
            optimisedOutput: output,
            target: target.name,
            engine: engine.label,
            timestamp: now()
        )
        try history.record(entry)

        return output
    }

    /// Assemble the meta-prompt sent to the engine.
    ///
    /// This is the ONLY place the meta-prompt is built, and therefore the only
    /// place translation behaviour is tuned.
    static func buildMetaPrompt(guide: StyleGuide, rawPrompt: String, target: Target) -> String {
        """
        You are a prompt optimiser. Rewrite the rough prompt below into a single \
        prompt optimised for \(target.name), following the style guide. Output only \
        the rewritten prompt, with no preamble, commentary, or surrounding quotes.

        Style guide for \(target.name):
        \(guide.body)

        Rough prompt:
        \(rawPrompt)

        Rewritten prompt:
        """
    }
}
