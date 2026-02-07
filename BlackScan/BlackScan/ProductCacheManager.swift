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
    private var lastLoadTime: Date?
    
    /// How often to refresh featured products (in seconds)
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Public Methods
    
    /// Load featured products if not loaded yet or if stale (older than refreshInterval).
    func loadIfNeeded() async {
        guard !isLoading else { return }
        
        if isLoaded, let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < refreshInterval {
            return // Still fresh
        }
        
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
            // Fetch from multiple random pages to get a diverse product pool
            let perPage = Env.maxResultsPerPage
            let randomPage1 = Int.random(in: 1...10)
            var randomPage2 = Int.random(in: 1...10)
            while randomPage2 == randomPage1 { randomPage2 = Int.random(in: 1...10) }
            
            async let fetch1 = NetworkSecurity.withRetry(maxAttempts: 2) {
                try await typesenseClient.searchProducts(
                    query: "*",
                    page: randomPage1,
                    perPage: perPage
                )
            }
            async let fetch2 = NetworkSecurity.withRetry(maxAttempts: 2) {
                try await typesenseClient.searchProducts(
                    query: "*",
                    page: randomPage2,
                    perPage: perPage
                )
            }
            
            let (page1, page2) = try await (fetch1, fetch2)
            
            // Combine and deduplicate
            var seen = Set<String>()
            var allProducts: [Product] = []
            for product in (page1 + page2) {
                if seen.insert(product.id).inserted {
                    allProducts.append(product)
                }
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
            lastLoadTime = Date()
            
            Log.debug("ProductCacheManager: Loaded \(carouselProducts.count) carousel + \(gridProducts.count) grid from pages \(randomPage1) & \(randomPage2)", category: .network)
        } catch {
            isLoading = false
            loadError = "Unable to load products. Please try again."
            Log.error("ProductCacheManager load failed", category: .network)
        }
    }
}
