import Foundation
import UIKit
import Security
import CryptoKit

/// User Authentication Service for BlackScan
/// Provides anonymous user identification and rate limiting
@MainActor
class UserAuthService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var dailyScansRemaining = 10
    @Published var userID: String?
    
    // MARK: - Private Properties
    
    private let keychainService = "com.blackscan.userauth"
    private let userIDKey = "anonymous_user_id"
    private let maxDailyScans = 10
    
    // MARK: - Initialization
    
    init() {
        loadOrCreateUserID()
    }
    
    // MARK: - Public Methods
    
    /// Check if user can make a scan request
    func canMakeScanRequest() -> Bool {
        return dailyScansRemaining > 0
    }
    
    /// Record a scan request and update remaining count
    func recordScanRequest() {
        guard dailyScansRemaining > 0 else { 
            Log.warning("Rate limit exceeded", category: .auth)
            return 
        }
        
        dailyScansRemaining -= 1
        updateLocalScanCount()
        
        Log.debug("Scan request recorded. Remaining: \(dailyScansRemaining)", category: .auth)
        
        // TODO: Also update backend when implemented
        // Task { await updateBackendScanCount() }
    }
    
    /// Reset daily scan count (for testing)
    func resetDailyScans() {
        dailyScansRemaining = maxDailyScans
        clearLocalScanCount()
    }
    
    // MARK: - Privacy Controls
    
    /// Clear all user data for privacy compliance
    func clearUserData() {
        // Clear Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService
        ]
        
        SecItemDelete(query as CFDictionary)
        
        // Clear UserDefaults scan counts
        let defaults = UserDefaults.standard
        let scanCountKeys = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("scan_count_") }
        
        for key in scanCountKeys {
            defaults.removeObject(forKey: key)
        }
        
        // Reset state
        userID = nil
        isAuthenticated = false
        dailyScansRemaining = maxDailyScans
        
        Log.info("All user data cleared", category: .auth)
    }
    
    /// Export user data for privacy compliance (GDPR-style)
    func exportUserData() -> [String: Any] {
        return [
            "user_id_prefix": userID?.prefix(8) ?? "none", // Anonymized
            "daily_scans_remaining": dailyScansRemaining,
            "is_authenticated": isAuthenticated,
            "data_created": "Generated on device",
            "data_stored": "Device keychain only",
            "data_shared": "Never shared with third parties",
            "data_retention": "User ID: indefinite, Scan counts: 24 hours",
            "privacy_level": "Anonymous, non-personally identifiable"
        ]
    }
    
    /// Get privacy-compliant user statistics
    func getPrivacyStats() -> [String: Any] {
        return [
            "total_scans_today": maxDailyScans - dailyScansRemaining,
            "account_type": "anonymous",
            "data_retention": "24 hours for usage, indefinite for user ID",
            "data_sharing": "none",
            "third_party_access": "none",
            "encryption": "iOS Keychain (hardware-backed)",
            "data_minimization": "enabled"
        ]
    }
    
    // MARK: - Private Methods
    
    private func loadOrCreateUserID() {
        if let existingID = loadUserIDFromKeychain() {
            self.userID = existingID
            self.isAuthenticated = true
            loadLocalScanCount()
            
            Log.info("User authenticated", category: .auth)
        } else {
            let newID = generateUserID()
            saveUserIDToKeychain(newID)
            self.userID = newID
            self.isAuthenticated = true
            self.dailyScansRemaining = maxDailyScans
            
            Log.info("New user created", category: .auth)
        }
    }
    
    private func generateUserID() -> String {
        let uuid = UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970)
        let deviceModel = UIDevice.current.model.replacingOccurrences(of: " ", with: "_")
        
        var combined = "user_\(uuid)_\(timestamp)_\(deviceModel)"
        
        // Add secure random entropy
        var randomBytes = [UInt8](repeating: 0, count: 16)
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        
        if result == errSecSuccess {
            let randomHex = randomBytes.map { String(format: "%02x", $0) }.joined()
            combined += "_\(randomHex)"
        } else {
            Log.warning("Secure random unavailable, using standard generation", category: .auth)
        }
        
        // Hash for privacy and consistent length
        let inputData = Data(combined.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Keychain Management
    
    private func saveUserIDToKeychain(_ userID: String) {
        let data = userID.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userIDKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Log.error("Failed to save user ID to keychain", category: .auth)
        }
    }
    
    private func loadUserIDFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userIDKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let userID = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return userID
    }
    
    // MARK: - Local Rate Limiting (Fallback)
    
    private func loadLocalScanCount() {
        let today = todayKey()
        let usedScans = UserDefaults.standard.integer(forKey: today)
        dailyScansRemaining = max(0, maxDailyScans - usedScans)
        
        // Clean up old entries
        cleanupOldScanCounts()
    }
    
    private func updateLocalScanCount() {
        let today = todayKey()
        let usedScans = UserDefaults.standard.integer(forKey: today)
        UserDefaults.standard.set(usedScans + 1, forKey: today)
    }
    
    private func clearLocalScanCount() {
        let today = todayKey()
        UserDefaults.standard.removeObject(forKey: today)
    }
    
    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "scan_count_\(formatter.string(from: Date()))"
    }
    
    private func cleanupOldScanCounts() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        let scanCountKeys = allKeys.filter { $0.hasPrefix("scan_count_") }
        let today = todayKey()
        
        for key in scanCountKeys {
            if key != today {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
}

// MARK: - Backend Integration (Future Implementation)

extension UserAuthService {
    
    /// Validate user with backend (when backend is implemented)
    private func validateUserWithBackend() async {
        guard let userID = userID else { return }
        
        // TODO: Implement when backend API is ready
        // This will replace local rate limiting with server-side enforcement
        
        Log.debug("Backend validation not yet implemented", category: .auth)
    }
    
    /// Register user with backend (when backend is implemented)
    private func registerUserWithBackend() async {
        guard let userID = userID else { return }
        
        // TODO: Implement when backend API is ready
        Log.debug("Backend registration not yet implemented", category: .auth)
    }
}

// MARK: - Error Types

enum UserAuthError: Error, LocalizedError {
    case keychainError
    case userIDGenerationFailed
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .keychainError:
            return "Failed to access secure storage"
        case .userIDGenerationFailed:
            return "Failed to generate user identifier"
        case .rateLimitExceeded:
            return "Daily scan limit exceeded"
        }
    }
}
