import SwiftUI

/// Main container view that manages navigation between all app screens
struct MainTabView: View {
    @State private var selectedTab: AppTab = .scan
    @State private var pendingShopSearch: String? = nil
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var savedCompaniesManager: SavedCompaniesManager
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var authManager: AppleAuthManager
    
    var body: some View {
        // Content based on selected tab
        Group {
            switch selectedTab {
            case .profile:
                ProfileView(selectedTab: $selectedTab)
            case .saved:
                SavedView(selectedTab: $selectedTab)
            case .scan:
                ScanView(selectedTab: $selectedTab, pendingShopSearch: $pendingShopSearch)
            case .shop:
                ShopView(selectedTab: $selectedTab, pendingShopSearch: $pendingShopSearch)
            case .checkout:
                CheckoutManagerView(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

#Preview {
    MainTabView()
        .environmentObject(SavedProductsManager())
        .environmentObject(SavedCompaniesManager())
        .environmentObject(CartManager())
        .environmentObject(AppleAuthManager())
}
