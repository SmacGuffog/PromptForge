import XCTest
@testable import PromptForgeCore

final class TargetTests: XCTestCase {
    func testDerivesGuideFilenameFromName() {
        XCTAssertEqual(Target(name: "Claude").guideFilename, "claude.md")
        XCTAssertEqual(Target(name: "GPT").guideFilename, "gpt.md")
        XCTAssertEqual(Target(name: "Cursor").guideFilename, "cursor.md")
    }

    func testDerivesSlugForMultiWordName() {
        XCTAssertEqual(Target(name: "GitHub Copilot").guideFilename, "github-copilot.md")
    }

    func testExplicitFilenameIsKept() {
        let target = Target(name: "Claude", guideFilename: "claude-custom.md")
        XCTAssertEqual(target.guideFilename, "claude-custom.md")
    }

    func testIdentityIsTheName() {
        XCTAssertEqual(Target(name: "Claude").id, "Claude")
    }

    func testCodableRoundTrip() throws {
        let target = Target(name: "Cursor")
        let data = try JSONEncoder().encode(target)
        let decoded = try JSONDecoder().decode(Target.self, from: data)
        XCTAssertEqual(decoded, target)
    }
}
