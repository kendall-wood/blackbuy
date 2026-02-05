import SwiftUI

/// Main container view that manages navigation between all app screens
struct MainTabView: View {
    @State private var selectedTab: BottomNavBar.AppTab = .scan
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var savedCompaniesManager: SavedCompaniesManager
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var authManager: AppleAuthManager
    
    var body: some View {
        ZStack {
            // Content based on selected tab
            Group {
                switch selectedTab {
                case .profile:
                    ProfileView()
                case .saved:
                    SavedView()
                case .scan:
                    ScanView(selectedTab: $selectedTab)
                case .shop:
                    ShopView()
                case .checkout:
                    CheckoutManagerView()
                }
            }
            .ignoresSafeArea(.all, edges: .bottom)
            
            // Bottom Navigation Bar - hidden on scan view
            if selectedTab != .scan {
                BottomNavBar(selectedTab: $selectedTab)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SavedProductsManager())
        .environmentObject(SavedCompaniesManager())
        .environmentObject(CartManager())
        .environmentObject(AppleAuthManager())
}
