/// Which side of the engine boundary a rewrite ran on.
///
/// This is the pure choice between the cloud brain and the local brain. The
/// specific model is carried separately in `EngineLabel`, so this enum stays a
/// simple, Codable two-case value.
public enum EngineKind: String, Codable, Hashable, Sendable, CaseIterable {
    case cloud
    case local

    /// Capitalised name for badges and labels, "Cloud" or "Local".
    public var displayName: String {
        switch self {
        case .cloud: return "Cloud"
        case .local: return "Local"
        }
    }
}

/// The engine and the specific model used for a translation, used to tag
/// history entries.
///
/// Every `RewriteEngine` reports its own `EngineLabel` so the History Store can
/// record exactly what produced an entry, for example "Cloud · Haiku" or
/// "Local · Qwen 2.5 7B".
public struct EngineLabel: Codable, Hashable, Sendable {
    /// Cloud or local.
    public let kind: EngineKind

    /// The specific model name, for example "Haiku" or "Qwen 2.5 7B".
    public let model: String

    public init(kind: EngineKind, model: String) {
        self.kind = kind
        self.model = model
    }

    /// The label as shown in history, for example "Cloud · Haiku".
    public var displayName: String {
        "\(kind.displayName) · \(model)"
    }
}
