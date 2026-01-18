import SwiftUI

/// Shop view with featured carousel, categories, and product grid
struct ShopView: View {
    
    @StateObject private var typesenseClient = TypesenseClient()
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
    // State for different product sections
    @State private var carouselProducts: [Product] = []
    @State private var gridProducts: [Product] = []
    @State private var isLoading = false
    @State private var searchError: String?
    @State private var selectedCategory: String? = nil
    @State private var selectedProduct: Product?
    @State private var currentCarouselIndex = 0
    @State private var showingSearch = false
    @State private var showingAllFeatured = false
    
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
                // Header
                header
                
                // Main Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Large Featured Carousel
                        featuredCarousel
                        
                        // Categories Section
                        categoriesSection
                        
                        // Featured Products Grid
                        featuredProductsSection
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .onAppear {
            loadAllProducts()
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
        }
        .fullScreenCover(isPresented: $showingSearch) {
            SearchView()
        }
        .fullScreenCover(isPresented: $showingAllFeatured) {
            AllFeaturedProductsView(excludedProductIds: Set(carouselProducts.map { $0.id } + gridProducts.map { $0.id }))
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            // Back Button - light grey
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(.systemGray3))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // BlackBuy Logo - smaller, blue
            Image("shop_logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 24)
                .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
            
            Spacer()
            
            // Search Button - blue
            Button(action: {
                showingSearch = true
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.white)
    }
    
    // MARK: - Featured Carousel
    
    private var featuredCarousel: some View {
        VStack(spacing: 12) {
            if !carouselProducts.isEmpty {
                TabView(selection: $currentCarouselIndex) {
                    ForEach(Array(carouselProducts.enumerated()), id: \.element.id) { index, product in
                        LargeFeatureCard(
                            product: product,
                            onAddToCart: {
                                cartManager.addToCart(product)
                            },
                            onCardTapped: {
                                selectedProduct = product
                            }
                        )
                        .tag(index)
                    }
                }
                .frame(height: 300)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            selectedCategory = category
                            searchByCategory(category)
                        }) {
                            Text(category)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Featured Products Section
    
    private var featuredProductsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Featured Products")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: {
                    showingAllFeatured = true
                }) {
                    Text("See All")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            if !gridProducts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(gridProducts) { product in
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
                            .frame(width: 160)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    // MARK: - Search Category
    
    private func searchByCategory(_ category: String) {
        // Navigate to SearchView with category pre-filled
        showingSearch = true
    }
    
    // MARK: - Load Products
    
    private func loadAllProducts() {
        print("🛍️ Loading all products...")
        
        isLoading = true
        searchError = nil
        
        Task {
            do {
                // Get all products
                let allProducts = try await typesenseClient.searchProducts(
                    query: "*",
                    page: 1,
                    perPage: 200
                )
                
                await MainActor.run {
                    // Get unique companies
                    let uniqueCompanies = Array(Set(allProducts.map { $0.company }))
                    
                    // Select 12 random companies for carousel
                    let selectedCompanies = uniqueCompanies.shuffled().prefix(12)
                    var carousel: [Product] = []
                    
                    // Get one product from each selected company for carousel
                    for company in selectedCompanies {
                        if let product = allProducts.first(where: { $0.company == company }) {
                            carousel.append(product)
                        }
                    }
                    
                    // Get 12 random products for grid (excluding carousel products)
                    let carouselIds = Set(carousel.map { $0.id })
                    let remainingProducts = allProducts.filter { !carouselIds.contains($0.id) }
                    let grid = Array(remainingProducts.shuffled().prefix(12))
                    
                    carouselProducts = carousel.shuffled()
                    gridProducts = grid
                    isLoading = false
                    
                    print("✅ Loaded \(carousel.count) carousel products and \(grid.count) grid products")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    searchError = error.localizedDescription
                    print("❌ Failed to load products: \(error)")
                }
            }
        }
    }
}

// MARK: - Large Feature Card (Carousel)

struct LargeFeatureCard: View {
    let product: Product
    let onAddToCart: () -> Void
    let onCardTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                // Left side: Text content
                VStack(alignment: .leading, spacing: 8) {
                    Text("Featured Product")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(product.name)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    Text(product.company)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(.systemGray2))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: onAddToCart) {
                        Text("Add to Cart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(red: 0, green: 0.48, blue: 1))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                
                // Right side: Product image
                AsyncImage(url: URL(string: product.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } placeholder: {
                    Color(.systemGray6)
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(16)
            }
        }
        .frame(height: 280)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
        .onTapGesture {
            onCardTapped()
        }
    }
}

// MARK: - Short Feature Card (Grid)

struct ShortFeatureCard: View {
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
                        .aspectRatio(1, contentMode: .fill)
                } placeholder: {
                    Color(.systemGray6)
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(height: 120)
                .clipped()
                
                // Heart Button
                Button(action: onSaveTapped) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSaved ? .red : .gray)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            .onTapGesture {
                onCardTapped()
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 6) {
                // Company name first (light grey)
                Text(product.company)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(.systemGray2))
                    .lineLimit(1)
                
                // Product name (black)
                Text(product.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .frame(height: 40, alignment: .top)
                
                // Price and Add button
                HStack {
                    Text(product.formattedPrice)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button(action: onAddToCart) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color(red: 0, green: 0.48, blue: 1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
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
