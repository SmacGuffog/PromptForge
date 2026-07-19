import XCTest
@testable import PromptForgeCore

final class HistoryStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PromptForgeHistoryTests-\(UUID().uuidString)", isDirectory: true)
        fileURL = dir.appendingPathComponent("history.jsonl")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    private func makeEntry(
        raw: String,
        output: String,
        target: String = "Claude",
        engine: EngineLabel = EngineLabel(kind: .cloud, model: "Haiku"),
        secondsSince1970: TimeInterval
    ) -> HistoryEntry {
        HistoryEntry(
            rawInput: raw,
            optimisedOutput: output,
            target: target,
            engine: engine,
            timestamp: Date(timeIntervalSince1970: secondsSince1970)
        )
    }

    func testEntriesOnMissingFileIsEmpty() throws {
        let store = HistoryStore(fileURL: fileURL)
        XCTAssertEqual(try store.entries(), [])
    }

    func testRecordThenReadRoundTripsAllFields() throws {
        let store = HistoryStore(fileURL: fileURL)
        let entry = makeEntry(raw: "rough", output: "optimised", secondsSince1970: 1_752_876_000)
        try store.record(entry)

        let read = try store.entries()
        XCTAssertEqual(read, [entry])
    }

    func testEntriesAreNewestFirst() throws {
        let store = HistoryStore(fileURL: fileURL)
        let older = makeEntry(raw: "one", output: "1", secondsSince1970: 1_000)
        let newer = makeEntry(raw: "two", output: "2", secondsSince1970: 2_000)
        try store.record(older)
        try store.record(newer)

        let read = try store.entries()
        XCTAssertEqual(read.map(\.rawInput), ["two", "one"])
    }

    func testRawInputIsPreservedVerbatim() throws {
        let store = HistoryStore(fileURL: fileURL)
        let messy = "  leading spaces\nand a newline\tand a tab, plus unicode: café 🚀  "
        try store.record(makeEntry(raw: messy, output: "out", secondsSince1970: 42))

        let read = try store.entries()
        XCTAssertEqual(read.first?.rawInput, messy)
    }

    func testClearRemovesAllEntries() throws {
        let store = HistoryStore(fileURL: fileURL)
        try store.record(makeEntry(raw: "a", output: "1", secondsSince1970: 1))
        try store.record(makeEntry(raw: "b", output: "2", secondsSince1970: 2))

        try store.clear()
        XCTAssertEqual(try store.entries(), [])
    }

    func testEngineLabelRoundTrips() throws {
        let store = HistoryStore(fileURL: fileURL)
        let entry = makeEntry(
            raw: "x",
            output: "y",
            engine: EngineLabel(kind: .local, model: "Qwen 2.5 7B"),
            secondsSince1970: 100
        )
        try store.record(entry)

        let read = try store.entries().first
        XCTAssertEqual(read?.engine, EngineLabel(kind: .local, model: "Qwen 2.5 7B"))
        XCTAssertEqual(read?.engine.displayName, "Local · Qwen 2.5 7B")
    }

    func testEachEntryIsOnItsOwnLine() throws {
        let store = HistoryStore(fileURL: fileURL)
        try store.record(makeEntry(raw: "a", output: "1", secondsSince1970: 1))
        try store.record(makeEntry(raw: "b", output: "2", secondsSince1970: 2))

        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 2)
    }
}
