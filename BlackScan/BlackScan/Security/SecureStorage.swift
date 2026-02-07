import Foundation
import Security

/// Keychain-backed secure storage for sensitive data
/// Replaces UserDefaults for credentials, auth tokens, and PII
struct SecureStorage {
    
    private let service: String
    
    init(service: String = "com.blackscan.securestorage") {
        self.service = service
    }
    
    // MARK: - String Operations
    
    /// Save a string value to Keychain
    func setString(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return setData(data, forKey: key)
    }
    
    /// Retrieve a string value from Keychain
    func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Bool Operations
    
    /// Save a boolean value to Keychain
    func setBool(_ value: Bool, forKey key: String) -> Bool {
        return setString(value ? "1" : "0", forKey: key)
    }
    
    /// Retrieve a boolean value from Keychain
    func getBool(forKey key: String) -> Bool {
        return getString(forKey: key) == "1"
    }
    
    // MARK: - Data Operations
    
    /// Save raw data to Keychain
    func setData(_ data: Data, forKey key: String) -> Bool {
        // Delete existing item first
        delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve raw data from Keychain
    func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    // MARK: - Delete Operations
    
    /// Delete a specific key from Keychain
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Delete all items for this service from Keychain
    @discardableResult
    func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Codable Operations
    
    /// Save a Codable object to Keychain
    func setCodable<T: Encodable>(_ value: T, forKey key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return setData(data, forKey: key)
    }
    
    /// Retrieve a Codable object from Keychain
    func getCodable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = getData(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Shared Instances

extension SecureStorage {
    /// Storage for Apple Auth credentials
    static let auth = SecureStorage(service: "com.blackscan.auth")
    
    /// Storage for sensitive user data
    static let userData = SecureStorage(service: "com.blackscan.userdata")
}
