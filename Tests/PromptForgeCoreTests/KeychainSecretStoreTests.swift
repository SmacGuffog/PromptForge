#if canImport(Security)
import XCTest
@testable import PromptForgeCore

/// These tests exercise the real macOS Keychain, so they run only where the
/// Security framework is available. Each test uses a unique service name and
/// cleans up after itself. In a sandboxed environment without Keychain
/// entitlement the store reports errSecMissingEntitlement (-34018); the tests
/// skip rather than fail in that case.
final class KeychainSecretStoreTests: XCTestCase {
    private let missingEntitlement: Int32 = -34018

    private func makeStore() -> KeychainSecretStore {
        KeychainSecretStore(
            service: "com.promptforge.tests.\(UUID().uuidString)",
            account: "anthropic-api-key"
        )
    }

    /// Set a key, skipping the test if the environment forbids Keychain access.
    private func setOrSkip(_ store: KeychainSecretStore, _ key: String) throws {
        do {
            try store.setAPIKey(key)
        } catch let error as KeychainError {
            if case .unexpectedStatus(let status) = error, status == missingEntitlement {
                throw XCTSkip("Keychain access is unavailable in this environment (errSecMissingEntitlement).")
            }
            throw error
        }
    }

    func testMissingKeyReturnsNil() throws {
        let store = makeStore()
        XCTAssertNil(try store.apiKey())
    }

    func testRoundTrip() throws {
        let store = makeStore()
        defer { try? store.deleteAPIKey() }

        try setOrSkip(store, "sk-ant-test-123")
        XCTAssertEqual(try store.apiKey(), "sk-ant-test-123")
    }

    func testSetOverwritesExistingKey() throws {
        let store = makeStore()
        defer { try? store.deleteAPIKey() }

        try setOrSkip(store, "first-key")
        try store.setAPIKey("second-key")
        XCTAssertEqual(try store.apiKey(), "second-key")
    }

    func testDeleteRemovesKey() throws {
        let store = makeStore()
        defer { try? store.deleteAPIKey() }

        try setOrSkip(store, "to-be-deleted")
        try store.deleteAPIKey()
        XCTAssertNil(try store.apiKey())
    }

    func testDeleteMissingKeyIsNotAnError() throws {
        let store = makeStore()
        XCTAssertNoThrow(try store.deleteAPIKey())
    }
}
#endif
