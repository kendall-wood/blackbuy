import SwiftUI

/// Shop view with featured carousel, categories, and product grid
struct ShopView: View {
    
    @Binding var selectedTab: AppTab
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
                    // Header
                    AppHeader(centerContent: .logo, onBack: { selectedTab = .scan })
                    
                    // Search bar
                    searchBar
                    
                    // Main Content
                    ScrollView {
                        VStack(spacing: DS.sectionSpacing) {
                            // Categories Section
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
                .background(DS.cardBackground)
                
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
                            .font(DS.body)
                            .foregroundColor(Color(.systemGray))
                            .lineLimit(1)
                    }
                    TextField("", text: $searchText)
                        .font(DS.body)
                        .foregroundColor(.black)
                }
                .onChange(of: searchText) { oldValue, newValue in
                    searchTask?.cancel()
                    
                    if newValue.isEmpty {
                        searchResults = []
                        showSearchDropdown = false
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
                RoundedRectangle(cornerRadius: DS.radiusMedium)
                    .fill(Color.white)
                    .dsCardShadow()
            )
            .padding(.horizontal, DS.horizontalPadding)
            .padding(.top, 4)
            .padding(.bottom, 16)
            .background(DS.cardBackground)
        }
    }
    
    // MARK: - Search Dropdown
    
    private var searchDropdown: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 140)
            
            VStack(spacing: 0) {
                ForEach(searchResults.prefix(9)) { product in
                    Button(action: {
                        selectedProduct = product
                        showSearchDropdown = false
                    }) {
                        HStack(spacing: 12) {
                            CachedAsyncImage(url: URL(string: product.imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Color.white
                            }
                            .frame(width: 50, height: 50)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                            
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
                
                Button(action: {
                    showSearchDropdown = false
                    showingSearch = true
                }) {
                    Text("See more...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DS.brandBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(Color(.systemGray6).opacity(0.5))
            }
            .background(Color.white)
            .cornerRadius(DS.radiusMedium)
            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 5)
            .padding(.horizontal, DS.horizontalPadding)
            
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
                .font(DS.sectionHeader)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            selectedCategory = category
                            searchByCategory(category)
                        }) {
                            Text(category)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(DS.brandBlue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(DS.radiusMedium)
                                .dsCardShadow()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Featured Brands Section
    
    private var featuredBrandsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Featured Brands")
                .font(DS.sectionHeader)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
            
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
                    .padding(.horizontal, DS.horizontalPadding)
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
                .font(DS.sectionHeader)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
            
            if !gridProducts.isEmpty {
                LazyVGrid(columns: UnifiedProductCard.gridColumns, spacing: DS.gridSpacing) {
                    ForEach(gridProducts.prefix(100)) { product in
                        UnifiedProductCard(
                            product: product,
                            isSaved: savedProductsManager.isProductSaved(product),
                            isInCart: cartManager.isInCart(product),
                            onCardTapped: { selectedProduct = product },
                            onSaveTapped: {
                                if savedProductsManager.isProductSaved(product) {
                                    savedProductsManager.removeSavedProduct(product)
                                } else {
                                    savedProductsManager.saveProduct(product)
                                }
                            },
                            onAddToCart: { cartManager.isInCart(product) ? cartManager.removeFromCart(product) : cartManager.addToCart(product) },
                            onCompanyTapped: { selectedCompany = product.company }
                        )
                    }
                }
                .padding(.horizontal, DS.horizontalPadding)
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
        print("Loading all products...")
        
        isLoading = true
        searchError = nil
        
        Task {
            do {
                let allProducts = try await typesenseClient.searchProducts(
                    query: "*",
                    page: 1,
                    perPage: 200
                )
                
                await MainActor.run {
                    let uniqueCompanies = Array(Set(allProducts.map { $0.company }))
                    let selectedCompanies = uniqueCompanies.shuffled().prefix(12)
                    var carousel: [Product] = []
                    
                    for company in selectedCompanies {
                        if let product = allProducts.first(where: { $0.company == company }) {
                            carousel.append(product)
                        }
                    }
                    
                    let carouselIds = Set(carousel.map { $0.id })
                    let remainingProducts = allProducts.filter { !carouselIds.contains($0.id) }
                    let grid = Array(remainingProducts.shuffled().prefix(12))
                    
                    carouselProducts = carousel.shuffled()
                    gridProducts = grid
                    isLoading = false
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

// MARK: - Featured Brand Circle Card

struct FeaturedBrandCircleCard: View {
    let product: Product
    let isSaved: Bool
    let onSaveTapped: () -> Void
    let onCardTapped: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onCardTapped) {
                VStack(spacing: 4) {
                    // Company Logo Circle
                    CachedAsyncImage(url: URL(string: product.imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Circle()
                                .fill(DS.circleFallbackBg)
                            
                            ProgressView()
                                .tint(DS.brandBlue)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(DS.brandBlue.opacity(0.2), lineWidth: 2)
                    )
                    .padding(.top, 12)
                    
                    // Company Name
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
                .background(DS.cardBackground)
                .cornerRadius(DS.radiusMedium)
                .dsCardShadow()
            }
            .buttonStyle(.plain)
            
            // Heart Button
            Button(action: onSaveTapped) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSaved ? DS.brandRed : .gray)
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
