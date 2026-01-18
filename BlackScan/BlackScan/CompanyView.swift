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
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
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
                        // Products grid
                        let columns = [
                            GridItem(.flexible(), spacing: 24),
                            GridItem(.flexible(), spacing: 24)
                        ]
                        
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(searchResults) { product in
                                ShortFeatureCard(
                                    product: product,
                                    isSaved: savedProductsManager.isProductSaved(product),
                                    onSaveTapped: {
                                        savedProductsManager.toggleSaveProduct(product)
                                    },
                                    onAddToCart: {
                                        cartManager.addToCart(product)
                                    },
                                    onCardTapped: {
                                        selectedProduct = product
                                    }
                                )
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(Color.white)
            .onAppear {
                loadCompanyProducts()
            }
            .sheet(item: $selectedProduct) { product in
                ProductDetailView(product: product)
                    .environmentObject(typesenseClient)
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                // Back Button
                Button(action: {
                    dismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                // Company Name
                Text(companyName)
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(1)
                
                Spacer()
                
                // Placeholder for symmetry
                Circle()
                    .fill(Color.clear)
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            Divider()
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
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "building.2")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Products Found")
                .font(.system(size: 22, weight: .semibold))
            
            Text("We couldn't find any products from \(companyName)")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
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
