import SwiftUI

/// Shop view with featured carousel, categories, and product grid
struct ShopView: View {
    
    @Binding var selectedTab: AppTab
    @Binding var pendingShopSearch: String?
    var onBack: () -> Void = {}
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
    @State private var showingAllFeatured = false
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showSearchDropdown = false
    
    // Category browsing state
    @State private var categoryProducts: [Product] = []
    @State private var displayedCategoryProducts: [Product] = []
    @State private var isCategoryLoading = false
    @State private var categorySortOrder: SortOrder = .relevant
    @State private var categoryPage = 0
    private let pageSize = 24
    
    // Search results grid state
    @State private var activeSearchQuery: String? = nil
    @State private var searchGridProducts: [Product] = []
    @State private var displayedSearchProducts: [Product] = []
    @State private var isSearchLoading = false
    @State private var searchSortOrder: SortOrder = .relevant
    
    enum SortOrder: String, CaseIterable {
        case relevant = "Relevant"
        case priceLowToHigh = "Price: Low to High"
        case priceHighToLow = "Price: High to Low"
        case nameAZ = "Name: A-Z"
    }
    
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
                    AppHeader(
                        centerContent: .logo,
                        onBack: onBack,
                        trailingContent: AnyView(
                            Button(action: { selectedTab = .checkout }) {
                                ZStack(alignment: .topTrailing) {
                                    Image("cart_icon")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(DS.brandBlue)
                                        .frame(width: 44, height: 44)
                                    
                                    if cartManager.totalItemCount > 0 {
                                        Text("\(cartManager.totalItemCount)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(minWidth: 18, minHeight: 18)
                                            .background(DS.brandBlue)
                                            .clipShape(Circle())
                                            .offset(x: 2, y: 2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        )
                    )
                    
                    // Search bar
                    searchBar
                    
                    // Main Content
                    ScrollView {
                        VStack(spacing: DS.sectionSpacing) {
                            // Categories Section
                            categoriesSection
                                .padding(.top, 16)
                            
                            if activeSearchQuery != nil {
                                // Search results mode
                                searchResultsSection
                            } else if selectedCategory != nil {
                                // Category browsing mode
                                categoryBrowseSection
                            } else {
                                // Default: Featured Brands + Products
                                featuredBrandsSection
                                featuredProductsSection
                            }
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
            handlePendingSearch()
        }
        .onChange(of: pendingShopSearch) { _, _ in
            handlePendingSearch()
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
                .environmentObject(typesenseClient)
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
                .environmentObject(savedCompaniesManager)
                .environmentObject(cartManager)
        }
    }
    
    // MARK: - Search Bar
    
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
                        .submitLabel(.search)
                        .onSubmit {
                            commitSearch()
                        }
                }
                .onChange(of: searchText) { oldValue, newValue in
                    searchTask?.cancel()
                    
                    if newValue.isEmpty {
                        searchResults = []
                        showSearchDropdown = false
                        return
                    }
                    
                    // Show dropdown suggestions while typing
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if !Task.isCancelled {
                            await performDropdownSearch(query: newValue)
                        }
                    }
                }
                
                if !searchText.isEmpty {
                    Button(action: {
                        clearSearch()
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
    
    // MARK: - Search Dropdown (autocomplete suggestions)
    
    private var searchDropdown: some View {
        VStack(spacing: 0) {
            // Spacer to push dropdown below search bar
            // Header (~56) + search bar (~60) + padding + gap
            Color.clear
                .frame(height: 118)
                .contentShape(Rectangle())
                .onTapGesture { showSearchDropdown = false }
            
            VStack(spacing: 0) {
                ForEach(Array(searchResults.prefix(3).enumerated()), id: \.element.id) { index, product in
                    Button(action: {
                        selectedProduct = product
                        showSearchDropdown = false
                    }) {
                        HStack(spacing: 14) {
                            CachedAsyncImage(url: URL(string: product.imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(product.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                
                                Text(product.company)
                                    .font(.system(size: 13))
                                    .foregroundColor(DS.brandBlue)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(product.formattedPrice)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    if index < min(searchResults.count, 3) - 1 {
                        Divider()
                            .padding(.leading, 78)
                    }
                }
                
                // "See X results" row
                if searchResults.count > 0 {
                    Button(action: {
                        commitSearch()
                    }) {
                        HStack(spacing: 6) {
                            Text("See \(searchResults.count) results")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(DS.brandBlue)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(DS.brandBlue)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.white)
            .cornerRadius(DS.radiusLarge)
            .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 6)
            .padding(.horizontal, DS.horizontalPadding)
            
            Spacer()
                .contentShape(Rectangle())
                .onTapGesture { showSearchDropdown = false }
        }
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
                            // Clear any active search when tapping a category
                            if activeSearchQuery != nil {
                                activeSearchQuery = nil
                                searchGridProducts = []
                                displayedSearchProducts = []
                                searchText = ""
                            }
                            
                            if selectedCategory == category {
                                // Deselect
                                selectedCategory = nil
                                categoryProducts = []
                                displayedCategoryProducts = []
                            } else {
                                selectedCategory = category
                                loadCategoryProducts(category)
                            }
                        }) {
                            Text(category)
                                .font(.system(size: 15, weight: selectedCategory == category ? .semibold : .medium))
                                .foregroundColor(DS.brandBlue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(DS.radiusMedium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.radiusMedium)
                                        .stroke(DS.brandBlue, lineWidth: selectedCategory == category ? 2 : 0)
                                )
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
    
    // MARK: - Search Results Section (grid, like category browse)
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sort button
            HStack {
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(action: {
                            searchSortOrder = order
                            applySearchSort()
                        }) {
                            HStack {
                                Text(order.rawValue)
                                if searchSortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 13, weight: .medium))
                        Text("Sort")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: DS.radiusSmall)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.radiusSmall)
                                    .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, DS.horizontalPadding)
            
            // Showing count
            Text("Showing \(displayedSearchProducts.count) of \(searchGridProducts.count) products")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(.systemGray))
                .padding(.horizontal, DS.horizontalPadding)
            
            if isSearchLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Searching...")
                        .font(DS.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else if displayedSearchProducts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(Color(.systemGray3))
                    Text("No results found")
                        .font(DS.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Product grid
                LazyVGrid(columns: UnifiedProductCard.gridColumns, spacing: DS.gridSpacing) {
                    ForEach(displayedSearchProducts) { product in
                        UnifiedProductCard(
                            product: product,
                            isSaved: savedProductsManager.isProductSaved(product),
                            isInCart: cartManager.isInCart(product),
                            onCardTapped: { selectedProduct = product },
                            onSaveTapped: {
                                savedProductsManager.isProductSaved(product)
                                    ? savedProductsManager.removeSavedProduct(product)
                                    : savedProductsManager.saveProduct(product)
                            },
                            onAddToCart: { cartManager.isInCart(product) ? cartManager.removeFromCart(product) : cartManager.addToCart(product) },
                            onCompanyTapped: { selectedCompany = product.company }
                        )
                    }
                }
                .padding(.horizontal, DS.horizontalPadding)
                
                // Load More button
                if displayedSearchProducts.count < searchGridProducts.count {
                    Button(action: loadMoreSearchProducts) {
                        Text("Load More")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(DS.brandGradient)
                            .cornerRadius(DS.radiusMedium)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Category Browse Section
    
    private var categoryBrowseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sort button
            HStack {
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(action: {
                            categorySortOrder = order
                            applyCategorySort()
                        }) {
                            HStack {
                                Text(order.rawValue)
                                if categorySortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 13, weight: .medium))
                        Text("Sort")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: DS.radiusSmall)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.radiusSmall)
                                    .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, DS.horizontalPadding)
            
            // Showing count
            Text("Showing \(displayedCategoryProducts.count) of \(categoryProducts.count) products")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(.systemGray))
                .padding(.horizontal, DS.horizontalPadding)
            
            if isCategoryLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(DS.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else if displayedCategoryProducts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(Color(.systemGray3))
                    Text("No products found")
                        .font(DS.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Product grid
                LazyVGrid(columns: UnifiedProductCard.gridColumns, spacing: DS.gridSpacing) {
                    ForEach(displayedCategoryProducts) { product in
                        UnifiedProductCard(
                            product: product,
                            isSaved: savedProductsManager.isProductSaved(product),
                            isInCart: cartManager.isInCart(product),
                            onCardTapped: { selectedProduct = product },
                            onSaveTapped: {
                                savedProductsManager.isProductSaved(product)
                                    ? savedProductsManager.removeSavedProduct(product)
                                    : savedProductsManager.saveProduct(product)
                            },
                            onAddToCart: { cartManager.isInCart(product) ? cartManager.removeFromCart(product) : cartManager.addToCart(product) },
                            onCompanyTapped: { selectedCompany = product.company }
                        )
                    }
                }
                .padding(.horizontal, DS.horizontalPadding)
                
                // Load More button
                if displayedCategoryProducts.count < categoryProducts.count {
                    Button(action: loadMoreCategoryProducts) {
                        Text("Load More")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(DS.brandGradient)
                            .cornerRadius(DS.radiusMedium)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.top, 8)
                }
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
                                savedProductsManager.isProductSaved(product)
                                    ? savedProductsManager.removeSavedProduct(product)
                                    : savedProductsManager.saveProduct(product)
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
    
    // MARK: - Search Actions
    
    /// Picks up a search query passed from another tab (e.g. Recent Scans)
    private func handlePendingSearch() {
        if let query = pendingShopSearch {
            pendingShopSearch = nil
            searchText = query
            commitSearch()
        }
    }
    
    /// Called when user presses return or taps "See all" — commits the search to a grid
    private func commitSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        showSearchDropdown = false
        
        // Clear category selection
        selectedCategory = nil
        categoryProducts = []
        displayedCategoryProducts = []
        
        // Enter search results mode
        activeSearchQuery = query
        searchSortOrder = .relevant
        isSearchLoading = true
        searchGridProducts = []
        displayedSearchProducts = []
        
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: query,
                    page: 1,
                    perPage: 200
                )
                
                await MainActor.run {
                    searchGridProducts = products
                    loadMoreSearchProducts()
                    isSearchLoading = false
                }
            } catch {
                await MainActor.run {
                    isSearchLoading = false
                }
                print("Search grid error: \(error)")
            }
        }
    }
    
    /// Clears search text and exits search results mode
    private func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        searchResults = []
        showSearchDropdown = false
        activeSearchQuery = nil
        searchGridProducts = []
        displayedSearchProducts = []
    }
    
    // MARK: - Search Results Pagination & Sort
    
    private func loadMoreSearchProducts() {
        let sorted = sortedSearchProducts
        let start = displayedSearchProducts.count
        let end = min(start + pageSize, sorted.count)
        
        if start < sorted.count {
            displayedSearchProducts.append(contentsOf: sorted[start..<end])
        }
    }
    
    private func applySearchSort() {
        displayedSearchProducts = Array(sortedSearchProducts.prefix(displayedSearchProducts.count))
    }
    
    private var sortedSearchProducts: [Product] {
        switch searchSortOrder {
        case .relevant:
            return searchGridProducts
        case .priceLowToHigh:
            return searchGridProducts.sorted { $0.price < $1.price }
        case .priceHighToLow:
            return searchGridProducts.sorted { $0.price > $1.price }
        case .nameAZ:
            return searchGridProducts.sorted { $0.name < $1.name }
        }
    }
    
    // MARK: - Category Loading
    
    private func loadCategoryProducts(_ category: String) {
        isCategoryLoading = true
        categoryProducts = []
        displayedCategoryProducts = []
        categoryPage = 0
        categorySortOrder = .relevant
        
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: category,
                    page: 1,
                    perPage: 200
                )
                
                let filtered = products.filter { $0.mainCategory == category }
                
                await MainActor.run {
                    categoryProducts = filtered
                    loadMoreCategoryProducts()
                    isCategoryLoading = false
                }
            } catch {
                await MainActor.run {
                    isCategoryLoading = false
                }
                print("Error loading category products: \(error)")
            }
        }
    }
    
    private func loadMoreCategoryProducts() {
        let sorted = sortedCategoryProducts
        let start = displayedCategoryProducts.count
        let end = min(start + pageSize, sorted.count)
        
        if start < sorted.count {
            displayedCategoryProducts.append(contentsOf: sorted[start..<end])
        }
    }
    
    private func applyCategorySort() {
        displayedCategoryProducts = Array(sortedCategoryProducts.prefix(displayedCategoryProducts.count))
    }
    
    private var sortedCategoryProducts: [Product] {
        switch categorySortOrder {
        case .relevant:
            return categoryProducts
        case .priceLowToHigh:
            return categoryProducts.sorted { $0.price < $1.price }
        case .priceHighToLow:
            return categoryProducts.sorted { $0.price > $1.price }
        case .nameAZ:
            return categoryProducts.sorted { $0.name < $1.name }
        }
    }
    
    // MARK: - Dropdown Search (autocomplete)
    
    private func performDropdownSearch(query: String) async {
        do {
            let products = try await typesenseClient.searchProducts(
                query: query,
                page: 1,
                perPage: 20
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
    ShopView(selectedTab: .constant(.shop), pendingShopSearch: .constant(nil))
        .environmentObject(SavedProductsManager())
        .environmentObject(SavedCompaniesManager())
        .environmentObject(CartManager())
}
