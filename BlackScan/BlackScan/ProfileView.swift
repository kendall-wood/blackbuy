import SwiftUI
import AuthenticationServices

/// Profile view
struct ProfileView: View {
    
    @Binding var selectedTab: AppTab
    var onBack: () -> Void = {}
    @EnvironmentObject var authManager: AppleAuthManager
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var savedCompaniesManager: SavedCompaniesManager
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var scanHistoryManager: ScanHistoryManager
    
    @State private var showDeleteConfirmation = false
    @State private var showExportSheet = false
    @State private var exportData: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppHeader(centerContent: .logo, onBack: onBack)
            
            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Avatar and Welcome
                    welcomeSection
                    
                    // Sign In Section
                    if !authManager.isSignedIn {
                        signInSection
                    }
                    
                    // Settings Section
                    settingsSection
                    
                    // Privacy Section
                    privacySection
                    
                    // Legal Section
                    legalSection
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .background(DS.cardBackground)
        .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Everything", role: .destructive) {
                deleteAllUserData()
            }
        } message: {
            Text("This will permanently delete all your saved products, companies, cart items, scan history, and sign you out. This action cannot be undone.")
        }
        .sheet(isPresented: $showExportSheet) {
            NavigationView {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(exportData)
                        .font(.system(size: 13, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Your Data")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { showExportSheet = false }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        ShareLink(item: exportData) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
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
                    switch result {
                    case .success(let authorization):
                        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            let userId = credential.user
                            let fullName = credential.fullName
                            let email = credential.email
                            
                            var displayName: String?
                            if let givenName = fullName?.givenName, let familyName = fullName?.familyName {
                                displayName = "\(givenName) \(familyName)"
                            } else if let givenName = fullName?.givenName {
                                displayName = givenName
                            }
                            
                            authManager.handleSignInSuccess(userId: userId, name: displayName, email: email)
                        }
                    case .failure(let error):
                        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                            Log.debug("User cancelled sign in", category: .auth)
                        } else {
                            Log.error("Apple Sign In failed", category: .auth)
                        }
                    }
                }
            )
            .frame(height: 48)
            .cornerRadius(DS.radiusMedium)
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: DS.radiusLarge)
                .fill(Color.white)
                .dsCardShadow(cornerRadius: DS.radiusLarge)
        )
        .padding(.horizontal, DS.horizontalPadding)
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Data")
                .font(DS.sectionHeader)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
            
            VStack(spacing: 0) {
                // Export Data
                settingsRow(
                    icon: "square.and.arrow.up",
                    iconColor: DS.brandBlue,
                    title: "Export My Data",
                    showChevron: true,
                    action: { exportMyData() }
                )
                
                Divider()
                    .padding(.leading, 56)
                
                // Delete All Data
                settingsRow(
                    icon: "trash",
                    iconColor: .red,
                    title: "Delete All My Data",
                    showChevron: false,
                    action: { showDeleteConfirmation = true }
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
        VStack(alignment: .leading, spacing: 16) {
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
                        if let url = URL(string: "https://kendall-wood.github.io/blackbuy-privacy/") {
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
    
    // MARK: - Privacy Actions
    
    /// Delete all user data (GDPR/App Store compliance)
    private func deleteAllUserData() {
        // Clear all saved products
        savedProductsManager.clearAllSavedProducts()
        
        // Clear cart
        cartManager.clearCart()
        
        // Clear scan history
        scanHistoryManager.clearHistory()
        
        // Clear saved companies
        for company in savedCompaniesManager.savedCompanies {
            savedCompaniesManager.removeSavedCompany(company.name)
        }
        
        // Sign out and clear auth data
        authManager.signOut()
        
        // Clear any remaining UserDefaults data
        let domain = Bundle.main.bundleIdentifier ?? ""
        UserDefaults.standard.removePersistentDomain(forName: domain)
        
        // Clear secure storage
        SecureStorage.auth.deleteAll()
        SecureStorage.userData.deleteAll()
        
        Log.info("All user data deleted", category: .auth)
    }
    
    /// Export all user data as JSON (GDPR compliance)
    private func exportMyData() {
        var data: [String: Any] = [
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        // Saved products
        data["saved_products"] = savedProductsManager.savedProducts.map { product in
            ["name": product.name, "company": product.company, "category": product.mainCategory]
        }
        
        // Saved companies
        data["saved_companies"] = savedCompaniesManager.savedCompanies.map { company in
            ["name": company.name, "date_saved": ISO8601DateFormatter().string(from: company.dateSaved)]
        }
        
        // Cart items
        data["cart_items"] = cartManager.cartItems.map { item in
            ["product_name": item.product.name, "quantity": item.quantity]
        }
        
        // Scan history count (not full details for privacy)
        data["scan_history_count"] = scanHistoryManager.scanHistory.count
        
        // Auth status (anonymized)
        data["is_signed_in"] = authManager.isSignedIn
        data["account_type"] = authManager.isSignedIn ? "Apple ID" : "anonymous"
        
        // Storage info
        data["data_storage"] = [
            "location": "on-device only",
            "encryption": "iOS Keychain for credentials, UserDefaults for preferences",
            "cloud_sync": false,
            "third_party_sharing": "none"
        ]
        
        // Format as pretty JSON
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            exportData = jsonString
        } else {
            exportData = "Unable to export data. Please try again."
        }
        
        showExportSheet = true
    }
}

#Preview("Profile - Signed Out") {
    ProfileView(selectedTab: .constant(.profile))
        .environmentObject(AppleAuthManager())
        .environmentObject(SavedProductsManager())
        .environmentObject(SavedCompaniesManager())
        .environmentObject(CartManager())
        .environmentObject(ScanHistoryManager())
}
