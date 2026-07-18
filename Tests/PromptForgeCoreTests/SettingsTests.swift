import XCTest
@testable import PromptForgeCore

final class SettingsModelTests: XCTestCase {
    func testDefaults() {
        let settings = Settings()
        XCTAssertEqual(settings.activeEngine, .cloud)
        XCTAssertEqual(settings.cloudModel, "claude-haiku-4-5")
        XCTAssertEqual(settings.localModel, "qwen2.5:7b")
        XCTAssertEqual(settings.hotkey, Hotkey(key: "space", modifiers: [.control, .option]))
        XCTAssertEqual(settings.defaultTargetName, "Claude")
        XCTAssertEqual(settings.theme, .system)
    }

    func testEncodeDecodeRoundTrip() throws {
        var settings = Settings()
        settings.activeEngine = .local
        settings.cloudModel = "claude-opus-4-8"
        settings.localModel = "llama3.3:8b"
        settings.hotkey = Hotkey(key: "p", modifiers: [.command, .shift])
        settings.defaultTargetName = "Cursor"
        settings.theme = .dark

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    func testDecodePartialJSONFillsDefaults() throws {
        let json = Data(#"{"theme":"dark"}"#.utf8)
        let settings = try JSONDecoder().decode(Settings.self, from: json)

        XCTAssertEqual(settings.theme, .dark)
        // Everything else falls back to its default.
        XCTAssertEqual(settings.activeEngine, .cloud)
        XCTAssertEqual(settings.cloudModel, "claude-haiku-4-5")
        XCTAssertEqual(settings.defaultTargetName, "Claude")
    }
}

final class SettingsStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PromptForgeSettingsTests-\(UUID().uuidString)", isDirectory: true)
        fileURL = dir.appendingPathComponent("settings.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    func testLoadMissingFileReturnsDefaults() {
        let store = SettingsStore(fileURL: fileURL)
        XCTAssertEqual(store.load(), Settings())
    }

    func testSaveThenLoad() throws {
        let store = SettingsStore(fileURL: fileURL)
        var settings = Settings()
        settings.activeEngine = .local
        settings.theme = .light
        try store.save(settings)

        XCTAssertEqual(store.load(), settings)
    }

    func testCorruptFileReturnsDefaults() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not valid json".utf8).write(to: fileURL)

        let store = SettingsStore(fileURL: fileURL)
        XCTAssertEqual(store.load(), Settings())
    }

    func testSaveCreatesContainingFolder() throws {
        // The folder does not exist yet; save must create it.
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.deletingLastPathComponent().path))
        let store = SettingsStore(fileURL: fileURL)
        try store.save(Settings())
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
