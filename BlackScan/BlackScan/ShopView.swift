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
    @EnvironmentObject var toastManager: ToastManager
    @EnvironmentObject var productCacheManager: ProductCacheManager
    
    // State for search and category browsing (featured products come from cache)
    @State private var searchResults: [Product] = []
    @State private var searchError: String?
    @State private var selectedCategory: String? = nil
    @State private var selectedProduct: Product?
    @State private var selectedCompany: String?
    @State private var currentCarouselIndex = 0
    @State private var showingAllFeatured = false
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showSearchDropdown = false
    @FocusState private var isSearchFocused: Bool
    @State private var shopScrollToTop: Bool = false
    
    // Category browsing state
    @State private var categoryProducts: [Product] = []
    @State private var displayedCategoryProducts: [Product] = []
    @State private var isCategoryLoading = false
    @State private var categorySortOrder: SortOrder = .relevant
    @State private var categoryServerPage: Int = 1
    @State private var categoryTotalFound: Int = 0
    @State private var hasMoreCategoryPages: Bool = false
    @State private var isCategoryLoadingMore: Bool = false
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
        "Women's Care",
        "Men's Care",
        "Women's Clothing",
        "Men's Clothing",
        "Vitamins & Supplements",
        "Home Care",
        "Books & More",
        "Accessories",
        "Baby & Kids"
    ]
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Hair Care":                return "comb"
        case "Skincare":                 return "drop"
        case "Body Care":               return "hands.and.sparkles"
        case "Makeup":                   return "wand.and.stars"
        case "Fragrance":               return "aqi.medium"
        case "Women's Care":            return "♀"
        case "Men's Care":              return "♂"
        case "Women's Clothing":        return "icon_dress"
        case "Men's Clothing":          return "tshirt"
        case "Vitamins & Supplements":  return "pill"
        case "Home Care":               return "house"
        case "Books & More":            return "book"
        case "Accessories":             return "watch.analog"
        case "Baby & Kids":             return "stroller"
        default:                         return "tag"
        }
    }
    
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
                                ZStack {
                                    Circle()
                                        .fill(DS.cardBackground)
                                        .frame(width: 44, height: 44)
                                        .dsCircleShadow()
                                    
                                    Image("cart_icon")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .foregroundColor(DS.brandBlue)
                                }
                                .overlay(alignment: .topTrailing) {
                                    if cartManager.totalItemCount > 0 {
                                        Text("\(cartManager.totalItemCount)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(minWidth: 20, minHeight: 20)
                                            .background(DS.brandBlue)
                                            .clipShape(Circle())
                                            .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        )
                    )
                    
                    // Search bar
                    searchBar
                    
                    // Main Content
                    ScrollViewReader { mainProxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: DS.sectionSpacing) {
                                // Categories Section
                                categoriesSection
                                    .padding(.top, 12)
                                    .id("shopTop")
                                
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
                        .onChange(of: shopScrollToTop) { _ in
                            withAnimation(.easeOut(duration: 0.25)) {
                                mainProxy.scrollTo("shopTop", anchor: .top)
                            }
                        }
                    }
                }
                .background(DS.cardBackground)
                
                // Search Dropdown Overlay (only while typing)
                if showSearchDropdown && isSearchFocused && !searchResults.isEmpty {
                    searchDropdown
                }
            }
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            handlePendingSearch()
        }
        .onChange(of: pendingShopSearch) { _, _ in
            handlePendingSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCategory)) { notification in
            if let category = notification.object as? String {
                handleCategoryNavigation(category)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchInShop)) { notification in
            if let query = notification.object as? String {
                searchText = query
                commitSearch()
            }
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
                .environmentObject(typesenseClient)
        }
        .fullScreenCover(isPresented: $showingAllFeatured) {
            AllFeaturedProductsView(excludedProductIds: Set(productCacheManager.carouselProducts.map { $0.id } + productCacheManager.gridProducts.map { $0.id }))
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
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            commitSearch()
                        }
                }
                .onChange(of: searchText) { oldValue, newValue in
                    searchTask?.cancel()
                    
                    if newValue.isEmpty {
                        searchResults = []
                        withAnimation(.easeOut(duration: 0.2)) {
                            showSearchDropdown = false
                        }
                        return
                    }
                    
                    // Show dropdown suggestions while typing
                    showSearchDropdown = true
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 250_000_000)
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
            .contentShape(Rectangle())
            .onTapGesture {
                isSearchFocused = true
            }
            .background(
                RoundedRectangle(cornerRadius: DS.radiusMedium)
                    .fill(Color.white)
                    .dsCardShadow(cornerRadius: DS.radiusMedium)
            )
            .padding(.horizontal, DS.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(DS.cardBackground)
        }
    }
    
    // MARK: - Search Dropdown (autocomplete suggestions)
    
    private var searchDropdown: some View {
        VStack(spacing: 0) {
            // Spacer to push dropdown below search bar
            // Header (60 + 10pt top) + search bar (~62pt) + 2pt gap
            Color.clear
                .frame(height: 134)
                .contentShape(Rectangle())
                .onTapGesture { showSearchDropdown = false }
            
            VStack(spacing: 0) {
                // Search label + Close button
                HStack {
                    Text("Search \"\(searchText)\"")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: { showSearchDropdown = false }) {
                        Text("Close")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(.systemGray))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                                    .overlay(
                                        Capsule()
                                            .stroke(DS.strokeColor, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)
                
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
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusLarge)
                    .stroke(DS.strokeColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            .padding(.horizontal, DS.horizontalPadding)
            
            Spacer()
                .contentShape(Rectangle())
                .onTapGesture { showSearchDropdown = false }
        }
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(DS.sectionHeader)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
            
            ScrollViewReader { proxy in
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
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            selectedCategory = nil
                                            categoryProducts = []
                                            displayedCategoryProducts = []
                                        }
                                    } else {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            selectedCategory = category
                                        }
                                        loadCategoryProducts(category)
                                        withAnimation {
                                            proxy.scrollTo(category, anchor: .leading)
                                        }
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        let icon = categoryIcon(for: category)
                                        let isUnicode = icon.unicodeScalars.first.map { !$0.isASCII } ?? false
                                        let isAsset = icon.hasPrefix("icon_")
                                        if isUnicode {
                                            Text(icon)
                                                .font(.system(size: 14))
                                        } else if isAsset {
                                            Image(icon)
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 14, height: 14)
                                        } else {
                                            Image(systemName: icon)
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                        Text(category)
                                            .font(.system(size: 15, weight: selectedCategory == category ? .semibold : .medium))
                                    }
                                    .foregroundColor(DS.brandBlue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .cornerRadius(DS.radiusMedium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.radiusMedium)
                                            .stroke(selectedCategory == category ? DS.brandBlue : DS.strokeColor, lineWidth: selectedCategory == category ? 2 : 1)
                                    )
                                }
                                .buttonStyle(DSButtonStyle())
                                .id(category)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 14)
                }
                .contentMargins(.horizontal, DS.horizontalPadding, for: .scrollContent)
                .onChange(of: selectedCategory) { _, newCategory in
                    if let cat = newCategory {
                        withAnimation {
                            proxy.scrollTo(cat, anchor: .leading)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Search Results Section (grid, like category browse)
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sort button
            HStack {
                DSSortButton(label: "Sort") {
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
                }
                
                Spacer()
            }
            .padding(.horizontal, DS.horizontalPadding)
            
            // Showing count
            Text("Showing \(displayedSearchProducts.count) of \(searchGridProducts.count) products")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(.systemGray))
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
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
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
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
                                if savedProductsManager.isProductSaved(product) {
                                    savedProductsManager.removeSavedProduct(product)
                                    toastManager.show(.unsaved)
                                } else {
                                    savedProductsManager.saveProduct(product)
                                    toastManager.show(.saved)
                                }
                            },
                            onAddToCart: {
                                if cartManager.isInCart(product) {
                                    cartManager.removeFromCart(product)
                                    toastManager.show(.removedFromCheckout)
                                } else {
                                    cartManager.addToCart(product)
                                    toastManager.show(.addedToCheckout)
                                }
                            },
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
                            .foregroundColor(DS.brandBlue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .cornerRadius(DS.radiusMedium)
                            .dsCardShadow(cornerRadius: DS.radiusMedium)
                    }
                    .buttonStyle(DSButtonStyle())
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Category Browse Section
    
    private var categoryBrowseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sort button
            HStack {
                DSSortButton(label: "Sort") {
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
                }
                
                Spacer()
            }
            .padding(.horizontal, DS.horizontalPadding)
            
            // Showing count
            Text("Showing \(displayedCategoryProducts.count) of \(categoryTotalFound) products")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(.systemGray))
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
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
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
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
                                if savedProductsManager.isProductSaved(product) {
                                    savedProductsManager.removeSavedProduct(product)
                                    toastManager.show(.unsaved)
                                } else {
                                    savedProductsManager.saveProduct(product)
                                    toastManager.show(.saved)
                                }
                            },
                            onAddToCart: {
                                if cartManager.isInCart(product) {
                                    cartManager.removeFromCart(product)
                                    toastManager.show(.removedFromCheckout)
                                } else {
                                    cartManager.addToCart(product)
                                    toastManager.show(.addedToCheckout)
                                }
                            },
                            onCompanyTapped: { selectedCompany = product.company }
                        )
                    }
                }
                .padding(.horizontal, DS.horizontalPadding)
                
                // Load More button
                if displayedCategoryProducts.count < categoryTotalFound {
                    Button(action: loadMoreCategoryProducts) {
                        Group {
                            if isCategoryLoadingMore {
                                ProgressView()
                                    .tint(DS.brandBlue)
                            } else {
                                Text("Load More")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(DS.brandBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white)
                        .cornerRadius(DS.radiusMedium)
                        .dsCardShadow(cornerRadius: DS.radiusMedium)
                    }
                    .buttonStyle(DSButtonStyle())
                    .disabled(isCategoryLoadingMore)
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Featured Brands Section
    
    private var featuredBrandsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured Brands")
                .font(DS.sectionHeader)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
            
            if !productCacheManager.carouselProducts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(productCacheManager.carouselProducts) { product in
                            FeaturedBrandCircleCard(
                                product: product,
                                isSaved: savedCompaniesManager.isCompanySaved(product.company),
                                onSaveTapped: {
                                    let wasSaved = savedCompaniesManager.isCompanySaved(product.company)
                                    savedCompaniesManager.toggleSaveCompany(
                                        product.company,
                                        imageUrl: product.imageUrl,
                                        category: product.mainCategory
                                    )
                                    toastManager.show(wasSaved ? .unsaved : .saved)
                                },
                                onCardTapped: {
                                    selectedCompany = product.company
                                }
                            )
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
            
            if !productCacheManager.gridProducts.isEmpty {
                LazyVGrid(columns: UnifiedProductCard.gridColumns, spacing: DS.gridSpacing) {
                    ForEach(productCacheManager.gridProducts.prefix(100)) { product in
                        UnifiedProductCard(
                            product: product,
                            isSaved: savedProductsManager.isProductSaved(product),
                            isInCart: cartManager.isInCart(product),
                            onCardTapped: { selectedProduct = product },
                            onSaveTapped: {
                                if savedProductsManager.isProductSaved(product) {
                                    savedProductsManager.removeSavedProduct(product)
                                    toastManager.show(.unsaved)
                                } else {
                                    savedProductsManager.saveProduct(product)
                                    toastManager.show(.saved)
                                }
                            },
                            onAddToCart: {
                                if cartManager.isInCart(product) {
                                    cartManager.removeFromCart(product)
                                    toastManager.show(.removedFromCheckout)
                                } else {
                                    cartManager.addToCart(product)
                                    toastManager.show(.addedToCheckout)
                                }
                            },
                            onCompanyTapped: { selectedCompany = product.company }
                        )
                    }
                }
                .padding(.horizontal, DS.horizontalPadding)
                
                // See All Products button
                Button(action: { showingAllFeatured = true }) {
                    HStack(spacing: 6) {
                        Text("See All Featured Products")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(DS.brandBlue)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DS.brandBlue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                                    .cornerRadius(DS.radiusLarge)
                    .dsCardShadow(cornerRadius: DS.radiusLarge)
                }
                .buttonStyle(DSButtonStyle())
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.top, 16)
            }
        }
    }
    
    // MARK: - Search Actions
    
    /// Navigate to the Shop and select a category row (e.g. from ProductDetailView chip)
    private func handleCategoryNavigation(_ category: String) {
        // Clear any active search
        searchText = ""
        activeSearchQuery = nil
        searchResults = []
        
        // Select the category and load its products
        withAnimation(.easeOut(duration: 0.25)) {
            selectedCategory = category
        }
        loadCategoryProducts(category)
        
        // Scroll main content to top so the user sees the category section
        shopScrollToTop.toggle()
    }
    
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
        let query = InputValidator.sanitizeSearchQuery(searchText)
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
        
        // Dismiss keyboard and dropdown
        isSearchFocused = false
        
        Task {
            do {
                let products = try await NetworkSecurity.withRetry(maxAttempts: 2) {
                    try await typesenseClient.searchProducts(
                        query: query,
                        page: 1,
                        perPage: Env.maxResultsPerPage
                    )
                }
                
                await MainActor.run {
                    searchGridProducts = products
                    loadMoreSearchProducts()
                    isSearchLoading = false
                }
            } catch {
                await MainActor.run {
                    isSearchLoading = false
                }
                Log.error("Search grid failed", category: .network)
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
        categoryServerPage = 1
        categoryTotalFound = 0
        hasMoreCategoryPages = false
        categorySortOrder = .relevant
        
        Task {
            do {
                let result = try await NetworkSecurity.withRetry(maxAttempts: 2) {
                    try await typesenseClient.searchByCategory(
                        mainCategory: category,
                        page: 1
                    )
                }
                
                await MainActor.run {
                    categoryProducts = result.products
                    categoryTotalFound = result.totalFound
                    categoryServerPage = 1
                    hasMoreCategoryPages = categoryProducts.count < categoryTotalFound
                    showMoreLocalCategoryProducts()
                    isCategoryLoading = false
                }
            } catch {
                await MainActor.run {
                    isCategoryLoading = false
                }
                Log.error("Category load failed", category: .network)
            }
        }
    }
    
    /// Show more products from the locally fetched pool
    private func showMoreLocalCategoryProducts() {
        let sorted = sortedCategoryProducts
        let start = displayedCategoryProducts.count
        let end = min(start + pageSize, sorted.count)
        
        if start < sorted.count {
            displayedCategoryProducts.append(contentsOf: sorted[start..<end])
        }
    }
    
    /// Load more category products — pulls from local pool first, fetches next server page when exhausted
    private func loadMoreCategoryProducts() {
        let sorted = sortedCategoryProducts
        
        // If we still have local products not yet displayed, show those first
        if displayedCategoryProducts.count < sorted.count {
            showMoreLocalCategoryProducts()
            return
        }
        
        // Otherwise fetch the next page from the server
        guard hasMoreCategoryPages, !isCategoryLoadingMore, let category = selectedCategory else { return }
        
        isCategoryLoadingMore = true
        let nextPage = categoryServerPage + 1
        
        Task {
            do {
                let result = try await NetworkSecurity.withRetry(maxAttempts: 2) {
                    try await typesenseClient.searchByCategory(
                        mainCategory: category,
                        page: nextPage
                    )
                }
                
                await MainActor.run {
                    categoryServerPage = nextPage
                    categoryProducts.append(contentsOf: result.products)
                    hasMoreCategoryPages = categoryProducts.count < categoryTotalFound
                    showMoreLocalCategoryProducts()
                    isCategoryLoadingMore = false
                }
            } catch {
                await MainActor.run {
                    isCategoryLoadingMore = false
                }
                Log.error("Category page load failed", category: .network)
            }
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
        let sanitizedQuery = InputValidator.sanitizeSearchQuery(query)
        guard !sanitizedQuery.isEmpty else { return }
        
        do {
            let products = try await typesenseClient.searchProducts(
                query: sanitizedQuery,
                page: 1,
                perPage: 5
            )
            
            await MainActor.run {
                searchResults = products
                if products.isEmpty {
                    showSearchDropdown = false
                }
            }
        } catch {
            await MainActor.run {
                searchResults = []
                showSearchDropdown = false
            }
            Log.debug("Dropdown search failed", category: .network)
        }
    }
    
    // MARK: - Load Products (handled by ProductCacheManager)
}

// MARK: - Featured Brand Circle Card

struct FeaturedBrandCircleCard: View {
    let product: Product
    let isSaved: Bool
    let onSaveTapped: () -> Void
    let onCardTapped: () -> Void
    
    var body: some View {
        Button(action: onCardTapped) {
            HStack(spacing: 14) {
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
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(DS.brandBlue.opacity(0.2), lineWidth: 1.5)
                )
                
                // Name and category
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.company)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DS.brandBlue)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    
                    Text(product.mainCategory)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                // Heart Button
                Button(action: onSaveTapped) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSaved ? DS.brandRed : DS.brandBlue)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                        .dsCircleShadow()
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(DS.cardBackground)
            .cornerRadius(DS.radiusMedium)
            .dsCardShadow()
        }
        .buttonStyle(DSButtonStyle())
    }
}

// MARK: - Helper Struct for Identifiable String

struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}

#Preview {
    ShopView(selectedTab: .constant(.shop), pendingShopSearch: .constant(nil))
        .environmentObject(SavedProductsManager())
        .environmentObject(SavedCompaniesManager())
        .environmentObject(CartManager())
        .environmentObject(ProductCacheManager())
}
