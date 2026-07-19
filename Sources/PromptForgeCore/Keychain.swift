import Foundation
#if canImport(Security)
import Security
#endif

/// Stores the one secret the app holds: the Anthropic API key.
///
/// The key lives in the macOS Keychain, never in a settings file or anything
/// that might be committed or synced. This protocol lets the Translator and the
/// cloud engine depend on secret storage without knowing it is the Keychain, so
/// they can be tested with a fake.
public protocol SecretStore {
    /// Store or replace the API key.
    func setAPIKey(_ key: String) throws

    /// The stored API key, or nil if none is set.
    func apiKey() throws -> String?

    /// Remove the stored API key. Removing an absent key is not an error.
    func deleteAPIKey() throws
}

/// A failure from the Keychain-backed secret store.
public enum KeychainError: Error, Equatable, Sendable {
    /// The Keychain is not available on this platform.
    case unavailable

    /// The Keychain returned an unexpected status code.
    case unexpectedStatus(Int32)

    /// A stored value could not be decoded as UTF-8 text.
    case dataEncoding
}

extension KeychainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "The system Keychain is not available on this platform."
        case .unexpectedStatus(let status):
            return "The Keychain returned an unexpected status (\(status))."
        case .dataEncoding:
            return "The stored key could not be read as text."
        }
    }
}

/// A `SecretStore` backed by the macOS Keychain (a generic password item).
///
/// On platforms without the Security framework the methods throw
/// `KeychainError.unavailable`, so the module still compiles and the pure
/// settings logic can be tested anywhere.
public struct KeychainSecretStore: SecretStore {
    /// The Keychain service, typically the app bundle identifier.
    public let service: String

    /// The account under which the key is stored.
    public let account: String

    public init(
        service: String = "com.promptforge.PromptForge",
        account: String = "anthropic-api-key"
    ) {
        self.service = service
        self.account = account
    }

    public func setAPIKey(_ key: String) throws {
        #if canImport(Security)
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
        #else
        throw KeychainError.unavailable
        #endif
    }

    public func apiKey() throws -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let key = String(data: data, encoding: .utf8)
            else {
                throw KeychainError.dataEncoding
            }
            return key
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
        #else
        throw KeychainError.unavailable
        #endif
    }

    public func deleteAPIKey() throws {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
        #else
        throw KeychainError.unavailable
        #endif
    }
}
