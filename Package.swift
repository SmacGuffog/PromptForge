// swift-tools-version: 5.9
import PackageDescription

// PromptForge is a native macOS menu-bar app. The package separates portable
// logic (PromptForgeCore) from the Mac-locked SwiftUI UI (PromptForgeApp) so
// the core stays reusable if the app is productised later.
//
// This manifest is scaffolding. The target source directories are populated in
// Phase 1 of the implementation plan; until then a checkout has the layout but
// no Swift sources, so `swift build` is expected to report missing sources.
let package = Package(
    name: "PromptForge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PromptForgeCore", targets: ["PromptForgeCore"]),
        .executable(name: "PromptForgeApp", targets: ["PromptForgeApp"])
    ],
    dependencies: [
        // No third-party dependencies in v1. The Anthropic and Ollama clients
        // are written against URLSession directly.
    ],
    targets: [
        // Portable logic: rewrite engines, style guide store, translator,
        // history store, refresh service. No AppKit or SwiftUI here.
        .target(
            name: "PromptForgeCore",
            exclude: ["README.md"],
            resources: [
                .copy("Resources/StyleGuides")
            ]
        ),
        // Mac-locked SwiftUI menu-bar UI. The only target that imports SwiftUI
        // and AppKit. Talks to the core, never to an engine directly.
        .executableTarget(
            name: "PromptForgeApp",
            dependencies: ["PromptForgeCore"],
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "PromptForgeCoreTests",
            dependencies: ["PromptForgeCore"],
            exclude: ["README.md"]
        )
    ]
)
