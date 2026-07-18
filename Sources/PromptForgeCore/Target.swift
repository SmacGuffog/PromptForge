import Foundation

/// Identity of a target tool the user can translate a prompt for, such as
/// Claude, GPT, or Cursor.
///
/// A `Target` is a plain value: a display name plus the filename of its style
/// guide on disk. It carries no behaviour. The Style Guide Store owns loading
/// and saving; the Translator uses a `Target` only to ask the Store for the
/// right guide.
public struct Target: Codable, Hashable, Sendable, Identifiable {
    /// Stable identity. The name is unique across targets.
    public var id: String { name }

    /// Human-readable name shown in the UI, for example "Claude" or "GPT".
    public let name: String

    /// Filename of this target's style guide, for example "claude.md".
    public let guideFilename: String

    /// Create a target with an explicit guide filename.
    public init(name: String, guideFilename: String) {
        self.name = name
        self.guideFilename = guideFilename
    }

    /// Create a target, deriving the guide filename from the name.
    ///
    /// "Claude" becomes "claude.md", "GPT" becomes "gpt.md", and
    /// "GitHub Copilot" becomes "github-copilot.md".
    public init(name: String) {
        self.init(name: name, guideFilename: Self.defaultGuideFilename(for: name))
    }

    /// Derive a guide filename from a target name: lowercased, spaces to
    /// hyphens, with a `.md` extension.
    public static func defaultGuideFilename(for name: String) -> String {
        let slug = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "\(slug).md"
    }
}
