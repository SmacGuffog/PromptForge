import Foundation

/// One recorded translation.
///
/// The raw input is stored verbatim, exactly as dictated or typed, so the
/// history doubles as an informal record of how rough prompts map to optimised
/// ones.
public struct HistoryEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID

    /// The raw input, stored verbatim (unpolished).
    public let rawInput: String

    /// The optimised output returned by the engine.
    public let optimisedOutput: String

    /// The target tool this translation was for, by name.
    public let target: String

    /// The engine and specific model that produced the output, for example
    /// "Cloud · Haiku".
    public let engine: EngineLabel

    /// When the translation completed.
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        rawInput: String,
        optimisedOutput: String,
        target: String,
        engine: EngineLabel,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.rawInput = rawInput
        self.optimisedOutput = optimisedOutput
        self.target = target
        self.engine = engine
        self.timestamp = timestamp
    }
}

/// The write side of history, the seam the Translator depends on.
///
/// Kept minimal on purpose: the Translator only ever records, so it should not
/// see reading or clearing. The History tab uses the concrete `HistoryStore`.
public protocol HistoryRecording {
    /// Persist one entry, appended the moment a translation completes.
    func record(_ entry: HistoryEntry) throws
}

/// A failure from the History Store.
public enum HistoryStoreError: Error, Equatable, Sendable {
    /// The history file could not be read as UTF-8 text.
    case dataEncoding
}

extension HistoryStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .dataEncoding:
            return "The history file could not be read as text."
        }
    }
}

/// Owns the translation history as an append-only JSON Lines file.
///
/// One entry is written per line the moment a translation completes. Reading
/// returns entries newest first. Recording is isolated from translation logic;
/// this type knows nothing about engines, guides, or the UI.
public final class HistoryStore: HistoryRecording {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    /// The default history file:
    /// `~/Library/Application Support/PromptForge/history.jsonl`, a sibling of
    /// the guides and settings.
    public static func defaultFileURL(fileManager: FileManager = .default) throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport
            .appendingPathComponent("PromptForge", isDirectory: true)
            .appendingPathComponent("history.jsonl")
    }

    // MARK: HistoryRecording

    public func record(_ entry: HistoryEntry) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var line = try Self.makeEncoder().encode(entry)
        line.append(0x0A) // newline, one entry per line

        if fileManager.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } else {
            try line.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: Reading

    /// All entries, newest first. A missing file yields an empty array;
    /// unparseable lines are skipped rather than failing the whole read.
    public func entries() throws -> [HistoryEntry] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        guard let text = String(data: data, encoding: .utf8) else {
            throw HistoryStoreError.dataEncoding
        }

        let decoder = Self.makeDecoder()
        var entries: [HistoryEntry] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if let entry = try? decoder.decode(HistoryEntry.self, from: Data(line.utf8)) {
                entries.append(entry)
            }
        }
        // The file is append-only and chronological, so reversing it gives
        // reverse-chronological order (newest first).
        return Array(entries.reversed())
    }

    /// Remove all history.
    public func clear() throws {
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: Coding

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys] // compact, one line per entry
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
