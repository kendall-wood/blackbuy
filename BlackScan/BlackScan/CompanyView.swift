import SwiftUI

/// Company products view - displays all products from a specific company
struct CompanyView: View {
    
    let companyName: String
    
    @StateObject private var typesenseClient = TypesenseClient()
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
    @State private var searchResults: [Product] = []
    @State private var isLoading = false
    @State private var searchError: String?
    @State private var selectedProduct: Product?
    @State private var sortOrder: SortOrder = .recentlyAdded
    
    @Environment(\.dismiss) var dismiss
    
    enum SortOrder {
        case recentlyAdded
        case alphabetical
        case priceHighToLow
        case priceLowToHigh
    }
    
    private var sortOrderLabel: String {
        switch sortOrder {
        case .recentlyAdded: return "Recent"
        case .alphabetical: return "A-Z"
        case .priceHighToLow: return "Price ↓"
        case .priceLowToHigh: return "Price ↑"
        }
    }
    
    private var sortedProducts: [Product] {
        switch sortOrder {
        case .recentlyAdded:
            return searchResults
        case .alphabetical:
            return searchResults.sorted { $0.name < $1.name }
        case .priceHighToLow:
            return searchResults.sorted { $0.price > $1.price }
        case .priceLowToHigh:
            return searchResults.sorted { $0.price < $1.price }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppHeader(centerContent: .title(companyName), onBack: { dismiss() })
            
            // Content
            ScrollView {
                if isLoading {
                    loadingView
                } else if searchResults.isEmpty && !isLoading {
                    emptyStateView
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        // Shop Section Header with Sort Button
                        HStack(alignment: .center) {
                            Text("Shop")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            DSSortButton(label: sortOrderLabel) {
                                Button("Recently Added") { sortOrder = .recentlyAdded }
                                Button("Alphabetical") { sortOrder = .alphabetical }
                                Button("Price: High to Low") { sortOrder = .priceHighToLow }
                                Button("Price: Low to High") { sortOrder = .priceLowToHigh }
                            }
                        }
                        .padding(.horizontal, DS.horizontalPadding)
                        .padding(.top, 20)
                        
                        // Products grid
                        LazyVGrid(columns: UnifiedProductCard.gridColumns, spacing: DS.gridSpacing) {
                            ForEach(sortedProducts) { product in
                                UnifiedProductCard(
                                    product: product,
                                    isSaved: savedProductsManager.isProductSaved(product),
                                    isInCart: cartManager.isInCart(product),
                                    onCardTapped: {
                                        selectedProduct = product
                                    },
                                    onSaveTapped: {
                                        savedProductsManager.toggleSaveProduct(product)
                                    },
                                    onAddToCart: {
                                        cartManager.addToCart(product)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, DS.horizontalPadding)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .background(DS.cardBackground)
        .onAppear {
            loadCompanyProducts()
        }
        .fullScreenCover(item: $selectedProduct) { product in
            ProductDetailView(product: product)
                .environmentObject(typesenseClient)
                .environmentObject(savedProductsManager)
                .environmentObject(cartManager)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading products...")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(.systemGray))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "building.2")
                .font(.system(size: 64))
                .foregroundColor(Color(.systemGray2))
            
            Text("No Products Found")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.black)
            
            Text("We couldn't find any products from \(companyName)")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Data Loading
    
    private func loadCompanyProducts() {
        isLoading = true
        searchError = nil
        
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: companyName,
                    page: 1,
                    perPage: 50
                )
                
                let companyProducts = products.filter { $0.company == companyName }
                
                await MainActor.run {
                    isLoading = false
                    searchResults = companyProducts
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    searchError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    CompanyView(companyName: "SheaMoisture")
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
}
