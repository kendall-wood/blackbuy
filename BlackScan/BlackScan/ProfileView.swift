import SwiftUI
import AuthenticationServices

/// Profile modal - matches screenshot 4 exactly
struct ProfileView: View {
    
    @Binding var selectedTab: BottomNavBar.AppTab
    @EnvironmentObject var authManager: AppleAuthManager
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
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
                    
                    // Legal Section
                    legalSection
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
                selectedTab = .scan
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(red: 0.26, green: 0.63, blue: 0.95))
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Profile Title
            Text("Profile")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
            
            Spacer()
            
            // Spacer to balance the layout
            Color.clear
                .frame(width: 50, height: 50)
        }
        .frame(height: 60)
        .padding(.horizontal, 20)
        .background(Color.white)
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(spacing: 16) {
            // Avatar Circle
            ZStack {
                Circle()
                    .fill(Color(red: 0.26, green: 0.63, blue: 0.95))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.white)
            }
            
            // Welcome Text
            VStack(spacing: 8) {
                Text("Welcome")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.black)
                
                Text("Sign in to save products")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(.systemGray))
            }
        }
    }
    
    // MARK: - Get Started Section
    
    private var getStartedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Get Started")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
            
            // Save Your Favorites Card
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("Save Your Favorites")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("Sign in with Apple ID to save products and sync across all your devices")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(.systemGray))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
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
                .frame(height: 48)
                .cornerRadius(12)
                .padding(.horizontal, 50)
                .padding(.bottom, 24)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Saved Products")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
            
            VStack(spacing: 0) {
                // Saved Items Row
                HStack {
                    Image(systemName: "heart")
                        .font(.system(size: 18))
                        .foregroundColor(Color(.systemGray))
                        .frame(width: 40)
                    
                    Text("Saved Items")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Text("\(savedProductsManager.savedProducts.count)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                
                Divider()
                    .padding(.leading, 64)
                
                // Clear All Saved Row
                Button(action: {
                    savedProductsManager.clearAllSavedProducts()
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                            .foregroundColor(.red)
                            .frame(width: 40)
                        
                        Text("Clear All Saved")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
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
    
    // MARK: - Legal Section
    
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(red: 0.26, green: 0.63, blue: 0.95))
                
                Text("Legal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 24)
            
            VStack(spacing: 0) {
                // Privacy Policy Row
                Button(action: {
                    if let url = URL(string: "https://kendall-wood.github.io/blackbuy/privacy-policy/") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(.systemGray))
                            .frame(width: 40)
                        
                        Text("Privacy Policy")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(.systemGray3))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
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
