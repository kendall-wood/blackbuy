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
            // Fetch from 3 random non-overlapping pages for a diverse product pool
            let perPage = Env.maxResultsPerPage
            var pages: Set<Int> = []
            while pages.count < 3 {
                pages.insert(Int.random(in: 1...15))
            }
            let pageList = Array(pages)
            
            async let fetch1 = NetworkSecurity.withRetry(maxAttempts: 2) {
                try await self.typesenseClient.searchProducts(
                    query: "*",
                    page: pageList[0],
                    perPage: perPage
                )
            }
            async let fetch2 = NetworkSecurity.withRetry(maxAttempts: 2) {
                try await self.typesenseClient.searchProducts(
                    query: "*",
                    page: pageList[1],
                    perPage: perPage
                )
            }
            async let fetch3 = NetworkSecurity.withRetry(maxAttempts: 2) {
                try await self.typesenseClient.searchProducts(
                    query: "*",
                    page: pageList[2],
                    perPage: perPage
                )
            }
            
            let (page1, page2, page3) = try await (fetch1, fetch2, fetch3)
            
            // Combine, shuffle, and deduplicate
            var seen = Set<String>()
            var allProducts: [Product] = []
            for product in (page1 + page2 + page3).shuffled() {
                if seen.insert(product.id).inserted {
                    allProducts.append(product)
                }
            }
            
            // --- Carousel: 1 product per brand, pick 12 random brands ---
            let uniqueCompanies = Array(Set(allProducts.map { $0.company })).shuffled()
            let selectedCompanies = uniqueCompanies.prefix(12)
            var carousel: [Product] = []
            
            for company in selectedCompanies {
                if let product = allProducts.filter({ $0.company == company }).randomElement() {
                    carousel.append(product)
                }
            }
            
            // --- Grid: max 2 products per brand, diverse selection ---
            let carouselIds = Set(carousel.map { $0.id })
            let remainingProducts = allProducts.filter { !carouselIds.contains($0.id) }.shuffled()
            
            var grid: [Product] = []
            var gridCompanyCount: [String: Int] = [:]
            
            for product in remainingProducts {
                let count = gridCompanyCount[product.company, default: 0]
                if count < 2 {
                    grid.append(product)
                    gridCompanyCount[product.company] = count + 1
                }
                if grid.count >= 24 { break }
            }
            
            carouselProducts = carousel.shuffled()
            gridProducts = grid
            isLoaded = true
            isLoading = false
            lastLoadTime = Date()
            
            Log.debug("ProductCacheManager: Loaded \(carouselProducts.count) carousel + \(gridProducts.count) grid from pages \(pageList)", category: .network)
        } catch {
            isLoading = false
            loadError = "Unable to load products. Please try again."
            Log.error("ProductCacheManager load failed", category: .network)
        }
    }
}
