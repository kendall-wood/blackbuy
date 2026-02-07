import SwiftUI
import AuthenticationServices

/// Profile view
struct ProfileView: View {
    
    @Binding var selectedTab: AppTab
    var previousTab: AppTab = .scan
    @EnvironmentObject var authManager: AppleAuthManager
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var savedCompaniesManager: SavedCompaniesManager
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppHeader(centerContent: .title("Profile"), onBack: { selectedTab = previousTab })
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar and Welcome
                    welcomeSection
                    
                    // Sign In Section
                    if !authManager.isSignedIn {
                        signInSection
                    }
                    
                    // Settings Section
                    settingsSection
                    
                    // Legal Section
                    legalSection
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .background(DS.cardBackground)
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(spacing: 14) {
            // Avatar Circle
            ZStack {
                Circle()
                    .fill(DS.brandBlue.opacity(0.1))
                    .frame(width: 96, height: 96)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(DS.brandBlue)
            }
            
            // Welcome Text
            VStack(spacing: 4) {
                Text("Welcome")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                
                Text(authManager.isSignedIn ? "Manage your account" : "Sign in to save your favorites")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.systemGray))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }
    
    // MARK: - Sign In Section
    
    private var signInSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Save Your Favorites")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("Sign in with Apple to save products and sync across your devices")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.systemGray))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
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
            .padding(.horizontal, 40)
            .onTapGesture {
                authManager.signIn()
            }
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: DS.radiusLarge)
                .fill(Color.white)
                .dsCardShadow()
        )
        .padding(.horizontal, DS.horizontalPadding)
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(DS.sectionHeader)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
            
            VStack(spacing: 0) {
                // Clear Saved Products
                settingsRow(
                    icon: "heart.slash",
                    iconColor: DS.brandBlue,
                    title: "Clear Saved Products",
                    subtitle: "\(savedProductsManager.savedProducts.count) items",
                    action: { savedProductsManager.clearAllSavedProducts() }
                )
                
                Divider()
                    .padding(.leading, 56)
                
                // Clear Cart
                settingsRow(
                    icon: "cart.badge.minus",
                    iconColor: DS.brandBlue,
                    title: "Clear Cart",
                    subtitle: "\(cartManager.totalItemCount) items",
                    action: { cartManager.clearCart() }
                )
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Legal")
                .font(DS.sectionHeader)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
            
            VStack(spacing: 0) {
                settingsRow(
                    icon: "hand.raised.fill",
                    iconColor: DS.brandBlue,
                    title: "Privacy Policy",
                    showChevron: true,
                    action: {
                        if let url = URL(string: "https://kendall-wood.github.io/blackbuy/privacy-policy/") {
                            UIApplication.shared.open(url)
                        }
                    }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: DS.radiusLarge)
                    .fill(Color.white)
                    .dsCardShadow()
            )
            .padding(.horizontal, DS.horizontalPadding)
        }
    }
    
    // MARK: - Settings Row Helper
    
    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        showChevron: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.black)
                
                Spacer()
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color(.systemGray2))
                }
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(.systemGray3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Profile - Signed Out") {
    ProfileView(selectedTab: .constant(.profile))
        .environmentObject(AppleAuthManager())
        .environmentObject(SavedProductsManager())
        .environmentObject(SavedCompaniesManager())
        .environmentObject(CartManager())
}
