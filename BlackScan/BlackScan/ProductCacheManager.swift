import Foundation
import SwiftUI

/// Shared manager that pre-fetches and caches featured products for the Shop.
/// Avoids re-fetching on every tab switch. Initialized once at app launch.
@MainActor
class ProductCacheManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var carouselProducts: [Product] = []
    @Published var gridProducts: [Product] = []
    @Published var isLoaded: Bool = false
    @Published var isLoading: Bool = false
    @Published var loadError: String?
    
    // MARK: - Private Properties
    
    private let typesenseClient = TypesenseClient()
    
    // MARK: - Public Methods
    
    /// Load featured products once. No-ops if already loaded or in progress.
    func loadIfNeeded() async {
        guard !isLoaded && !isLoading else { return }
        await load()
    }
    
    /// Force reload (e.g. pull-to-refresh)
    func reload() async {
        await load()
    }
    
    // MARK: - Private
    
    private func load() async {
        isLoading = true
        loadError = nil
        
        do {
            let allProducts = try await NetworkSecurity.withRetry(maxAttempts: 2) {
                try await typesenseClient.searchProducts(
                    query: "*",
                    page: 1,
                    perPage: Env.maxResultsPerPage
                )
            }
            
            let uniqueCompanies = Array(Set(allProducts.map { $0.company }))
            let selectedCompanies = uniqueCompanies.shuffled().prefix(12)
            var carousel: [Product] = []
            
            for company in selectedCompanies {
                if let product = allProducts.first(where: { $0.company == company }) {
                    carousel.append(product)
                }
            }
            
            let carouselIds = Set(carousel.map { $0.id })
            let remainingProducts = allProducts.filter { !carouselIds.contains($0.id) }
            let grid = Array(remainingProducts.shuffled().prefix(12))
            
            carouselProducts = carousel.shuffled()
            gridProducts = grid
            isLoaded = true
            isLoading = false
            
            Log.debug("ProductCacheManager: Loaded \(carouselProducts.count) carousel + \(gridProducts.count) grid products", category: .network)
        } catch {
            isLoading = false
            loadError = "Unable to load products. Please try again."
            Log.error("ProductCacheManager load failed", category: .network)
        }
    }
}
