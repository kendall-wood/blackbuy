import Foundation
import AuthenticationServices
import SwiftUI

/// Manager for Apple Sign In authentication
/// Handles sign in, sign out, and user state persistence
/// Credentials stored securely in iOS Keychain (not UserDefaults)
@MainActor
class AppleAuthManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSignedIn: Bool = false
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var userId: String?
    
    // MARK: - Private Properties
    
    private let secureStorage = SecureStorage.auth
    private let userIdKey = "apple_user_id"
    private let userNameKey = "apple_user_name"
    private let userEmailKey = "apple_user_email"
    private let isSignedInKey = "is_signed_in_with_apple"
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        migrateFromUserDefaultsIfNeeded()
        checkAuthState()
    }
    
    // MARK: - Public Methods
    
    /// Check current authentication state from secure storage
    func checkAuthState() {
        isSignedIn = secureStorage.getBool(forKey: isSignedInKey)
        userId = secureStorage.getString(forKey: userIdKey)
        userName = secureStorage.getString(forKey: userNameKey)
        userEmail = secureStorage.getString(forKey: userEmailKey)
        
        // Verify credential is still valid with Apple
        if isSignedIn, let userId = userId {
            Task {
                await verifyAppleCredential(userId: userId)
            }
        }
        
        Log.debug("Auth state loaded: signed_in=\(isSignedIn)", category: .auth)
    }
    
    /// Initiate Apple Sign In flow
    func signIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        
        // Find the window scene to present from
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            controller.presentationContextProvider = AuthContextProvider(window: window)
            controller.performRequests()
        }
    }
    
    /// Sign out the current user
    func signOut() {
        isSignedIn = false
        userId = nil
        userName = nil
        userEmail = nil
        
        secureStorage.delete(forKey: isSignedInKey)
        secureStorage.delete(forKey: userIdKey)
        secureStorage.delete(forKey: userNameKey)
        secureStorage.delete(forKey: userEmailKey)
        
        Log.info("User signed out", category: .auth)
    }
    
    /// Get display name for UI
    func getDisplayName() -> String {
        if let name = userName, !name.isEmpty {
            return name
        }
        if let email = userEmail {
            return email.components(separatedBy: "@").first ?? "User"
        }
        return "Apple User"
    }
    
    /// Get user initials for avatar
    func getUserInitials() -> String {
        guard let name = userName, !name.isEmpty else {
            return "?"
        }
        
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        
        return "?"
    }
    
    // MARK: - Private Methods
    
    /// Save user credentials to Keychain (secure storage)
    private func saveUserCredentials(userId: String, name: String?, email: String?) {
        self.userId = userId
        self.userName = name
        self.userEmail = email
        self.isSignedIn = true
        
        secureStorage.setBool(true, forKey: isSignedInKey)
        secureStorage.setString(userId, forKey: userIdKey)
        if let name = name {
            secureStorage.setString(name, forKey: userNameKey)
        }
        if let email = email {
            secureStorage.setString(email, forKey: userEmailKey)
        }
        
        Log.info("Credentials saved to Keychain", category: .auth)
    }
    
    /// Verify Apple credential is still valid (handles revoked accounts)
    private func verifyAppleCredential(userId: String) async {
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: userId)
            switch state {
            case .revoked, .notFound:
                Log.warning("Apple credential revoked or not found, signing out", category: .auth)
                await MainActor.run { signOut() }
            case .authorized:
                break // Still valid
            case .transferred:
                Log.info("Apple credential transferred", category: .auth)
            @unknown default:
                break
            }
        } catch {
            Log.error("Failed to verify Apple credential", category: .auth)
        }
    }
    
    /// One-time migration from UserDefaults to Keychain
    private func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let migrationKey = "auth_migrated_to_keychain"
        
        guard !defaults.bool(forKey: migrationKey) else { return }
        
        // Check if there's data in UserDefaults to migrate
        if let oldUserId = defaults.string(forKey: userIdKey) {
            secureStorage.setString(oldUserId, forKey: userIdKey)
            if let name = defaults.string(forKey: userNameKey) {
                secureStorage.setString(name, forKey: userNameKey)
            }
            if let email = defaults.string(forKey: userEmailKey) {
                secureStorage.setString(email, forKey: userEmailKey)
            }
            secureStorage.setBool(defaults.bool(forKey: isSignedInKey), forKey: isSignedInKey)
            
            // Clean up UserDefaults
            defaults.removeObject(forKey: userIdKey)
            defaults.removeObject(forKey: userNameKey)
            defaults.removeObject(forKey: userEmailKey)
            defaults.removeObject(forKey: isSignedInKey)
            
            Log.info("Migrated auth credentials from UserDefaults to Keychain", category: .auth)
        }
        
        defaults.set(true, forKey: migrationKey)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthManager: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Log.error("Invalid credential type received", category: .auth)
            return
        }
        
        let userId = credential.user
        let fullName = credential.fullName
        let email = credential.email
        
        // Construct display name
        var displayName: String?
        if let givenName = fullName?.givenName, let familyName = fullName?.familyName {
            displayName = "\(givenName) \(familyName)"
        } else if let givenName = fullName?.givenName {
            displayName = givenName
        }
        
        // Save credentials securely
        saveUserCredentials(userId: userId, name: displayName, email: email)
        
        Log.info("Apple Sign In successful", category: .auth)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Check if user cancelled (not a real error)
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            Log.debug("User cancelled sign in", category: .auth)
            return
        }
        
        Log.error("Apple Sign In failed", category: .auth)
    }
}

// MARK: - Presentation Context Provider

/// Helper class to provide window context for Apple Sign In
class AuthContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return window
    }
}
