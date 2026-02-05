import SwiftUI

/// Shop view with featured carousel, categories, and product grid
struct ShopView: View {
    
    @Binding var selectedTab: BottomNavBar.AppTab
    @StateObject private var typesenseClient = TypesenseClient()
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var savedCompaniesManager: SavedCompaniesManager
    @EnvironmentObject var cartManager: CartManager
    
    // State for different product sections
    @State private var carouselProducts: [Product] = []
    @State private var gridProducts: [Product] = []
    @State private var searchResults: [Product] = []
    @State private var isLoading = false
    @State private var searchError: String?
    @State private var selectedCategory: String? = nil
    @State private var selectedProduct: Product?
    @State private var selectedCompany: String?
    @State private var currentCarouselIndex = 0
    @State private var showingSearch = false
    @State private var showingAllFeatured = false
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showSearchDropdown = false
    
    private let categories = [
        "Hair Care",
        "Skincare",
        "Body Care",
        "Makeup",
        "Fragrance",
        "Lip Care",
        "Men's Care",
        "Accessories",
        "Clothing",
        "Baby & Kids",
        "Home Care",
        "Health & Wellness"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Header with search bar
                    VStack(spacing: 0) {
                        header
                        searchBar
                    }
                    
                    // Main Content
                    ScrollView {
                        VStack(spacing: 24) {
                            // Categories Section (moved to top)
                            categoriesSection
                                .padding(.top, 16)
                            
                            // Featured Brands Section
                            featuredBrandsSection
                            
                            // Featured Products Grid
                            featuredProductsSection
                        }
                        .padding(.bottom, 40)
                    }
                }
                .background(Color.white)
                
