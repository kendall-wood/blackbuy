import SwiftUI

/// Shop view with blackbuy branding, category chips, and product grid
/// Matches screenshot 1 exactly
struct ShopView: View {
    
    @StateObject private var typesenseClient = TypesenseClient()
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
    @State private var searchText = ""
    @State private var searchResults: [Product] = []
    @State private var featuredProducts: [Product] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var selectedCategory: String? = nil
    @State private var showingCart = false
    @State private var selectedProduct: Product?
    @State private var searchTask: Task<Void, Never>?
    
    @Environment(\.dismiss) var dismiss
    
    private let categories = [
        "Baby Accessories",
        "Bags & Handbags",
        "Bath & Body",
        "Beauty Tools",
        "Body Care",
        "Fragrance",
        "Hair Care",
        "Makeup",
        "Skincare"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Bar
                header
                
                // Search Bar
                searchBar
                
                // Category Chips (horizontal scroll)
                categoryChips
                
                // Suggested Filter
                HStack {
                    sortButton
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Error Message
                        if let error = searchError {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                                
                                Text("Connection Error")
                                    .font(.system(size: 20, weight: .bold))
                                
                                Text(error)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Button("Retry") {
                                    loadFeaturedProducts()
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color(red: 0, green: 0.48, blue: 1))
                                .cornerRadius(10)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }
                        
                        // Loading State
                        if isSearching && featuredProducts.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Loading products...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }
                        
                        // Featured Brand Section
                        if !displayedProducts.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Featured Brand")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 20)
                                
                                // Product Grid
                                productGrid
                            }
                        }
                        
                        // Empty State
                        if !isSearching && displayedProducts.isEmpty && searchError == nil {
                            VStack(spacing: 12) {
                                Image(systemName: "bag")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                
                                Text("No Products Found")
                                    .font(.system(size: 20, weight: .bold))
                                
                                Text("Check your connection and try again")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .onAppear {
            loadFeaturedProducts()
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            // Back Button
            Button(action: {
                dismiss()
            }) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                }
            }
            
            Spacer()
            
            // BlackBuy Logo - use SVG asset (will be blue)
            Image("shop_logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 32)
                .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
            
            Spacer()
            
            // Cart Button
            Button(action: {
                showingCart = true
            }) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 50, height: 50)
                        
                        Image("cart_icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.primary)
                    }
                    
                    if cartManager.totalItemCount > 0 {
                        Text("\(cartManager.totalItemCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.white)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundColor(Color(.systemGray2))
            
            TextField("Search for brands, products, or categories", text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .onChange(of: searchText) { oldValue, newValue in
                    // Cancel previous search task
                    searchTask?.cancel()
                    
                    // Clear results if search text is empty
                    if newValue.isEmpty {
                        searchResults = []
                        selectedCategory = nil
                        return
                    }
                    
                    // Debounce search - wait 0.5s after user stops typing
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        
                        if !Task.isCancelled {
                            await MainActor.run {
                                performSearch()
                            }
                        }
                    }
                }
                .onSubmit {
                    performSearch()
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchTask?.cancel()
                    searchText = ""
                    searchResults = []
                    selectedCategory = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(.systemGray3))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.8))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    // MARK: - Category Chips
    
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                        searchByCategory(category)
                    }) {
                        Text(category)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(selectedCategory == category ? .white : Color(red: 0, green: 0.48, blue: 1))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedCategory == category ? Color(red: 0, green: 0.48, blue: 1) : Color(red: 0, green: 0.48, blue: 1).opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Sort Button
    
    private var sortButton: some View {
        Menu {
            Button("Suggested") { }
            Button("Price: Low to High") { }
            Button("Price: High to Low") { }
            Button("Newest First") { }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .medium))
                Text("Suggested")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Product Grid
    
    private var productGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 24),
            GridItem(.flexible(), spacing: 24)
        ]
        
        return LazyVGrid(columns: columns, spacing: 20) {
            ForEach(displayedProducts) { product in
                ShopProductCard(
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
        .padding(.horizontal, 20)
    }
    
    private var displayedProducts: [Product] {
        return searchResults.isEmpty ? featuredProducts : searchResults
    }
    
    // MARK: - Search Methods
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        searchError = nil
        
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: searchText,
                    page: 1,
                    perPage: 50
                )
                
                await MainActor.run {
                    isSearching = false
                    searchResults = products
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    searchError = error.localizedDescription
                }
            }
        }
    }
    
    private func searchByCategory(_ category: String) {
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: category,
                    page: 1,
                    perPage: 50
                )
                
                await MainActor.run {
                    searchResults = products
                }
            } catch {
                print("Category search error: \(error)")
            }
        }
    }
    
    private func loadFeaturedProducts() {
        print("🛍️ Loading featured products...")
        print("📡 Typesense Host: \(Env.typesenseHost)")
        print("🔑 API Key: \(Env.typesenseApiKey.prefix(10))... (length: \(Env.typesenseApiKey.count))")
        print("🔗 Search URL: \(Env.typesenseSearchURL())")
        
        searchError = nil
        isSearching = true
        
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: "*",
                    page: 1,
                    perPage: 20
                )
                
                await MainActor.run {
                    isSearching = false
                    featuredProducts = products
                    print("✅ Loaded \(products.count) featured products")
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    searchError = error.localizedDescription
                }
                print("❌ Failed to load featured products: \(error)")
                print("❌ Error type: \(type(of: error))")
                print("❌ Error details: \(String(describing: error))")
                
                // Print localized description
                if let localizedError = error as? LocalizedError {
                    print("❌ Localized description: \(localizedError.errorDescription ?? "N/A")")
                    print("❌ Failure reason: \(localizedError.failureReason ?? "N/A")")
                    print("❌ Recovery suggestion: \(localizedError.recoverySuggestion ?? "N/A")")
                }
            }
        }
    }
}

/// Product card for shop grid (matches screenshot design)
struct ShopProductCard: View {
    let product: Product
    let isSaved: Bool
    let onSaveTapped: () -> Void
    let onAddToCart: () -> Void
    let onCardTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with Heart
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: product.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemGray6)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(Color(.systemGray4))
                        )
                }
                .frame(height: 180)
                .clipped()
                
                // Heart Button
                Button(action: onSaveTapped) {
                    ZStack {
                        Circle()
                            .fill(Color(.darkGray).opacity(0.7))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isSaved ? .red : .white)
                    }
                }
                .padding(10)
            }
            .onTapGesture {
                onCardTapped()
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .top)
                
                Text(product.company)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                    .lineLimit(1)
                
                HStack {
                    Text(product.formattedPrice)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button(action: onAddToCart) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0, green: 0.48, blue: 1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.top, 2)
            }
            .padding(14)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    ShopView()
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
}
