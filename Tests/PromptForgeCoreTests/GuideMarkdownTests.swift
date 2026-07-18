import XCTest
@testable import PromptForgeCore

final class GuideMarkdownTests: XCTestCase {
    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)!
    }

    func testParsesWellFormedHeaderAndBody() {
        let text = """
        ---
        target: Claude
        last_refreshed: 2026-07-18
        ---

        # Style guide: Claude

        Body content here.
        """
        let guide = GuideMarkdown.parse(text, fallbackTarget: "fallback")
        XCTAssertEqual(guide.metadata.target, "Claude")
        XCTAssertEqual(guide.metadata.lastRefreshed, date("2026-07-18"))
        XCTAssertEqual(guide.body, "# Style guide: Claude\n\nBody content here.")
    }

    func testMissingHeaderUsesFallbackTargetAndWholeBody() {
        let text = "# Just a body\n\nNo front matter at all."
        let guide = GuideMarkdown.parse(text, fallbackTarget: "Cursor")
        XCTAssertEqual(guide.metadata.target, "Cursor")
        XCTAssertNil(guide.metadata.lastRefreshed)
        XCTAssertEqual(guide.body, "# Just a body\n\nNo front matter at all.")
    }

    func testMalformedHeaderWithNoClosingDelimiterIsTreatedAsBody() {
        let text = """
        ---
        target: Claude

        # Body with an unterminated header
        """
        let guide = GuideMarkdown.parse(text, fallbackTarget: "GPT")
        XCTAssertEqual(guide.metadata.target, "GPT")
        XCTAssertNil(guide.metadata.lastRefreshed)
        XCTAssertTrue(guide.body.contains("unterminated header"))
    }

    func testHeaderWithoutTargetFallsBack() {
        let text = """
        ---
        last_refreshed: 2026-07-18
        ---

        Body.
        """
        let guide = GuideMarkdown.parse(text, fallbackTarget: "GPT")
        XCTAssertEqual(guide.metadata.target, "GPT")
        XCTAssertEqual(guide.metadata.lastRefreshed, date("2026-07-18"))
    }

    func testMalformedDateBecomesNil() {
        let text = """
        ---
        target: Claude
        last_refreshed: not-a-date
        ---

        Body.
        """
        let guide = GuideMarkdown.parse(text, fallbackTarget: "fallback")
        XCTAssertEqual(guide.metadata.target, "Claude")
        XCTAssertNil(guide.metadata.lastRefreshed)
    }

    func testSerializeThenParseIsStable() {
        let guide = StyleGuide(
            metadata: GuideMetadata(target: "Claude", lastRefreshed: date("2026-07-18")),
            body: "# Heading\n\nSome prose.\n\n- a bullet"
        )
        let serialized = GuideMarkdown.serialize(guide)
        let reparsed = GuideMarkdown.parse(serialized, fallbackTarget: "fallback")
        XCTAssertEqual(reparsed, guide)
    }

    func testSerializeOmitsDateWhenAbsent() {
        let guide = StyleGuide(
            metadata: GuideMetadata(target: "Cursor", lastRefreshed: nil),
            body: "Body."
        )
        let serialized = GuideMarkdown.serialize(guide)
        XCTAssertFalse(serialized.contains("last_refreshed"))
        XCTAssertTrue(serialized.contains("target: Cursor"))
    }
}
