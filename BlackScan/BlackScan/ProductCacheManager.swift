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
            let perPage = Env.maxResultsPerPage
            
            // Step 1: Lightweight query to discover total product count
            let countResponse = try await typesenseClient.search(parameters: SearchParameters(
                query: "*", page: 1, perPage: 1
            ))
            let totalProducts = max(countResponse.found, 1)
            let totalPages = max(1, totalProducts / perPage)
            
            // Step 2: Alternate between price:asc and price:desc — the only sortable field
            // in the Typesense schema. Different sort directions surface completely different
            // products on the same page number, and random pages across the full range
            // ensure broad catalog coverage.
            let p1 = Int.random(in: 1...totalPages)
            let p2 = Int.random(in: 1...totalPages)
            let p3 = Int.random(in: 1...totalPages)
            let p4 = Int.random(in: 1...totalPages)
            let p5 = Int.random(in: 1...totalPages)
            
            // Step 3: Fetch all 5 concurrently, alternating sort direction
            async let fetch1 = NetworkSecurity.withRetry(maxAttempts: 2) {
                try await self.typesenseClient.searchProducts(
                    query: "*", page: p1, perPage: perPage, sortBy: "price:asc"
                )
            }
            async let fetch2 = NetworkSecurity.withRetry(maxAttempts: 2) {
                try await self.typesenseClient.searchProducts(
                    query: "*", page: p2, perPage: perPage, sortBy: "price:desc"
                )
            }
            async let fetch3 = NetworkSecurity.withRetry(maxAttempts: 2) {
                try await self.typesenseClient.searchProducts(
                    query: "*", page: p3, perPage: perPage, sortBy: "price:asc"
                )
            }
            async let fetch4 = NetworkSecurity.withRetry(maxAttempts: 2) {
                try await self.typesenseClient.searchProducts(
                    query: "*", page: p4, perPage: perPage, sortBy: "price:desc"
                )
            }
            async let fetch5 = NetworkSecurity.withRetry(maxAttempts: 2) {
                try await self.typesenseClient.searchProducts(
                    query: "*", page: p5, perPage: perPage, sortBy: "price:asc"
                )
            }
            
            let (r1, r2, r3, r4, r5) = try await (fetch1, fetch2, fetch3, fetch4, fetch5)
            
            // Step 5: Combine, shuffle, and deduplicate
            var seen = Set<String>()
            var allProducts: [Product] = []
            for product in (r1 + r2 + r3 + r4 + r5).shuffled() {
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
            
            Log.debug("ProductCacheManager: Loaded \(carouselProducts.count) carousel + \(gridProducts.count) grid from \(allProducts.count) unique products (pages [\(p1),\(p2),\(p3),\(p4),\(p5)] of \(totalPages))", category: .network)
        } catch {
            isLoading = false
            loadError = "Unable to load products. Please try again."
            Log.error("ProductCacheManager load failed", category: .network)
        }
    }
}
