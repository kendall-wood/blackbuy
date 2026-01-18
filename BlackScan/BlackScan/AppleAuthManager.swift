import Foundation
import AuthenticationServices
import SwiftUI

/// Manager for Apple Sign In authentication
/// Handles sign in, sign out, and user state persistence
@MainActor
class AppleAuthManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSignedIn: Bool = false
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var userId: String?
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let userIdKey = "apple_user_id"
    private let userNameKey = "apple_user_name"
    private let userEmailKey = "apple_user_email"
    private let isSignedInKey = "is_signed_in_with_apple"
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        checkAuthState()
    }
    
    // MARK: - Public Methods
    
    /// Check current authentication state from storage
    func checkAuthState() {
        isSignedIn = userDefaults.bool(forKey: isSignedInKey)
        userId = userDefaults.string(forKey: userIdKey)
        userName = userDefaults.string(forKey: userNameKey)
        userEmail = userDefaults.string(forKey: userEmailKey)
        
        if isSignedIn {
            print("✅ User is signed in with Apple ID: \(userId ?? "unknown")")
        }
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
        
        userDefaults.removeObject(forKey: isSignedInKey)
        userDefaults.removeObject(forKey: userIdKey)
        userDefaults.removeObject(forKey: userNameKey)
        userDefaults.removeObject(forKey: userEmailKey)
        
        print("👋 User signed out")
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
    
    /// Save user credentials to storage
    private func saveUserCredentials(userId: String, name: String?, email: String?) {
        self.userId = userId
        self.userName = name
        self.userEmail = email
        self.isSignedIn = true
        
        userDefaults.set(true, forKey: isSignedInKey)
        userDefaults.set(userId, forKey: userIdKey)
        userDefaults.set(name, forKey: userNameKey)
        userDefaults.set(email, forKey: userEmailKey)
        
        print("✅ Saved user credentials for: \(userId)")
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthManager: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ Invalid credential type")
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
        
        // Save credentials
        saveUserCredentials(userId: userId, name: displayName, email: email)
        
        print("✅ Apple Sign In successful")
        print("   User ID: \(userId)")
        print("   Name: \(displayName ?? "N/A")")
        print("   Email: \(email ?? "N/A")")
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign In failed: \(error.localizedDescription)")
        
        // Check if user cancelled
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                print("   User cancelled sign in")
            case .failed:
                print("   Authorization failed")
            case .invalidResponse:
                print("   Invalid response from Apple")
            case .notHandled:
                print("   Authorization not handled")
            case .unknown:
                print("   Unknown error")
            @unknown default:
                print("   Unexpected error")
            }
        }
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
