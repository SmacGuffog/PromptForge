import XCTest
@testable import PromptForgeCore

final class EngineKindTests: XCTestCase {
    func testDisplayNames() {
        XCTAssertEqual(EngineKind.cloud.displayName, "Cloud")
        XCTAssertEqual(EngineKind.local.displayName, "Local")
    }

    func testEngineLabelDisplayName() {
        let cloud = EngineLabel(kind: .cloud, model: "Haiku")
        XCTAssertEqual(cloud.displayName, "Cloud · Haiku")

        let local = EngineLabel(kind: .local, model: "Qwen 2.5 7B")
        XCTAssertEqual(local.displayName, "Local · Qwen 2.5 7B")
    }

    func testEngineKindCodableRoundTrip() throws {
        for kind in EngineKind.allCases {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(EngineKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }

    func testEngineLabelCodableRoundTrip() throws {
        let label = EngineLabel(kind: .local, model: "Qwen 2.5 7B")
        let data = try JSONEncoder().encode(label)
        let decoded = try JSONDecoder().decode(EngineLabel.self, from: data)
        XCTAssertEqual(decoded, label)
    }
}

final class RewriteEngineSeamTests: XCTestCase {
    func testFakeEngineReturnsCannedResponseAndRecordsMetaPrompt() async throws {
        let engine = FakeEngine(cannedResponse: "OPTIMISED")
        let result = try await engine.rewrite(metaPrompt: "guide + raw + instructions")

        XCTAssertEqual(result, "OPTIMISED")
        XCTAssertEqual(engine.receivedMetaPrompt, "guide + raw + instructions")
        XCTAssertEqual(engine.callCount, 1)
    }

    func testFakeEngineReportsItsLabel() {
        let engine = FakeEngine(label: EngineLabel(kind: .cloud, model: "Haiku"))
        XCTAssertEqual(engine.label.displayName, "Cloud · Haiku")
    }

    func testFakeEngineThrowsConfiguredError() async {
        let engine = FakeEngine(errorToThrow: .emptyResponse)
        do {
            _ = try await engine.rewrite(metaPrompt: "anything")
            XCTFail("expected rewrite to throw")
        } catch let error as RewriteError {
            XCTAssertEqual(error, .emptyResponse)
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }
}
