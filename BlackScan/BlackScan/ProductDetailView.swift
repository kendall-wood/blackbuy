import SwiftUI

/// Flow layout for wrapping category chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

/// Product detail view
struct ProductDetailView: View {
    
    let product: Product
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var savedCompaniesManager: SavedCompaniesManager
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var typesenseClient: TypesenseClient
    @EnvironmentObject var toastManager: ToastManager
    
    @State private var similarProducts: [Product] = []
    @State private var isLoadingSimilar = false
    @State private var selectedSimilarProduct: Product?
    @State private var showingCompany = false
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Product Image with rounded corners, padding, and heart button
                    ZStack(alignment: .topTrailing) {
                        CachedAsyncImage(url: URL(string: product.imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.white.overlay(ProgressView())
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                        .background(Color.white)
                        .cornerRadius(DS.radiusLarge)
                        .dsCardShadow(cornerRadius: DS.radiusLarge)
                        
                        // Heart Button
                        Button(action: {
                            savedProductsManager.toggleSaveProduct(product)
                        }) {
                            Image(systemName: savedProductsManager.isProductSaved(product) ? "heart.fill" : "heart")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(savedProductsManager.isProductSaved(product) ? DS.brandRed : DS.brandBlue)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.95))
                                .clipShape(Circle())
                                .dsCircleShadow()
                        }
                        .buttonStyle(.plain)
                        .padding(16)
                    }
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.top, 90)
                    .padding(.bottom, DS.horizontalPadding)
                    
                    // Product Info Section
                    VStack(alignment: .leading, spacing: 8) {
                        // Company name (clickable)
                        Button(action: { showingCompany = true }) {
                            Text(product.company)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DS.brandBlue)
                        }
                        .buttonStyle(.plain)
                        
                        // Product name
                        Text(product.name)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.black)
                            .lineLimit(3)
                        
                        // Price
                        Text(product.formattedPrice)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(.darkGray))
                            .padding(.top, 4)
                        
                        // Categories label
                        Text("CATEGORIES")
                            .font(DS.label)
                            .foregroundColor(Color(.systemGray))
                            .padding(.top, 16)
                        
                        // Category chips
                        FlowLayout(spacing: 8) {
                            if !product.mainCategory.isEmpty && product.mainCategory != "Other" {
                                Button(action: { navigateToCategory(product.mainCategory) }) {
                                    CategoryChip(text: product.mainCategory, isPrimary: true)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if !product.productType.isEmpty && product.productType != "Other" {
                                Button(action: { searchInShop(product.productType) }) {
                                    CategoryChip(text: product.productType, isPrimary: false)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if let form = product.form, !form.isEmpty && form != "other" {
                                CategoryChip(text: form.capitalized, isPrimary: false)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.bottom, DS.horizontalPadding)
                    
                    // Similar Products Section
                    if !similarProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Similar Products")
                                .font(DS.sectionHeader)
                                .foregroundColor(.black)
                                .padding(.horizontal, DS.horizontalPadding)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DS.gridSpacing) {
                                    ForEach(similarProducts) { similarProduct in
                                        UnifiedProductCard(
                                            product: similarProduct,
                                            isSaved: savedProductsManager.isProductSaved(similarProduct),
                                            isInCart: cartManager.isInCart(similarProduct),
                                            showAddToCart: false,
                                            onCardTapped: { selectedSimilarProduct = similarProduct },
                                            onSaveTapped: { savedProductsManager.toggleSaveProduct(similarProduct) }
                                        )
                                        .frame(width: 160)
                                    }
                                }
                                .padding(.horizontal, DS.horizontalPadding)
                                .padding(.top, 8)
                                .padding(.bottom, 12)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    } else if isLoadingSimilar {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Similar Products")
                                .font(DS.sectionHeader)
                                .foregroundColor(.black)
                                .padding(.horizontal, DS.horizontalPadding)
                            
                            HStack(spacing: 16) {
                                ForEach(0..<3, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: DS.radiusMedium)
                                        .fill(Color(.systemGray6))
                                        .frame(width: 160, height: 220)
                                }
                            }
                            .padding(.horizontal, DS.horizontalPadding)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .background(DS.cardBackground)
            
            // Fixed Header (pinned at top, background extends into safe area)
            VStack(spacing: 0) {
                AppHeader(centerContent: .logo, onBack: { dismiss() })
                    .background(DS.cardBackground.ignoresSafeArea(edges: .top))
                Spacer()
            }
            
            // Add to Cart Button (bottom right, fixed position)
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: {
                        if cartManager.isInCart(product) {
                            cartManager.removeFromCart(product)
                            toastManager.show(.removedFromCheckout)
                        } else {
                            cartManager.addToCart(product)
                            toastManager.show(.addedToCheckout)
                        }
                    }) {
                        Image(systemName: cartManager.isInCart(product) ? "checkmark" : "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(cartManager.isInCart(product) ? .white : DS.brandBlue)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle().fill(cartManager.isInCart(product) ? DS.brandBlue : Color.white)
                            )
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .geometryGroup()
        .onAppear {
            loadSimilarProducts()
        }
        .sheet(item: $selectedSimilarProduct) { product in
            ProductDetailView(product: product)
                .environmentObject(typesenseClient)
                .environmentObject(savedProductsManager)
                .environmentObject(savedCompaniesManager)
                .environmentObject(cartManager)
        }
        .fullScreenCover(isPresented: $showingCompany) {
            CompanyView(companyName: product.company)
                .environmentObject(savedProductsManager)
                .environmentObject(savedCompaniesManager)
                .environmentObject(cartManager)
        }
    }
    
    /// Dismiss and navigate to Shop with a search query
    private func searchInShop(_ query: String) {
        dismiss()
        NotificationCenter.default.post(name: .searchInShop, object: query)
    }
    
    /// Dismiss and navigate to Shop with the corresponding category row selected
    private func navigateToCategory(_ category: String) {
        dismiss()
        // Small delay so the sheet/fullScreenCover dismiss animation completes
        // before the tab switches and ShopView processes the notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NotificationCenter.default.post(name: .navigateToCategory, object: category)
        }
    }
    
    private func loadSimilarProducts() {
        Task {
            await MainActor.run {
                isLoadingSimilar = true
            }
            
            do {
                // Try searching by product type first
                let products = try await typesenseClient.searchProducts(
                    query: product.productType,
                    page: 1,
                    perPage: 30
                )
                
                // Prefer same category, but fall back to any match
                let sameCategory = products
                    .filter { $0.id != product.id && $0.mainCategory == product.mainCategory }
                
                var results: [Product]
                if sameCategory.count >= 3 {
                    results = Array(sameCategory.prefix(10))
                } else {
                    // Fall back: exclude self, take whatever we found
                    results = Array(products.filter { $0.id != product.id }.prefix(10))
                }
                
                // If still empty, try broader search with main category
                if results.isEmpty {
                    let broader = try await typesenseClient.searchProducts(
                        query: product.mainCategory,
                        page: 1,
                        perPage: 20
                    )
                    results = Array(broader.filter { $0.id != product.id }.prefix(10))
                }
                
                await MainActor.run {
                    similarProducts = results
                    isLoadingSimilar = false
                }
            } catch {
                Log.error("Failed to load similar products", category: .network)
                await MainActor.run {
                    isLoadingSimilar = false
                }
            }
        }
    }
}

// MARK: - Category Chip Component

struct CategoryChip: View {
    let text: String
    let isPrimary: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(isPrimary ? DS.brandBlue : Color(.systemGray2))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(DS.radiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusSmall)
                    .stroke(isPrimary ? DS.brandBlue : Color(.systemGray5), lineWidth: 1.5)
            )
    }
}

#Preview {
    ProductDetailView(product: Product.sampleShampoo)
        .environmentObject(SavedProductsManager())
        .environmentObject(SavedCompaniesManager())
        .environmentObject(CartManager())
        .environmentObject(TypesenseClient())
}
