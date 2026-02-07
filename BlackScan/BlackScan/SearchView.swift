import SwiftUI

/// Search view with dynamic product search
struct SearchView: View {
    
    @StateObject private var typesenseClient = TypesenseClient()
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
    @State private var searchText: String
    @State private var searchResults: [Product] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedProduct: Product?
    
    @Environment(\.dismiss) var dismiss
    
    init(initialSearchText: String = "") {
        _searchText = State(initialValue: initialSearchText)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with back button and logo
                VStack(spacing: 16) {
                    // Back button row
                    HStack {
                        AppBackButton(action: { dismiss() })
                        Spacer()
                    }
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.top, 12)
                    
                    // BlackBuy Logo
                    Image("shop_logo")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                        .foregroundColor(DS.brandBlue)
                    
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundColor(Color(.systemGray3))
                        
                        TextField("Search for brands, products, or categories", text: $searchText)
                            .font(.system(size: 16))
                            .onChange(of: searchText) { oldValue, newValue in
                                searchTask?.cancel()
                                
                                if newValue.isEmpty {
                                    searchResults = []
                                    return
                                }
                                
                                searchTask = Task {
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    if !Task.isCancelled {
                                        await performSearch(query: newValue)
                                    }
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchTask?.cancel()
                                searchText = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(.systemGray3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: DS.radiusMedium)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal, DS.horizontalPadding)
                }
                .background(DS.cardBackground)
                
                // Results
                if isSearching {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                } else if searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("Search for products")
                            .font(DS.sectionHeader)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No results found")
                            .font(DS.sectionHeader)
                        
                        Text("Try a different search term")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: UnifiedProductCard.gridColumns, spacing: DS.gridSpacing) {
                            ForEach(searchResults) { product in
                                UnifiedProductCard(
                                    product: product,
                                    isSaved: savedProductsManager.isProductSaved(product),
                                    isInCart: cartManager.isInCart(product),
                                    onCardTapped: { selectedProduct = product },
                                    onSaveTapped: { savedProductsManager.toggleSaveProduct(product) },
                                    onAddToCart: { cartManager.addToCart(product) }
                                )
                            }
                        }
                        .padding(DS.gridSpacing)
                    }
                }
            }
            .background(DS.cardBackground)
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
                .environmentObject(typesenseClient)
        }
        .onAppear {
            if !searchText.isEmpty {
                Task {
                    await performSearch(query: searchText)
                }
            }
        }
    }
    
    private func performSearch(query: String) async {
        await MainActor.run {
            isSearching = true
        }
        
        do {
            let products = try await typesenseClient.searchProducts(
                query: query,
                page: 1,
                perPage: 50
            )
            
            await MainActor.run {
                searchResults = products
                isSearching = false
            }
        } catch {
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
            print("Search error: \(error)")
        }
    }
}

#Preview {
    SearchView(initialSearchText: "")
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
}
