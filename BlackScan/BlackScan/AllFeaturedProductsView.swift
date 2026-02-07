import SwiftUI

/// All Featured Products view with pagination
struct AllFeaturedProductsView: View {
    
    @StateObject private var typesenseClient = TypesenseClient()
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
    let excludedProductIds: Set<String>
    
    @State private var allProducts: [Product] = []
    @State private var displayedProducts: [Product] = []
    @State private var isLoading = false
    @State private var currentPage = 0
    @State private var selectedProduct: Product?
    @State private var sortOrder: SortOrder = .random
    
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
                ScrollView {
                    LazyVGrid(columns: UnifiedProductCard.gridColumns, spacing: DS.gridSpacing) {
                        ForEach(displayedProducts) { product in
                            UnifiedProductCard(
                                product: product,
                                isSaved: savedProductsManager.isProductSaved(product),
                                isInCart: cartManager.isInCart(product),
                                onCardTapped: { selectedProduct = product },
                                onSaveTapped: { savedProductsManager.toggleSaveProduct(product) },
                                onAddToCart: { cartManager.isInCart(product) ? cartManager.removeFromCart(product) : cartManager.addToCart(product) }
                            )
                        }
                    }
                    .padding(DS.gridSpacing)
                    
                    // Load More Button
                    if displayedProducts.count < allProducts.count {
                        Button(action: loadMore) {
                            Text("Load More")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(DS.brandBlue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.radiusMedium)
                                        .stroke(DS.brandBlue, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DS.horizontalPadding)
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
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppBackButton(action: { dismiss() })
                Spacer()
            }
            
            Text("Featured Products")
                .font(DS.pageTitle)
                .foregroundColor(.black)
            
            // Sort Button
            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button(order.rawValue) {
                        sortOrder = order
                        sortProducts()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                    Text(sortOrder.rawValue)
                        .font(DS.body)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusLarge)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, DS.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(DS.cardBackground)
    }
    
    // MARK: - Load Products
    
    private func loadProducts() {
        isLoading = true
        
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: "*",
                    page: 1,
                    perPage: 200
                )
                
                await MainActor.run {
                    let filtered = products.filter { !excludedProductIds.contains($0.id) }
                    
                    var companyGroups: [String: [Product]] = [:]
                    for product in filtered {
                        if companyGroups[product.company] == nil {
                            companyGroups[product.company] = []
                        }
                        if companyGroups[product.company]!.count < maxProductsPerCompany {
                            companyGroups[product.company]!.append(product)
                        }
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
                print("Error loading products: \(error)")
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
