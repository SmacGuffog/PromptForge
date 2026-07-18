import Foundation

/// The read side of style guides, the seam the Translator depends on.
///
/// Kept minimal on purpose: the Translator only ever reads guides, so it should
/// not see saving or seeding. Editing and refresh use the concrete
/// `StyleGuideStore`.
public protocol StyleGuideProviding {
    /// The targets that have a guide on disk, sorted by display name.
    func availableTargets() throws -> [Target]

    /// Load the guide for a target.
    func loadGuide(for target: Target) throws -> StyleGuide
}

/// A failure from the Style Guide Store.
public enum StyleGuideStoreError: Error, Equatable, Sendable {
    /// No guide file exists for the requested target.
    case guideNotFound(filename: String)
}

extension StyleGuideStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .guideNotFound(let filename):
            return "No style guide was found for \(filename)."
        }
    }
}

/// Owns the per-target style guides as editable Markdown files on disk.
///
/// On first run it seeds a user-owned folder from the guides bundled with the
/// app, copying only files that are not already present so it never overwrites
/// an edit. After that the user owns the files: they can be edited in-app or in
/// an external editor. The store loads them, lists them, and saves edits back.
/// It knows nothing about rewriting or the UI.
public final class StyleGuideStore: StyleGuideProviding {
    private let directory: URL
    private let seededGuidesURL: URL?
    private let fileManager: FileManager

    /// The folder inside the app bundle holding the seeded guides.
    public static var bundledSeedsURL: URL? {
        Bundle.module.url(forResource: "StyleGuides", withExtension: nil)
    }

    /// The default on-disk folder for guides:
    /// `~/Library/Application Support/PromptForge/StyleGuides`.
    ///
    /// Guides live in their own subfolder of the app's known folder so settings
    /// and history can sit alongside as siblings.
    public static func defaultDirectory(fileManager: FileManager = .default) throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport
            .appendingPathComponent("PromptForge", isDirectory: true)
            .appendingPathComponent("StyleGuides", isDirectory: true)
    }

    /// Create a store over a guides folder, seeding it on first run.
    ///
    /// - Parameters:
    ///   - directory: the on-disk folder holding the editable guides.
    ///   - seededGuidesURL: the folder of bundled seed guides, or nil to skip
    ///     seeding. Defaults to the guides bundled with the app.
    ///   - fileManager: the file manager to use, injectable for testing.
    public init(
        directory: URL,
        seededGuidesURL: URL? = StyleGuideStore.bundledSeedsURL,
        fileManager: FileManager = .default
    ) throws {
        self.directory = directory
        self.seededGuidesURL = seededGuidesURL
        self.fileManager = fileManager
        try seedIfNeeded()
    }

    // MARK: StyleGuideProviding

    public func availableTargets() throws -> [Target] {
        let files = try guideFiles()
        let targets = files.map { url -> Target in
            let filename = url.lastPathComponent
            let name = (try? loadGuide(atFilename: filename))?.metadata.target
                ?? Self.displayName(fromFilename: filename)
            return Target(name: name, guideFilename: filename)
        }
        return targets.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    public func loadGuide(for target: Target) throws -> StyleGuide {
        try loadGuide(atFilename: target.guideFilename)
    }

    // MARK: Editing

    /// Save an edited guide back to disk in canonical form.
    public func save(_ guide: StyleGuide, for target: Target) throws {
        let url = directory.appendingPathComponent(target.guideFilename)
        let text = GuideMarkdown.serialize(guide)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: Seeding

    /// Create the guides folder if needed and copy any bundled seed that is not
    /// already present. Copying only missing files means user edits are never
    /// overwritten. Idempotent.
    public func seedIfNeeded() throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let seededGuidesURL else { return }

        let seeds = try fileManager.contentsOfDirectory(
            at: seededGuidesURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "md" }

        for seed in seeds {
            let destination = directory.appendingPathComponent(seed.lastPathComponent)
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.copyItem(at: seed, to: destination)
            }
        }
    }

    // MARK: Helpers

    private func guideFiles() throws -> [URL] {
        try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
    }

    private func loadGuide(atFilename filename: String) throws -> StyleGuide {
        let url = directory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else {
            throw StyleGuideStoreError.guideNotFound(filename: filename)
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        return GuideMarkdown.parse(text, fallbackTarget: Self.displayName(fromFilename: filename))
    }

    /// Derive a display name from a guide filename when no header is available.
    /// "claude.md" becomes "Claude", "github-copilot.md" becomes "Github Copilot".
    static func displayName(fromFilename filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        return base
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
