import Foundation
import SwiftUI

/// Manager for saved products with local and cloud sync support
/// Integrates with UserAuthService for Apple Sign In users
@MainActor
class SavedProductsManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var savedProducts: [Product] = []
    @Published var isLoading = false
    @Published var lastSyncDate: Date?
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let savedProductsKey = "saved_products"
    private let lastSyncKey = "last_sync_date"
    
    // MARK: - Initialization
    
    init() {
        loadSavedProducts()
    }
    
    // MARK: - Public Methods
    
    /// Check if a product is saved
    func isProductSaved(_ product: Product) -> Bool {
        return savedProducts.contains { $0.id == product.id }
    }
    
    /// Save a product
    func saveProduct(_ product: Product) {
        guard !isProductSaved(product) else { return }
        
        savedProducts.append(product)
        persistSavedProducts()
        
        print("💾 Product saved: \(product.name)")
        
        // TODO: Sync to CloudKit if signed in with Apple
        // syncToCloudIfNeeded()
    }
    
    /// Remove a saved product
    func removeSavedProduct(_ product: Product) {
        savedProducts.removeAll { $0.id == product.id }
        persistSavedProducts()
        
        print("🗑️ Product removed: \(product.name)")
        
        // TODO: Sync to CloudKit if signed in with Apple
        // syncToCloudIfNeeded()
    }
    
    /// Toggle save status of a product
    func toggleSaveProduct(_ product: Product) {
        if isProductSaved(product) {
            removeSavedProduct(product)
        } else {
            saveProduct(product)
        }
    }
    
    /// Clear all saved products
    func clearAllSavedProducts() {
        savedProducts.removeAll()
        persistSavedProducts()
        
        print("🗑️ All saved products cleared")
    }
    
    /// Get saved products by category
    func savedProducts(in category: String) -> [Product] {
        return savedProducts.filter { $0.mainCategory == category }
    }
    
    /// Get recently saved products (last 7 days)
    func recentlySavedProducts() -> [Product] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return savedProducts.filter { product in
            // For now, return all products since we don't track save date
            // TODO: Add save date tracking
            return true
        }
    }
    
    // MARK: - Private Methods
    
    /// Load saved products from UserDefaults
    private func loadSavedProducts() {
        guard let data = userDefaults.data(forKey: savedProductsKey) else {
            savedProducts = []
            return
        }
        
        do {
            savedProducts = try JSONDecoder().decode([Product].self, from: data)
            print("✅ Loaded \(savedProducts.count) saved products")
        } catch {
            print("❌ Failed to load saved products: \(error)")
            savedProducts = []
        }
        
        // Load last sync date
        if let syncDate = userDefaults.object(forKey: lastSyncKey) as? Date {
            lastSyncDate = syncDate
        }
    }
    
    /// Persist saved products to UserDefaults
    private func persistSavedProducts() {
        do {
            let data = try JSONEncoder().encode(savedProducts)
            userDefaults.set(data, forKey: savedProductsKey)
            
            // Update last sync date
            lastSyncDate = Date()
            userDefaults.set(lastSyncDate, forKey: lastSyncKey)
            
            print("✅ Persisted \(savedProducts.count) saved products")
        } catch {
            print("❌ Failed to persist saved products: \(error)")
        }
    }
}

// MARK: - Future CloudKit Integration

extension SavedProductsManager {
    
    /// Sync saved products to CloudKit (future implementation)
    private func syncToCloudIfNeeded() {
        // TODO: Implement CloudKit sync when user is signed in with Apple
        /*
        guard UserAuthService.shared.isSignedInWithApple else { return }
        
        Task {
            do {
                try await syncSavedProductsToCloud()
                print("☁️ Synced saved products to CloudKit")
            } catch {
                print("❌ Failed to sync to CloudKit: \(error)")
            }
        }
        */
    }
    
    /// Sync saved products from CloudKit (future implementation)
    func syncFromCloud() async throws {
        // TODO: Implement CloudKit fetch
        /*
        guard UserAuthService.shared.isSignedInWithApple else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Fetch from CloudKit
        let cloudProducts = try await fetchSavedProductsFromCloud()
        
        // Merge with local products
        await MainActor.run {
            mergeSavedProducts(cloudProducts)
        }
        */
    }
    
    /// Merge cloud and local saved products (future implementation)
    private func mergeSavedProducts(_ cloudProducts: [Product]) {
        // TODO: Implement smart merging logic
        // - Combine local and cloud products
        // - Remove duplicates
        // - Handle conflicts
        // - Update UI
    }
}

// MARK: - Export/Import for Privacy Compliance

extension SavedProductsManager {
    
    /// Export saved products data for privacy compliance
    func exportSavedProductsData() -> [String: Any] {
        return [
            "saved_products_count": savedProducts.count,
            "categories": Set(savedProducts.map { $0.mainCategory }).sorted(),
            "last_sync_date": lastSyncDate?.ISO8601Format() ?? "never",
            "storage_location": "local_device_only",
            "cloud_sync_enabled": false, // TODO: Update when CloudKit is implemented
            "data_retention": "until_manually_deleted_or_app_uninstalled"
        ]
    }
    
    /// Import saved products from exported data
    func importSavedProductsData(_ data: Data) throws {
        let importedProducts = try JSONDecoder().decode([Product].self, from: data)
        
        // Merge with existing products (avoid duplicates)
        for product in importedProducts {
            if !isProductSaved(product) {
                savedProducts.append(product)
            }
        }
        
        persistSavedProducts()
        print("✅ Imported \(importedProducts.count) products")
    }
}
