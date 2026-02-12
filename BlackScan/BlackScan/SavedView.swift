import SwiftUI

/// Saved products and companies view
struct SavedView: View {
    
    @Binding var selectedTab: AppTab
    var onBack: () -> Void = {}
    @StateObject private var typesenseClient = TypesenseClient()
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var savedCompaniesManager: SavedCompaniesManager
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var toastManager: ToastManager
    
    @State private var selectedProduct: Product?
    @State private var sortOrder: SortOrder = .recentlySaved
    @State private var showReportSheet = false
    
    enum SortOrder {
        case recentlySaved
        case alphabetical
        case priceHighToLow
        case priceLowToHigh
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppHeader(
                centerContent: .logo,
                onBack: onBack,
                trailingContent: AnyView(
                    ReportMenuButton { showReportSheet = true }
                )
            )
            
            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.sectionSpacing) {
                    // Saved Companies Section
                    if !savedCompaniesManager.savedCompanies.isEmpty {
                        savedCompaniesSection
                    }
                    
                    // Saved Products Section
                    savedProductsSection
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(DS.cardBackground)
        }
        .background(DS.cardBackground)
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
                .environmentObject(typesenseClient)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportIssueView(currentTab: .saved)
        }
    }
    
    // MARK: - Saved Companies Section
    
    private var savedCompaniesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Saved Brands")
                    .font(DS.sectionHeader)
                    .foregroundColor(.black)
                
                Text("\(savedCompaniesManager.savedCompanies.count)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(.systemGray))
                
                Spacer()
            }
            .padding(.horizontal, DS.horizontalPadding)
            
            // Companies Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(savedCompaniesManager.sortedByDate) { company in
                        CompanyCircleCard(
                            company: company,
                            typesenseClient: typesenseClient,
                            onUnsave: {
                                savedCompaniesManager.removeSavedCompany(company.name)
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
    
    // MARK: - Saved Products Section
    
    private var savedProductsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Saved Products")
                    .font(DS.sectionHeader)
                    .foregroundColor(.black)
                
                Text("\(savedProductsManager.savedProducts.count)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(.systemGray))
                
                Spacer()
            }
            .padding(.horizontal, DS.horizontalPadding)
            
            // Sort Menu
            HStack {
                DSSortButton(label: sortOrderLabel) {
                    Button("Recently Saved") { sortOrder = .recentlySaved }
                    Button("Alphabetical") { sortOrder = .alphabetical }
                    Button("Price: High to Low") { sortOrder = .priceHighToLow }
                    Button("Price: Low to High") { sortOrder = .priceLowToHigh }
                }
                
                Spacer()
            }
            .padding(.horizontal, DS.horizontalPadding)
            
            // Products Grid
            if savedProductsManager.savedProducts.isEmpty {
                emptyProductsView
            } else {
                productsGrid
            }
        }
    }
    
    private var sortOrderLabel: String {
        switch sortOrder {
        case .recentlySaved: return "Recent"
        case .alphabetical: return "A-Z"
        case .priceHighToLow: return "Price ↓"
        case .priceLowToHigh: return "Price ↑"
        }
    }
    
    private var productsGrid: some View {
        LazyVGrid(columns: UnifiedProductCard.gridColumns, spacing: DS.gridSpacing) {
            ForEach(sortedProducts) { product in
                UnifiedProductCard(
                    product: product,
                    isSaved: true,
                    isInCart: cartManager.isInCart(product),
                    heartAlwaysFilled: true,
                    onCardTapped: { selectedProduct = product },
                    onSaveTapped: {
                        savedProductsManager.removeSavedProduct(product)
                        toastManager.show(.unsaved)
                    },
                    onAddToCart: {
                        if cartManager.isInCart(product) {
                            cartManager.removeFromCart(product)
                            toastManager.show(.removedFromCheckout)
                        } else {
                            cartManager.addToCart(product)
                            toastManager.show(.addedToCheckout)
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.horizontalPadding)
    }
    
    private var sortedProducts: [Product] {
        switch sortOrder {
        case .recentlySaved:
            return savedProductsManager.savedProducts.reversed()
        case .alphabetical:
            return savedProductsManager.savedProducts.sorted { $0.name < $1.name }
        case .priceHighToLow:
            return savedProductsManager.savedProducts.sorted { $0.price > $1.price }
        case .priceLowToHigh:
            return savedProductsManager.savedProducts.sorted { $0.price < $1.price }
        }
    }
    
    private var emptyProductsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Saved Products")
                .font(DS.sectionHeader)
            
            Text("Tap the heart icon on products to save them here")
                .font(DS.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 60)
    }
}

/// Company circle card with product image (matches FeaturedBrandCircleCard style)
struct CompanyCircleCard: View {
    let company: SavedCompaniesManager.SavedCompany
    let typesenseClient: TypesenseClient
    let onUnsave: () -> Void
    
    @EnvironmentObject var savedCompaniesManager: SavedCompaniesManager
    @State private var productImage: String?
    @State private var mainCategory: String = ""
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                // Company Logo Circle
                Group {
                    if let imageUrl = productImage, let url = URL(string: imageUrl) {
                        CachedAsyncImage(url: url) { image in
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
                    } else {
                        ZStack {
                            Circle()
                                .fill(DS.circleFallbackBg)
                            ProgressView()
                                .tint(DS.brandBlue)
                        }
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(DS.brandBlue.opacity(0.2), lineWidth: 1.5)
                )
                .padding(.top, 10)
                
                // Company Name
                Text(company.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 34, alignment: .top)
                    .padding(.horizontal, 8)
                
                // Category
                Text(mainCategory.isEmpty ? "Brand" : mainCategory)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(.systemGray))
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(DS.cardBackground)
            .cornerRadius(DS.radiusMedium)
            .dsCardShadow()
            
            // Heart Button
            Button(action: onUnsave) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DS.brandRed)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .dsCircleShadow()
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .onAppear {
            // Use cached image if available, otherwise fetch and cache
            if let cached = company.cachedImageUrl {
                productImage = cached
                mainCategory = company.cachedCategory ?? ""
            } else {
                fetchAndCacheImage()
            }
        }
    }
    
    /// Fetch image from Typesense and cache it in SavedCompaniesManager for next time
    private func fetchAndCacheImage() {
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: company.name,
                    page: 1,
                    perPage: 5
                )
                
                if let product = products.first {
                    await MainActor.run {
                        productImage = product.imageUrl
                        mainCategory = product.mainCategory
                        // Persist so we don't fetch again
                        savedCompaniesManager.updateCachedImage(
                            for: company.name,
                            imageUrl: product.imageUrl,
                            category: product.mainCategory
                        )
                    }
                }
            } catch {
                Log.error("Failed to load product image for company", category: .network)
            }
        }
    }
}

#Preview {
    SavedView(selectedTab: .constant(.saved))
        .environmentObject(SavedProductsManager())
        .environmentObject(SavedCompaniesManager())
        .environmentObject(CartManager())
}
