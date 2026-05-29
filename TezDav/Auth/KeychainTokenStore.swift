import Foundation
import Security

final class KeychainTokenStore: TokenStore {
    private let service: String
    private let account: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(service: String = "TezDav.Strava", account: String = "token") {
        self.service = service
        self.account = account
    }

    func loadToken() throws -> StravaToken? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw TokenStoreError.keychain(status)
        }
        guard let data = result as? Data else {
            throw TokenStoreError.decodeFailed
        }
        do {
            return try decoder.decode(StravaToken.self, from: data)
        } catch {
            throw TokenStoreError.decodeFailed
        }
    }

    func saveToken(_ token: StravaToken) throws {
        guard let data = try? encoder.encode(token) else {
            throw TokenStoreError.encodeFailed
        }

        var query = baseQuery()
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }
        if status != errSecItemNotFound {
            throw TokenStoreError.keychain(status)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw TokenStoreError.keychain(addStatus)
        }
    }

    func clearToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw TokenStoreError.keychain(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
