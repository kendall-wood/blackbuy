import SwiftUI

@main
struct BlackScanApp: App {
    
    // MARK: - Shared State Managers
    
    @StateObject private var cartManager = CartManager()
    @StateObject private var savedProductsManager = SavedProductsManager()
    @StateObject private var savedCompaniesManager = SavedCompaniesManager()
    @StateObject private var authManager = AppleAuthManager()
    @StateObject private var scanHistoryManager = ScanHistoryManager()
    
    init() {
        // Validate environment variables on startup
        TestEnv.validateOnStartup()
    }
    
    var body: some Scene {
        WindowGroup {
            MainCameraView()
                .environmentObject(cartManager)
                .environmentObject(savedProductsManager)
                .environmentObject(savedCompaniesManager)
                .environmentObject(authManager)
                .environmentObject(scanHistoryManager)
        }
    }
}

/// Main camera-first view with floating action buttons
/// This is the primary interface - camera is always visible
struct MainCameraView: View {
    
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var scanHistoryManager: ScanHistoryManager
    
    @State private var showingProfile = false
    @State private var showingCheckout = false
    @State private var showingShop = false
    @State private var showingSaved = false
    @State private var showingHistory = false
    @State private var flashlightOn = false
    
    var body: some View {
        ZStack {
            // Camera Scanner - always visible as background
            CameraScanView()
                .ignoresSafeArea()
            
            // Floating Action Buttons at Bottom
            VStack {
                Spacer()
                
                floatingButtons
                    .padding(.bottom, 40)
            }
        }
        // Profile Modal
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        // Checkout Modal
        .sheet(isPresented: $showingCheckout) {
            CheckoutManagerView()
        }
        // Shop Full Screen
        .fullScreenCover(isPresented: $showingShop) {
            ShopView()
        }
        // Saved Full Screen
        .fullScreenCover(isPresented: $showingSaved) {
            SavedView()
        }
        // History Full Screen
        .fullScreenCover(isPresented: $showingHistory) {
            ScanHistoryView()
        }
    }
    
    // MARK: - Floating Buttons
    
    private var floatingButtons: some View {
        HStack(spacing: 24) {
            // History Button
            FloatingButton(icon: "clock", size: 60) {
                showingHistory = true
            }
            
            // Favorites Button
            FloatingButton(icon: "heart.fill", size: 60) {
                showingSaved = true
            }
            
            // Shop Button
            FloatingButton(icon: "storefront", size: 60) {
                showingShop = true
            }
            
            // Cart Button with Badge
            ZStack(alignment: .topTrailing) {
                FloatingButton(icon: "bag", size: 60) {
                    showingCheckout = true
                }
                
                if cartManager.totalItemCount > 0 {
                    Text("\(cartManager.totalItemCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
}

/// Floating circular button component
struct FloatingButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                
                Image(systemName: icon)
                    .font(.system(size: size * 0.35, weight: .medium))
                    .foregroundColor(Color(red: 0, green: 0.48, blue: 1)) // iOS blue
            }
        }
    }
}

