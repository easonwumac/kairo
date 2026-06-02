import Foundation

#if canImport(Security)
import Security

public actor KeychainCredentialStore: CredentialStore {
    private let service: String
    private let accessGroup: String?

    public init(service: String = "app.kairo.credentials", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func saveSecret(_ value: String, for key: String) async throws {
        let data = Data(value.utf8)
        var query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainCredentialStoreError.unhandledStatus(status)
        }
    }

    public func readSecret(for key: String) async throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainCredentialStoreError.unhandledStatus(status)
        }
        guard let data = result as? Data else {
            throw KeychainCredentialStoreError.invalidData
        }
        return String(data: data, encoding: .utf8)
    }

    public func deleteSecret(for key: String) async throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainCredentialStoreError.unhandledStatus(status)
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}

public enum KeychainCredentialStoreError: Error, Equatable {
    case unhandledStatus(OSStatus)
    case invalidData
}
#else
public actor KeychainCredentialStore: CredentialStore {
    public init(service: String = "app.kairo.credentials", accessGroup: String? = nil) {}

    public func saveSecret(_ value: String, for key: String) async throws {
        throw KeychainCredentialStoreError.unavailable
    }

    public func readSecret(for key: String) async throws -> String? {
        throw KeychainCredentialStoreError.unavailable
    }

    public func deleteSecret(for key: String) async throws {
        throw KeychainCredentialStoreError.unavailable
    }
}

public enum KeychainCredentialStoreError: Error, Equatable {
    case unavailable
}
#endif
