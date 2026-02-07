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
    @StateObject private var productCacheManager = ProductCacheManager()
    @StateObject private var networkMonitor = NetworkMonitor()
    
    @State private var isReady = false
    
    init() {
        // Validate environment variables on startup
        TestEnv.validateOnStartup()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isReady {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    LaunchScreenView()
                }
            }
            .animation(.easeOut(duration: 0.3), value: isReady)
            .environmentObject(cartManager)
            .environmentObject(savedProductsManager)
            .environmentObject(savedCompaniesManager)
            .environmentObject(authManager)
            .environmentObject(scanHistoryManager)
            .environmentObject(toastManager)
            .environmentObject(productCacheManager)
            .environmentObject(networkMonitor)
            .preferredColorScheme(.light)
            .task {
                // Pre-fetch featured products during splash
                await productCacheManager.loadIfNeeded()
                
                // Ensure splash shows for at least 1 second for branding
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                withAnimation {
                    isReady = true
                }
            }
        }
    }
}
