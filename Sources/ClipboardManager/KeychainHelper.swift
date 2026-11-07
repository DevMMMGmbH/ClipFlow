import Foundation
import Security
import CryptoKit

/// Hält den symmetrischen Schlüssel, mit dem SnippetStore seine Datei verschlüsselt,
/// persistent im macOS-Schlüsselbund (statt im Klartext neben den Daten).
enum KeychainHelper {
    private static let service = "local.misgin.clipflow"
    private static let account = "snippetsEncryptionKey"

    static func loadOrCreateKey() -> SymmetricKey {
        if let data = load() {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        save(key.withUnsafeBytes { Data($0) })
        return key
    }

    private static func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    private static func save(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
