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
                VStack(spacing: 48) {
                    // Avatar and Welcome
                    welcomeSection
                    
                    // Get Started Section
                    if !authManager.isSignedIn {
                        getStartedSection
                    }
                    
                    // Saved Products Section
                    savedProductsSection
                }
                .padding(.top, 40)
                .padding(.bottom, 60)
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
        VStack(spacing: 24) {
            // Avatar Circle
            ZStack {
                Circle()
                    .fill(Color(red: 0, green: 0.48, blue: 1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.white)
            }
            
            // Welcome Text
            VStack(spacing: 12) {
                Text("Welcome")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.black)
                
                Text("Sign in to save products")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color(.systemGray))
            }
        }
    }
    
    // MARK: - Get Started Section
    
    private var getStartedSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                
                Text("Get Started")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 24)
            
            // Save Your Favorites Card
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Save Your Favorites")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.black)
                    
                    Text("Sign in with Apple ID to save products and sync across all your devices")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(.systemGray))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 32)
                
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
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
                .onTapGesture {
                    authManager.signIn()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
            )
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Saved Products Section
    
    private var savedProductsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 26))
                    .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                
                Text("Saved Products")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 24)
            
            VStack(spacing: 0) {
                // Saved Items Row
                HStack {
                    Image(systemName: "heart")
                        .font(.system(size: 22))
                        .foregroundColor(Color(.systemGray))
                        .frame(width: 40)
                    
                    Text("Saved Items")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Text("\(savedProductsManager.savedProducts.count)")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                Divider()
                    .padding(.leading, 64)
                
                // Clear All Saved Row
                Button(action: {
                    savedProductsManager.clearAllSavedProducts()
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 22))
                            .foregroundColor(.red)
                            .frame(width: 40)
                        
                        Text("Clear All Saved")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
            .padding(.horizontal, 24)
        }
    }
}

#Preview("Profile - Signed Out") {
    ProfileView()
        .environmentObject(AppleAuthManager())
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
}
