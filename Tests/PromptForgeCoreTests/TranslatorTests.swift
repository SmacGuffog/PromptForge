import XCTest
@testable import PromptForgeCore

/// A `StyleGuideProviding` that returns a canned guide and records the target
/// it was asked for.
private final class FakeGuideProvider: StyleGuideProviding {
    var guide: StyleGuide
    private(set) var requestedTargets: [Target] = []

    init(guide: StyleGuide) {
        self.guide = guide
    }

    func availableTargets() throws -> [Target] {
        [Target(name: guide.metadata.target)]
    }

    func loadGuide(for target: Target) throws -> StyleGuide {
        requestedTargets.append(target)
        return guide
    }
}

/// A `HistoryRecording` that collects entries in memory.
private final class FakeHistory: HistoryRecording {
    private(set) var recorded: [HistoryEntry] = []

    func record(_ entry: HistoryEntry) throws {
        recorded.append(entry)
    }
}

final class TranslatorTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_752_876_000)

    private func makeGuide(target: String = "Claude", body: String = "Guide body.") -> StyleGuide {
        StyleGuide(metadata: GuideMetadata(target: target), body: body)
    }

    func testAssemblesMetaPromptFromGuideAndRawPrompt() async throws {
        let guide = makeGuide(target: "Claude", body: "Prefer XML tags.")
        let provider = FakeGuideProvider(guide: guide)
        let engine = FakeEngine(cannedResponse: "OPTIMISED")
        let translator = Translator(guides: provider, engine: engine, history: FakeHistory())
        let target = Target(name: "Claude")

        _ = try await translator.translate(rawPrompt: "make it good", target: target)

        let expected = Translator.buildMetaPrompt(guide: guide, rawPrompt: "make it good", target: target)
        XCTAssertEqual(engine.receivedMetaPrompt, expected)
        // Sanity: the assembled prompt carries the guide body and the raw prompt.
        XCTAssertTrue(engine.receivedMetaPrompt?.contains("Prefer XML tags.") == true)
        XCTAssertTrue(engine.receivedMetaPrompt?.contains("make it good") == true)
        XCTAssertTrue(engine.receivedMetaPrompt?.contains("Claude") == true)
    }

    func testReturnsEngineOutputUnchanged() async throws {
        let engine = FakeEngine(cannedResponse: "the optimised prompt")
        let translator = Translator(
            guides: FakeGuideProvider(guide: makeGuide()),
            engine: engine,
            history: FakeHistory()
        )

        let result = try await translator.translate(rawPrompt: "x", target: Target(name: "Claude"))
        XCTAssertEqual(result, "the optimised prompt")
    }

    func testRecordsHistoryOnceOnSuccess() async throws {
        let history = FakeHistory()
        let engine = FakeEngine(
            label: EngineLabel(kind: .cloud, model: "Haiku"),
            cannedResponse: "out"
        )
        let translator = Translator(
            guides: FakeGuideProvider(guide: makeGuide()),
            engine: engine,
            history: history,
            now: { self.fixedDate }
        )

        _ = try await translator.translate(rawPrompt: "verbatim raw", target: Target(name: "Claude"))

        XCTAssertEqual(history.recorded.count, 1)
        let entry = try XCTUnwrap(history.recorded.first)
        XCTAssertEqual(entry.rawInput, "verbatim raw")
        XCTAssertEqual(entry.optimisedOutput, "out")
        XCTAssertEqual(entry.target, "Claude")
        XCTAssertEqual(entry.engine, EngineLabel(kind: .cloud, model: "Haiku"))
        XCTAssertEqual(entry.timestamp, fixedDate)
    }

    func testDoesNotRecordHistoryOnEngineFailure() async {
        let history = FakeHistory()
        let engine = FakeEngine(errorToThrow: .emptyResponse)
        let translator = Translator(
            guides: FakeGuideProvider(guide: makeGuide()),
            engine: engine,
            history: history
        )

        do {
            _ = try await translator.translate(rawPrompt: "x", target: Target(name: "Claude"))
            XCTFail("expected translate to throw")
        } catch let error as RewriteError {
            XCTAssertEqual(error, .emptyResponse)
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
        XCTAssertTrue(history.recorded.isEmpty)
    }

    func testLoadsGuideForRequestedTarget() async throws {
        let provider = FakeGuideProvider(guide: makeGuide(target: "Cursor"))
        let translator = Translator(
            guides: provider,
            engine: FakeEngine(),
            history: FakeHistory()
        )
        let target = Target(name: "Cursor")

        _ = try await translator.translate(rawPrompt: "x", target: target)
        XCTAssertEqual(provider.requestedTargets, [target])
    }

    func testEngineCanBeSwapped() async throws {
        let translator = Translator(
            guides: FakeGuideProvider(guide: makeGuide()),
            engine: FakeEngine(label: EngineLabel(kind: .cloud, model: "Haiku"), cannedResponse: "cloud"),
            history: FakeHistory()
        )

        translator.engine = FakeEngine(label: EngineLabel(kind: .local, model: "Qwen 2.5 7B"), cannedResponse: "local")
        let result = try await translator.translate(rawPrompt: "x", target: Target(name: "Claude"))
        XCTAssertEqual(result, "local")
    }
}
