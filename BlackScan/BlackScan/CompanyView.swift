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
            header
            
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
                            
                            // Sort Menu
                            Menu {
                                Button("Recently Added") { sortOrder = .recentlyAdded }
                                Button("Alphabetical") { sortOrder = .alphabetical }
                                Button("Price: High to Low") { sortOrder = .priceHighToLow }
                                Button("Price: Low to High") { sortOrder = .priceLowToHigh }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.system(size: 13, weight: .medium))
                                    Text(sortOrderLabel)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Products grid
                        let columns = [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ]
                        
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(sortedProducts) { product in
                                ShortFeatureCard(
                                    product: product,
                                    isSaved: savedProductsManager.isProductSaved(product),
                                    isInCart: cartManager.isInCart(product),
                                    onSaveTapped: {
                                        savedProductsManager.toggleSaveProduct(product)
                                    },
                                    onAddToCart: {
                                        cartManager.addToCart(product)
                                    },
                                    onCardTapped: {
                                        print("🔍 Card tapped - setting selectedProduct to: \(product.name)")
                                        selectedProduct = product
                                    },
                                    onCompanyTapped: nil
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .background(Color.white)
        .onAppear {
            loadCompanyProducts()
        }
        .sheet(item: $selectedProduct) { product in
            print("📱 ProductDetailView sheet presenting for: \(product.name)")
            return ProductDetailView(product: product)
                .environmentObject(typesenseClient)
                .environmentObject(savedProductsManager)
                .environmentObject(cartManager)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(false)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            // Back Button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Company Name
            Text(companyName)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.black)
                .lineLimit(1)
            
            Spacer()
            
            // Spacer for symmetry
            Color.clear
                .frame(width: 22)
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.white)
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
                
                // Filter to only this company's products
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
    
    private func openProductURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    CompanyView(companyName: "SheaMoisture")
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
}
