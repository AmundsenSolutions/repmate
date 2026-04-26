import Foundation
import Security

/// H6 Fix: Stable client UUID stored securely in Keychain.
/// Used to replace unreliable identifierForVendor for rate-limiting.
final class KeychainManager: @unchecked Sendable {
    static let shared = KeychainManager()
    
    private let service = "com.repmate.clientuuid"
    private let account = "client_uuid"
    
    private init() {}
    
    func getClientUUID() -> String {
        if let existing = read() {
            return existing
        } else {
            let newUUID = UUID().uuidString
            save(newUUID)
            return newUUID
        }
    }
    
    private func save(_ uuidString: String) {
        guard let data = uuidString.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
