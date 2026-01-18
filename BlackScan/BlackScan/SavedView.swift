import SwiftUI

/// Saved products and companies view - matches screenshot 2 exactly
struct SavedView: View {
    
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var savedCompaniesManager: SavedCompaniesManager
    @EnvironmentObject var cartManager: CartManager
    
    @State private var selectedProduct: Product?
    @State private var sortOrder: SortOrder = .recentlySaved
    
    @Environment(\.dismiss) var dismiss
    
    enum SortOrder {
        case recentlySaved
        case alphabetical
        case priceHighToLow
        case priceLowToHigh
    }
    
    var body: some View {
        NavigationView {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
                }
            }
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
        }
    }
    
    // MARK: - Saved Companies Section
    
    private var savedCompaniesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Saved Companies")
                    .font(.system(size: 24, weight: .bold))
                
                Spacer()
                
                Text("\(savedCompaniesManager.savedCompanies.count)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            // Companies Grid
            let columns = [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
            
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(savedCompaniesManager.savedCompanies) { company in
                    CompanyCircleCard(
                        company: company,
                        onUnsave: {
                            savedCompaniesManager.removeSavedCompany(company.name)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Saved Products Section
    
    private var savedProductsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saved Products")
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal, 20)
            
            // Count and Sort
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(savedProductsManager.savedProducts.count) Saved")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Text("Local storage only")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button("Recently Saved") { sortOrder = .recentlySaved }
                    Button("Alphabetical") { sortOrder = .alphabetical }
                    Button("Price: High to Low") { sortOrder = .priceHighToLow }
                    Button("Price: Low to High") { sortOrder = .priceLowToHigh }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14, weight: .medium))
                        Text("Recently Saved")
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
            .padding(.horizontal, 20)
            
            // Products Grid
            if savedProductsManager.savedProducts.isEmpty {
                emptyProductsView
            } else {
                productsGrid
            }
        }
    }
    
    private var productsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(savedProductsManager.savedProducts) { product in
                SavedProductCard(
                    product: product,
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
        .padding(.horizontal, 20)
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

/// Company circle card (matches screenshot design)
struct CompanyCircleCard: View {
    let company: SavedCompaniesManager.SavedCompany
    let onUnsave: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                // Company Circle
                ZStack {
                    Circle()
                        .fill(Color(red: 0.85, green: 0.95, blue: 1)) // Light blue
                        .frame(width: 80, height: 80)
                    
                    Text(company.name.prefix(1).uppercased())
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                }
                
                // Heart Button - NOT VISIBLE IN SCREENSHOT, removing
            }
            
            // Company Name
            Text(company.name)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 40, alignment: .top)
            
            // Product Count
            if let count = company.productCount {
                Text("\(count) products")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            // Unsave Heart Button
            Button(action: onUnsave) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Saved product card (matches screenshot design)
struct SavedProductCard: View {
    let product: Product
    let onUnsave: () -> Void
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
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // Heart Button (filled red)
                Button(action: onUnsave) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
                .padding(8)
            }
            .onTapGesture {
                onCardTapped()
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(height: 40, alignment: .top)
                
                Text(product.company)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                    .lineLimit(1)
                
                HStack {
                    Text(product.formattedPrice)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    
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
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
        }
    }
}

#Preview {
    SavedView()
        .environmentObject(SavedProductsManager())
        .environmentObject(SavedCompaniesManager())
        .environmentObject(CartManager())
}
