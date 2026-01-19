import SwiftUI

/// Saved products and companies view - matches screenshot 2 exactly
struct SavedView: View {
    
    @StateObject private var typesenseClient = TypesenseClient()
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var savedCompaniesManager: SavedCompaniesManager
    @EnvironmentObject var cartManager: CartManager
    
    @State private var selectedProduct: Product?
    @State private var sortOrder: SortOrder = .recentlySaved
    
    enum SortOrder {
        case recentlySaved
        case alphabetical
        case priceHighToLow
        case priceLowToHigh
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            header
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Saved Companies Section
                    if !savedCompaniesManager.savedCompanies.isEmpty {
                        savedCompaniesSection
                    }
                    
                    // Saved Products Section
                    savedProductsSection
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Color.white)
        }
        .background(Color.white)
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
                .environmentObject(typesenseClient)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Spacer()
            
            // BlackBuy Logo
            Image("shop_logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 28)
                .foregroundColor(Color(red: 0.26, green: 0.63, blue: 0.95))
            
            Spacer()
        }
        .frame(height: 44)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    // MARK: - Saved Companies Section
    
    private var savedCompaniesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Saved Companies")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("\(savedCompaniesManager.savedCompanies.count)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(.systemGray))
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            // Companies Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(savedCompaniesManager.savedCompanies) { company in
                        CompanyCircleCard(
                            company: company,
                            onUnsave: {
                                savedCompaniesManager.removeSavedCompany(company.name)
                            }
                        )
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, 24)
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("\(savedProductsManager.savedProducts.count)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(.systemGray))
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            // Sort Menu
            HStack {
                Menu {
                    Button("Recently Saved") { sortOrder = .recentlySaved }
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
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
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
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        
        return LazyVGrid(columns: columns, spacing: 24) {
            ForEach(sortedProducts) { product in
                SavedProductCard(
                    product: product,
                    isInCart: cartManager.isInCart(product),
                    onUnsave: {
                        savedProductsManager.removeSavedProduct(product)
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
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
                .font(.system(size: 18, weight: .semibold))
            
            Text("Tap the heart icon on products to save them here")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 60)
    }
}

/// Company circle card (matches ShopView style)
struct CompanyCircleCard: View {
    let company: SavedCompaniesManager.SavedCompany
    let onUnsave: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Company Circle
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.97, blue: 1)) // Very light blue
                    .frame(width: 64, height: 64)
                
                Text(company.name.prefix(1).uppercased())
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color(red: 0.26, green: 0.63, blue: 0.95))
            }
            .padding(.top, 12)
            
            // Company Name
            Text(company.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 8)
            
            // Product Count
            if let productCount = company.productCount {
                Text("\(productCount) products")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(.systemGray))
                    .padding(.top, 2)
            }
            
            // Unsave Heart Button
            Button(action: onUnsave) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

/// Saved product card (matches ShopView style)
struct SavedProductCard: View {
    let product: Product
    let isInCart: Bool
    let onUnsave: () -> Void
    let onAddToCart: () -> Void
    let onCardTapped: () -> Void
    
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
                
                // Heart Button (filled red since it's saved)
                Button(action: onUnsave) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
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
                // Company name first (light grey)
                    Text(product.company)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(.systemGray2))
                        .lineLimit(1)
                
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

#Preview {
    SavedView()
        .environmentObject(SavedProductsManager())
        .environmentObject(SavedCompaniesManager())
        .environmentObject(CartManager())
}
