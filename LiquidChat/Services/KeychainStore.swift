import Foundation
import Security

/// API Key 的 Keychain 存储。
///
/// 之前 API Key 以明文存在 UserDefaults 里——同域 App 都能读到，
/// 且会随 iCloud/备份外泄。这里改为 Keychain（kSecClassGenericPassword），
/// 设备加密保护、卸载即清除。
enum KeychainStore {

    private static let service = "com.liquidchat.app.apikey"

    /// 读取 API Key
    static func readAPIKey() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api-key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return value
    }

    /// 写入 API Key；传空串则删除条目
    static func writeAPIKey(_ value: String) {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api-key"
        ]

        guard !key.isEmpty else {
            SecItemDelete(baseQuery as CFDictionary)
            return
        }

        let data = Data(key.utf8)

        // 先尝试更新，已存在则覆盖
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    /// 是否已保存
    static func hasAPIKey() -> Bool {
        !readAPIKey().isEmpty
    }
}
