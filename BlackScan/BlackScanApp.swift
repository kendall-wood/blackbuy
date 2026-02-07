import SwiftUI

@main
struct BlackScanApp: App {
    
    // MARK: - Shared State Managers
    
    @StateObject private var cartManager = CartManager()
    @StateObject private var savedProductsManager = SavedProductsManager()
    @StateObject private var savedCompaniesManager = SavedCompaniesManager()
    @StateObject private var authManager = AppleAuthManager()
    @StateObject private var scanHistoryManager = ScanHistoryManager()
    @StateObject private var toastManager = ToastManager()
    
    init() {
        // Validate environment variables on startup
        TestEnv.validateOnStartup()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(cartManager)
                .environmentObject(savedProductsManager)
                .environmentObject(savedCompaniesManager)
                .environmentObject(authManager)
                .environmentObject(scanHistoryManager)
                .environmentObject(toastManager)
                .preferredColorScheme(.light)
        }
    }
}