                // Search Dropdown Overlay
                if showSearchDropdown && !searchResults.isEmpty {
                    searchDropdown
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadAllProducts()
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
                .environmentObject(typesenseClient)
        }
        .fullScreenCover(isPresented: $showingSearch) {
            SearchView(initialSearchText: searchText)
        }
        .fullScreenCover(isPresented: $showingAllFeatured) {
            AllFeaturedProductsView(excludedProductIds: Set(carouselProducts.map { $0.id } + gridProducts.map { $0.id }))
        }
        .fullScreenCover(item: Binding(
            get: { selectedCompany.map { IdentifiableString(value: $0) } },
            set: { selectedCompany = $0?.value }
        )) { company in
            CompanyView(companyName: company.value)
                .environmentObject(savedProductsManager)
                .environmentObject(cartManager)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            // Back Button
            Button(action: {
                selectedTab = .scan
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(red: 0.26, green: 0.63, blue: 0.95))
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // BlackBuy Logo - blue
            Image("shop_logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 28)
                .foregroundColor(Color(red: 0.26, green: 0.63, blue: 0.95))
            
            Spacer()
            
            // Spacer to balance the layout
            Color.clear
                .frame(width: 50, height: 50)
        }
        .frame(height: 60)
        .padding(.horizontal, 20)
        .background(Color.white)
    }
    
    // MARK: - Search Bar with Dropdown
    
    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(Color(.systemGray))
                
                ZStack(alignment: .leading) {
                    if searchText.isEmpty {
                        Text("Search products and brands")
                            .font(.system(size: 15))
                            .foregroundColor(Color(.systemGray))
                            .lineLimit(1)
                    }
                    TextField("", text: $searchText)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                }
                .onChange(of: searchText) { oldValue, newValue in
                        // Cancel previous search
                        searchTask?.cancel()
                        
                        if newValue.isEmpty {
                            searchResults = []
                            showSearchDropdown = false
                            return
                        }
                        
                        // Debounce search
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                            
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
                        showSearchDropdown = false
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 16)
            .background(Color.white)
        }
    }
    
    // MARK: - Search Dropdown
    
    private var searchDropdown: some View {
        VStack(spacing: 0) {
            // Spacer to position dropdown below search bar
            Color.clear
                .frame(height: 140)
            
            VStack(spacing: 0) {
                // Results (max 9)
                ForEach(searchResults.prefix(9)) { product in
                    Button(action: {
                        selectedProduct = product
                        showSearchDropdown = false
                    }) {
                        HStack(spacing: 12) {
                            // Product image
                            CachedAsyncImage(url: URL(string: product.imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Color.white
                            }
                            .frame(width: 50, height: 50)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                
                                Text(product.company)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(Color(.systemGray2))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(product.formattedPrice)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    
                    if product.id != searchResults.prefix(9).last?.id {
                        Divider()
                            .padding(.leading, 78)
                    }
                }
                
                // "See more..." button
                Button(action: {
                    showSearchDropdown = false
                    showingSearch = true
                }) {
                    Text("See more...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.26, green: 0.63, blue: 0.95))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(Color(.systemGray6).opacity(0.5))
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 5)
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showSearchDropdown = false
                }
        )
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            selectedCategory = category
                            searchByCategory(category)
                        }) {
                            Text(category)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(red: 0.26, green: 0.63, blue: 0.95))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Featured Brands Section
    
    private var featuredBrandsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Featured Brands")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
            
            if !carouselProducts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(carouselProducts) { product in
                            FeaturedBrandCircleCard(
                                product: product,
                                isSaved: savedCompaniesManager.isCompanySaved(product.company),
                                onSaveTapped: {
                                    savedCompaniesManager.toggleSaveCompany(product.company)
                                },
                                onCardTapped: {
                                    selectedCompany = product.company
                                }
                            )
                            .frame(width: 140)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
        }
    }
    
    // MARK: - Featured Products Section
    
    private var featuredProductsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Featured Products")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
            
            if !gridProducts.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20)
                ], spacing: 20) {
                    ForEach(gridProducts.prefix(100)) { product in
                        ShortFeatureCard(
                            product: product,
                            isSaved: savedProductsManager.isProductSaved(product),
                            isInCart: cartManager.isInCart(product),
                            onSaveTapped: {
                                if savedProductsManager.isProductSaved(product) {
                                    savedProductsManager.removeSavedProduct(product)
                                } else {
                                    savedProductsManager.saveProduct(product)
                                }
                            },
                            onAddToCart: {
                                cartManager.addToCart(product)
                            },
                            onCardTapped: {
                                selectedProduct = product
                            },
                            onCompanyTapped: {
                                selectedCompany = product.company
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Search Category
    
    private func searchByCategory(_ category: String) {
        searchText = category
        showingSearch = true
    }
    
    // MARK: - Perform Search
    
    private func performSearch(query: String) async {
        do {
            let products = try await typesenseClient.searchProducts(
                query: query,
                page: 1,
                perPage: 50
            )
            
            await MainActor.run {
                searchResults = products
                showSearchDropdown = !products.isEmpty
            }
        } catch {
            await MainActor.run {
                searchResults = []
                showSearchDropdown = false
            }
            print("Search error: \(error)")
        }
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

// MARK: - Company Feature Card (Featured Brands)

struct CompanyFeatureCard: View {
    let product: Product
    let allCompanyProducts: [Product]
    let onCardTapped: () -> Void
    let onProductTapped: () -> Void
    
    @EnvironmentObject var typesenseClient: TypesenseClient
    @State private var productCategories: [String] = []
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                // Company name at top, left aligned with image
                Text(product.company)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(alignment: .top, spacing: 12) {
                    // Left side: Product example image
                    CachedAsyncImage(url: URL(string: product.imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color.white
                            .overlay(
                                ProgressView()
                            )
                    }
                    .frame(width: 100, height: 100)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        onProductTapped()
                    }
                    
                    // Right side: "See more..." and category chips
                    VStack(alignment: .leading, spacing: 6) {
                        // "See more..." label
                        Text("See more...")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(Color(.systemGray3))
                        
                        // Category chips
                        if !productCategories.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(productCategories.prefix(4), id: \.self) { category in
                                    Text(category)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.white)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                                        )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            
            // Arrow button (positioned in bottom right)
            Button(action: onCardTapped) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color(red: 0.26, green: 0.63, blue: 0.95))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 280, height: 160)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        .onAppear {
            loadCategories()
        }
    }
    
    private func loadCategories() {
        // Extract unique categories from company products
        let categories = Set(allCompanyProducts.map { $0.mainCategory })
        productCategories = Array(categories.prefix(4))
    }
}

// MARK: - Large Feature Card (Carousel) - REMOVED

// MARK: - Short Feature Card (Grid)

struct ShortFeatureCard: View {
    let product: Product
    let isSaved: Bool
    let isInCart: Bool
    let onSaveTapped: () -> Void
    let onAddToCart: () -> Void
    let onCardTapped: () -> Void
    let onCompanyTapped: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with Heart - 1:1 frame, aspect fit, white background, with padding
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: URL(string: product.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.white
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(width: 150, height: 150)
                .background(Color.white)
                .cornerRadius(12)
                .clipped()
                .frame(maxWidth: .infinity)
                
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
                .padding(10)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .onTapGesture {
                onCardTapped()
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                // Company name first (light grey) - clickable if callback provided
                if let onCompanyTapped = onCompanyTapped {
                    Button(action: {
                        onCompanyTapped()
                    }) {
                        Text(product.company)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(product.company)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1))
                        .lineLimit(1)
                }
                
                // Product name (black)
                Text(product.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .padding(.bottom, 4)
                
                // Price and Add button
                HStack {
                    Text(product.formattedPrice)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button(action: onAddToCart) {
                        Image(systemName: isInCart ? "checkmark" : "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(isInCart ? Color(red: 0, green: 0.75, blue: 0.33) : Color(red: 0.26, green: 0.63, blue: 0.95))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 6)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Featured Brand Circle Card (like saved companies style)

struct FeaturedBrandCircleCard: View {
    let product: Product
    let isSaved: Bool
    let onSaveTapped: () -> Void
    let onCardTapped: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onCardTapped) {
                VStack(spacing: 4) {
                    // Company Logo Circle (using product image)
                    AsyncImage(url: URL(string: product.imageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.95, green: 0.97, blue: 1))
                                
                                Text(product.company.prefix(1).uppercased())
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(Color(red: 0.26, green: 0.63, blue: 0.95))
                            }
                        case .empty:
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.95, green: 0.97, blue: 1))
                                
                                ProgressView()
                                    .tint(Color(red: 0.26, green: 0.63, blue: 0.95))
                            }
                        @unknown default:
                            Circle()
                                .fill(Color(red: 0.95, green: 0.97, blue: 1))
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(red: 0.26, green: 0.63, blue: 0.95).opacity(0.2), lineWidth: 2)
                    )
                    .padding(.top, 12)
                    
                    // Company Name with fixed height container
                    Text(product.company)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(height: 40, alignment: .top)
                        .padding(.horizontal, 8)
                    
                    Spacer()
                    
                    // Category
                    Text(product.mainCategory)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(.systemGray))
                        .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, minHeight: 170)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            // Heart Button
            Button(action: onSaveTapped) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSaved ? .red : .gray)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }
}

// MARK: - Helper Struct for Identifiable String

struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

#Preview {
    ShopView(selectedTab: .constant(.shop))
        .environmentObject(SavedProductsManager())
        .environmentObject(SavedCompaniesManager())
        .environmentObject(CartManager())
}
