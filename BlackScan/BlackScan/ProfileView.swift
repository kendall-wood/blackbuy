import SwiftUI
import AuthenticationServices

/// Profile modal - matches screenshot 4 exactly
struct ProfileView: View {
    
    @EnvironmentObject var authManager: AppleAuthManager
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            header
            
            // Content
            ScrollView {
                VStack(spacing: 32) {
                    // Avatar and Welcome
                    welcomeSection
                    
                    // Get Started Section
                    if !authManager.isSignedIn {
                        getStartedSection
                    }
                    
                    // Saved Products Section
                    savedProductsSection
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.white)
        }
        .background(Color.white)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            // Back Button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Profile Title
            Text("Profile")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.black)
            
            Spacer()
            
            // Spacer for symmetry
            Color.clear
                .frame(width: 22)
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(spacing: 20) {
            // Avatar Circle
            ZStack {
                Circle()
                    .fill(Color(red: 0, green: 0.48, blue: 1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
            }
            
            // Welcome Text
            VStack(spacing: 8) {
                Text("Welcome")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.black)
                
                Text("Sign in to save products")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color(.systemGray))
            }
        }
    }
    
    // MARK: - Get Started Section
    
    private var getStartedSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                
                Text("Get Started")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 20)
            
            // Save Your Favorites Card
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("Save Your Favorites")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                    
                    Text("Sign in with Apple ID to save products and sync across all your devices")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(.systemGray))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 24)
                
                // Sign In Button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        // Handled by AuthManager
                    }
                )
                .frame(height: 56)
                .cornerRadius(12)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .onTapGesture {
                    authManager.signIn()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Saved Products Section
    
    private var savedProductsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                
                Text("Saved Products")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                // Saved Items Row
                HStack {
                    Image(systemName: "heart")
                        .font(.system(size: 20))
                        .foregroundColor(Color(.systemGray))
                        .frame(width: 32)
                    
                    Text("Saved Items")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Text("\(savedProductsManager.savedProducts.count)")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                    .padding(.leading, 52)
                
                // Clear All Saved Row
                Button(action: {
                    savedProductsManager.clearAllSavedProducts()
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                            .frame(width: 32)
                        
                        Text("Clear All Saved")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
        }
    }
}

#Preview("Profile - Signed Out") {
    ProfileView()
        .environmentObject(AppleAuthManager())
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
}
