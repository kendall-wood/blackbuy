import SwiftUI

/// All Featured Products view with pagination
struct AllFeaturedProductsView: View {
    
    @StateObject private var typesenseClient = TypesenseClient()
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var toastManager: ToastManager
    
    let excludedProductIds: Set<String>
    
    @State private var allProducts: [Product] = []
    @State private var displayedProducts: [Product] = []
    @State private var isLoading = false
    @State private var currentPage = 0
    @State private var selectedProduct: Product?
    @State private var sortOrder: SortOrder = .random
    @State private var showReportSheet = false
    
    @Environment(\.dismiss) var dismiss
    
    enum SortOrder: String, CaseIterable {
        case random = "Random"
        case priceLowToHigh = "Price: Low to High"
        case priceHighToLow = "Price: High to Low"
        case nameAZ = "Name: A-Z"
    }
    
    private let productsPerPage = 16
    private let maxProductsPerCompany = 3
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                header
                
                // Content
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: UnifiedProductCard.gridColumns, spacing: DS.gridSpacing) {
                        ForEach(displayedProducts) { product in
                            UnifiedProductCard(
                                product: product,
                                isSaved: savedProductsManager.isProductSaved(product),
                                isInCart: cartManager.isInCart(product),
                                onCardTapped: { selectedProduct = product },
                                onSaveTapped: {
                                    if savedProductsManager.isProductSaved(product) {
                                        savedProductsManager.removeSavedProduct(product)
                                        toastManager.show(.unsaved)
                                    } else {
                                        savedProductsManager.saveProduct(product)
                                        toastManager.show(.saved)
                                    }
                                },
                                onAddToCart: {
                                    if cartManager.isInCart(product) {
                                        cartManager.removeFromCart(product)
                                        toastManager.show(.removedFromCheckout)
                                    } else {
                                        cartManager.addToCart(product)
                                        toastManager.show(.addedToCheckout)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DS.horizontalPadding)
                    
                    // Load More Button
                    if displayedProducts.count < allProducts.count {
                        Button(action: loadMore) {
                            Text("Load More")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(DS.brandBlue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.white)
                                .cornerRadius(DS.radiusMedium)
                                .dsCardShadow(cornerRadius: DS.radiusMedium)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DS.horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(DS.cardBackground)
            .navigationBarHidden(true)
        }
        .onAppear {
            loadProducts()
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
                .environmentObject(typesenseClient)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportIssueView(currentTab: .shop)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppHeader(
                centerContent: .logo,
                onBack: { dismiss() },
                trailingContent: AnyView(
                    ReportMenuButton { showReportSheet = true }
                )
            )
            
            Text("Featured Products")
                .font(DS.pageTitle)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            // Sort Button
            HStack {
                DSSortButton(label: "Sort") {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(order.rawValue) {
                            sortOrder = order
                            sortProducts()
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, DS.horizontalPadding)
            
            Text("Showing \(allProducts.count) products")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(.systemGray))
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
        .background(DS.cardBackground)
    }
    
    // MARK: - Load Products
    
    private func loadProducts() {
        isLoading = true
        
        Task {
            do {
                let perPage = Env.maxResultsPerPage // 50
                
                // Get total product count to sample from the full catalog
                let countResponse = try await typesenseClient.search(parameters: SearchParameters(
                    query: "*", page: 1, perPage: 1
                ))
                let totalPages = max(1, countResponse.found / perPage)
                
                // Pick 4 random pages from the full range, alternating price sort direction
                let p1 = Int.random(in: 1...totalPages)
                let p2 = Int.random(in: 1...totalPages)
                let p3 = Int.random(in: 1...totalPages)
                let p4 = Int.random(in: 1...totalPages)
                
                // Fetch concurrently — alternate price:asc/desc (the only sortable field)
                async let f1 = typesenseClient.searchProducts(query: "*", page: p1, perPage: perPage, sortBy: "price:asc")
                async let f2 = typesenseClient.searchProducts(query: "*", page: p2, perPage: perPage, sortBy: "price:desc")
                async let f3 = typesenseClient.searchProducts(query: "*", page: p3, perPage: perPage, sortBy: "price:asc")
                async let f4 = typesenseClient.searchProducts(query: "*", page: p4, perPage: perPage, sortBy: "price:desc")
                
                let (r1, r2, r3, r4) = try await (f1, f2, f3, f4)
                
                // Deduplicate
                var seen = Set<String>()
                var uniqueProducts: [Product] = []
                for product in (r1 + r2 + r3 + r4).shuffled() {
                    if seen.insert(product.id).inserted {
                        uniqueProducts.append(product)
                    }
                }
                
                await MainActor.run {
                    let filtered = uniqueProducts.filter { !excludedProductIds.contains($0.id) }
                    
                    var companyGroups: [String: [Product]] = [:]
                    for product in filtered {
                        var group = companyGroups[product.company, default: []]
                        if group.count < maxProductsPerCompany {
                            group.append(product)
                        }
                        companyGroups[product.company] = group
                    }
                    
                    var result: [Product] = []
                    for products in companyGroups.values {
                        result.append(contentsOf: products)
                    }
                    result = Array(result.shuffled().prefix(64))
                    
                    allProducts = result
                    sortProducts()
                    loadMore()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
                Log.error("Failed to load featured products", category: .network)
            }
        }
    }
    
    private func sortProducts() {
        switch sortOrder {
        case .random:
            allProducts.shuffle()
        case .priceLowToHigh:
            allProducts.sort { $0.price < $1.price }
        case .priceHighToLow:
            allProducts.sort { $0.price > $1.price }
        case .nameAZ:
            allProducts.sort { $0.name < $1.name }
        }
        
        currentPage = 0
        displayedProducts = []
        loadMore()
    }
    
    private func loadMore() {
        let start = currentPage * productsPerPage
        let end = min(start + productsPerPage, allProducts.count)
        
        if start < allProducts.count {
            displayedProducts.append(contentsOf: allProducts[start..<end])
            currentPage += 1
        }
    }
}

#Preview {
    AllFeaturedProductsView(excludedProductIds: [])
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
}
