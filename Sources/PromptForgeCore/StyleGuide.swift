import Foundation

/// The small header carried at the top of every style guide file.
public struct GuideMetadata: Equatable, Sendable {
    /// Display name of the target this guide is for, for example "Claude".
    public var target: String

    /// When the guide was last refreshed, if the header recorded it.
    public var lastRefreshed: Date?

    public init(target: String, lastRefreshed: Date? = nil) {
        self.target = target
        self.lastRefreshed = lastRefreshed
    }
}

/// A parsed style guide: its metadata header plus the Markdown body.
///
/// The body is structured prose (model preferences, how to structure
/// instructions, formatting conventions, common pitfalls). The Translator uses
/// the body to steer a rewrite. This type carries no behaviour and knows nothing
/// about disk, rewriting, or the UI.
public struct StyleGuide: Equatable, Sendable {
    public var metadata: GuideMetadata
    public var body: String

    public init(metadata: GuideMetadata, body: String) {
        self.metadata = metadata
        self.body = body
    }
}

/// Parses and serialises the on-disk Markdown form of a style guide.
///
/// The on-disk form is a small front matter block delimited by `---` lines,
/// carrying `target` and `last_refreshed`, followed by the Markdown body:
///
///     ---
///     target: Claude
///     last_refreshed: 2026-07-18
///     ---
///
///     # Style guide: Claude
///     ...
///
/// Parsing is lenient: a missing or malformed header yields the whole text as
/// the body with a fallback target name, so a user editing the file by hand
/// cannot lose their content.
enum GuideMarkdown {
    private static let delimiter = "---"

    /// Fixed date format for the `last_refreshed` header, locale and time zone
    /// independent so guides round-trip identically everywhere.
    private static func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    /// Parse Markdown text into a `StyleGuide`.
    ///
    /// - Parameters:
    ///   - text: the full file contents.
    ///   - fallbackTarget: the target name to use when the header is missing,
    ///     malformed, or has no `target` field.
    static func parse(_ text: String, fallbackTarget: String) -> StyleGuide {
        let lines = text.components(separatedBy: "\n")

        // No opening delimiter: the whole text is the body.
        guard lines.first?.trimmingCharacters(in: .whitespaces) == delimiter else {
            return StyleGuide(
                metadata: GuideMetadata(target: fallbackTarget),
                body: normaliseBody(text)
            )
        }

        // Find the closing delimiter.
        var headerLines: [String] = []
        var bodyStart: Int?
        var index = 1
        while index < lines.count {
            if lines[index].trimmingCharacters(in: .whitespaces) == delimiter {
                bodyStart = index + 1
                break
            }
            headerLines.append(lines[index])
            index += 1
        }

        // Opening delimiter with no closing one: malformed, treat all as body.
        guard let bodyStart else {
            return StyleGuide(
                metadata: GuideMetadata(target: fallbackTarget),
                body: normaliseBody(text)
            )
        }

        let metadata = parseHeader(headerLines, fallbackTarget: fallbackTarget)
        let body = normaliseBody(lines[bodyStart...].joined(separator: "\n"))
        return StyleGuide(metadata: metadata, body: body)
    }

    /// Serialise a `StyleGuide` back to its on-disk Markdown form.
    ///
    /// The output is canonical: a `target` line, an optional `last_refreshed`
    /// line, one blank line, then the body and a trailing newline. Parsing this
    /// output returns an equal `StyleGuide`.
    static func serialize(_ guide: StyleGuide) -> String {
        var header = "\(delimiter)\n"
        header += "target: \(guide.metadata.target)\n"
        if let date = guide.metadata.lastRefreshed {
            header += "last_refreshed: \(makeDateFormatter().string(from: date))\n"
        }
        header += "\(delimiter)\n\n"
        return header + guide.body + "\n"
    }

    private static func parseHeader(_ lines: [String], fallbackTarget: String) -> GuideMetadata {
        var target = fallbackTarget
        var lastRefreshed: Date?
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            switch key {
            case "target":
                if !value.isEmpty { target = value }
            case "last_refreshed":
                lastRefreshed = makeDateFormatter().date(from: value)
            default:
                break
            }
        }
        return GuideMetadata(target: target, lastRefreshed: lastRefreshed)
    }

    /// Trim surrounding blank lines so the body round-trips through `serialize`.
    private static func normaliseBody(_ body: String) -> String {
        body.trimmingCharacters(in: .newlines)
    }
}
