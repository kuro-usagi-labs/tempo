import Foundation
import Security

enum SecureLocalStore {
    private static let service = "labs.kurousagi.tempo.local"

    /// An unsigned simulator build has no Keychain entitlement, even though the
    /// production app does. Keep a file-protected local fallback so onboarding
    /// and the rest of the offline experience remain usable in that environment.
    /// A successful Keychain write removes this fallback again.
    private static func fallbackKey(for key: String) -> String {
        "secure-fallback.\(key)"
    }

    static func data(for key: String) -> Data? {
        if let fallback = ProtectedFileStore.data(for: fallbackKey(for: key)) {
            return fallback
        }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    static func store(_ data: Data, for key: String) -> Bool {
        let identity: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let update: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(identity as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            _ = ProtectedFileStore.remove(fallbackKey(for: key))
            return true
        }
        if updateStatus == errSecItemNotFound {
            var newItem = identity
            newItem[kSecValueData] = data
            newItem[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            if SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess {
                _ = ProtectedFileStore.remove(fallbackKey(for: key))
                return true
            }
        }
        return ProtectedFileStore.store(data, for: fallbackKey(for: key))
    }

    @discardableResult
    static func remove(_ key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        let keychainRemoved = status == errSecSuccess || status == errSecItemNotFound
        return keychainRemoved && ProtectedFileStore.remove(fallbackKey(for: key))
    }

    @discardableResult
    static func removeAll() -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
