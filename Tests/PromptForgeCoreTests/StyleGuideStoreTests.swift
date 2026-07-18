import XCTest
@testable import PromptForgeCore

final class StyleGuideStoreTests: XCTestCase {
    private var tempDir: URL!
    private var seedsDir: URL!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("PromptForgeTests-\(UUID().uuidString)", isDirectory: true)
        tempDir = base.appendingPathComponent("guides", isDirectory: true)
        seedsDir = base.appendingPathComponent("seeds", isDirectory: true)
        try FileManager.default.createDirectory(at: seedsDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        let base = tempDir.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: base)
    }

    private func writeSeed(_ filename: String, _ contents: String) throws {
        try contents.write(
            to: seedsDir.appendingPathComponent(filename),
            atomically: true,
            encoding: .utf8
        )
    }

    private func makeStore() throws -> StyleGuideStore {
        try StyleGuideStore(directory: tempDir, seededGuidesURL: seedsDir)
    }

    func testSeedsOnFirstRun() throws {
        try writeSeed("claude.md", "---\ntarget: Claude\nlast_refreshed: 2026-07-18\n---\n\n# Claude\n")
        try writeSeed("gpt.md", "---\ntarget: GPT\n---\n\n# GPT\n")

        let store = try makeStore()
        let targets = try store.availableTargets()

        XCTAssertEqual(targets.map(\.name), ["Claude", "GPT"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("claude.md").path))
    }

    func testSeedingDoesNotOverwriteExistingEdits() throws {
        // A guide the user already owns and edited.
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let edited = "---\ntarget: Claude\n---\n\n# My edited Claude guide\n"
        try edited.write(to: tempDir.appendingPathComponent("claude.md"), atomically: true, encoding: .utf8)

        // A seed with different content for the same filename.
        try writeSeed("claude.md", "---\ntarget: Claude\n---\n\n# Shipped default\n")

        let store = try makeStore()
        let guide = try store.loadGuide(for: Target(name: "Claude"))
        XCTAssertTrue(guide.body.contains("My edited Claude guide"))
    }

    func testLoadGuideByTarget() throws {
        try writeSeed("cursor.md", "---\ntarget: Cursor\nlast_refreshed: 2026-07-18\n---\n\n# Cursor guide\n")
        let store = try makeStore()

        let guide = try store.loadGuide(for: Target(name: "Cursor"))
        XCTAssertEqual(guide.metadata.target, "Cursor")
        XCTAssertTrue(guide.body.contains("Cursor guide"))
    }

    func testLoadMissingGuideThrows() throws {
        let store = try makeStore()
        XCTAssertThrowsError(try store.loadGuide(for: Target(name: "Nonexistent"))) { error in
            XCTAssertEqual(error as? StyleGuideStoreError, .guideNotFound(filename: "nonexistent.md"))
        }
    }

    func testSaveThenReloadRoundTrips() throws {
        try writeSeed("claude.md", "---\ntarget: Claude\n---\n\n# Original\n")
        let store = try makeStore()
        let target = Target(name: "Claude")

        var guide = try store.loadGuide(for: target)
        guide.body = "# Edited body\n\nNew content."
        try store.save(guide, for: target)

        let reloaded = try store.loadGuide(for: target)
        XCTAssertEqual(reloaded, guide)
    }

    func testTargetsAreSortedByName() throws {
        try writeSeed("gpt.md", "---\ntarget: GPT\n---\n\nx\n")
        try writeSeed("claude.md", "---\ntarget: Claude\n---\n\nx\n")
        try writeSeed("cursor.md", "---\ntarget: Cursor\n---\n\nx\n")

        let store = try makeStore()
        XCTAssertEqual(try store.availableTargets().map(\.name), ["Claude", "Cursor", "GPT"])
    }

    func testNilSeedsSkipsSeeding() throws {
        let store = try StyleGuideStore(directory: tempDir, seededGuidesURL: nil)
        XCTAssertEqual(try store.availableTargets(), [])
    }
}
