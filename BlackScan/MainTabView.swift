import SwiftUI

/// Main container view that manages navigation between all app screens
struct MainTabView: View {
    @State private var selectedTab: AppTab = .scan
    @State private var tabHistory: [AppTab] = [.scan]
    @State private var pendingShopSearch: String? = nil
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var savedCompaniesManager: SavedCompaniesManager
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var authManager: AppleAuthManager
    @EnvironmentObject var toastManager: ToastManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    
    /// Navigate back: pop the stack and go to the previous tab
    private func goBack() {
        if tabHistory.count > 1 {
            tabHistory.removeLast()
            selectedTab = tabHistory.last ?? .scan
        } else {
            selectedTab = .scan
        }
    }
    
    var body: some View {
        Group {
            switch selectedTab {
            case .profile:
                ProfileView(selectedTab: $selectedTab, onBack: goBack)
            case .saved:
                SavedView(selectedTab: $selectedTab, onBack: goBack)
            case .scan:
                ScanView(selectedTab: $selectedTab, pendingShopSearch: $pendingShopSearch)
            case .shop:
                ShopView(selectedTab: $selectedTab, pendingShopSearch: $pendingShopSearch, onBack: goBack)
            case .checkout:
                CheckoutManagerView(selectedTab: $selectedTab, onBack: goBack)
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .onAppear {
            ToastWindowManager.shared.setup(toastManager: toastManager, networkMonitor: networkMonitor) { tab in
                selectedTab = tab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchInShop)) { notification in
            if let query = notification.object as? String {
                pendingShopSearch = query
                selectedTab = .shop
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Only push if it's a forward navigation (not a back)
            if tabHistory.last != newValue {
                tabHistory.append(newValue)
            }
            // Keep history reasonable
            if tabHistory.count > 10 {
                tabHistory.removeFirst()
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
        .environmentObject(ProductCacheManager())
}
