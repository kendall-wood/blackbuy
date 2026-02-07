import SwiftUI
import AuthenticationServices

/// Profile modal
struct ProfileView: View {
    
    @Binding var selectedTab: AppTab
    @EnvironmentObject var authManager: AppleAuthManager
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppHeader(centerContent: .title("Profile"), onBack: { selectedTab = .scan })
            
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
                .padding(.top, DS.horizontalPadding)
                .padding(.bottom, 40)
            }
            .background(DS.cardBackground)
        }
        .background(DS.cardBackground)
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(spacing: 16) {
            // Avatar Circle
            ZStack {
                Circle()
                    .fill(DS.brandBlue)
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
                .font(DS.sectionHeader)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
            
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
                        .padding(.horizontal, DS.horizontalPadding)
                }
                .padding(.top, DS.horizontalPadding)
                
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
                .cornerRadius(DS.radiusMedium)
                .padding(.horizontal, 50)
                .padding(.bottom, DS.horizontalPadding)
                .onTapGesture {
                    authManager.signIn()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.radiusLarge)
                    .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
            )
            .padding(.horizontal, DS.horizontalPadding)
        }
    }
    
    // MARK: - Saved Products Section
    
    private var savedProductsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saved Products")
                .font(DS.sectionHeader)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
            
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
                .padding(.horizontal, DS.horizontalPadding)
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
                            .foregroundColor(DS.brandRed)
                            .frame(width: 40)
                        
                        Text("Clear All Saved")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(DS.brandRed)
                        
                        Spacer()
                    }
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: DS.radiusLarge)
                    .fill(Color.white)
                    .dsCardShadow()
            )
            .padding(.horizontal, DS.horizontalPadding)
        }
    }
    
    // MARK: - Legal Section
    
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 22))
                    .foregroundColor(DS.brandBlue)
                
                Text("Legal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, DS.horizontalPadding)
            
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
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: DS.radiusLarge)
                    .fill(Color.white)
                    .dsCardShadow()
            )
            .padding(.horizontal, DS.horizontalPadding)
        }
    }
}

#Preview("Profile - Signed Out") {
    ProfileView(selectedTab: .constant(.profile))
        .environmentObject(AppleAuthManager())
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
}
