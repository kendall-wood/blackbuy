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
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var typesenseClient: TypesenseClient
    
    @State private var similarProducts: [Product] = []
    @State private var isLoadingSimilar = false
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
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
                        .dsCardShadow()
                        
                        // Heart Button
                        Button(action: {
                            savedProductsManager.toggleSaveProduct(product)
                        }) {
                            Image(systemName: savedProductsManager.isProductSaved(product) ? "heart.fill" : "heart")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(savedProductsManager.isProductSaved(product) ? DS.brandRed : .gray)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.95))
                                .clipShape(Circle())
                                .dsCardShadow()
                        }
                        .buttonStyle(.plain)
                        .padding(16)
                    }
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.top, 90)
                    .padding(.bottom, DS.horizontalPadding)
                    
                    // Product Info Section
                    VStack(alignment: .leading, spacing: 8) {
                        // Company name
                        Text(product.company)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DS.brandBlue)
                        
                        // Product name
                        Text(product.name)
                            .font(.system(size: 24, weight: .semibold))
                            .tracking(-0.3)
                            .foregroundColor(.black)
                            .lineLimit(3)
                            .lineSpacing(2)
                            .padding(.top, 2)
                        
                        // Price
                        Text(product.formattedPrice)
                            .font(.system(size: 26, weight: .semibold))
                            .tracking(-0.5)
                            .foregroundColor(.black)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        
                        // Categories label
                        Text("CATEGORIES")
                            .font(DS.label)
                            .tracking(DS.labelTracking)
                            .foregroundColor(Color(.systemGray))
                            .padding(.top, 16)
                        
                        // Category chips
                        FlowLayout(spacing: 8) {
                            if !product.mainCategory.isEmpty && product.mainCategory != "Other" {
                                CategoryChip(text: product.mainCategory, isPrimary: true)
                            }
                            
                            if !product.productType.isEmpty && product.productType != "Other" {
                                CategoryChip(text: product.productType, isPrimary: false)
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
                            Text("SIMILAR PRODUCTS")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(DS.labelTracking)
                                .foregroundColor(Color(.systemGray))
                                .padding(.horizontal, DS.horizontalPadding)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(similarProducts) { similarProduct in
                                        SimilarProductCardWrapper(product: similarProduct)
                                            .environmentObject(typesenseClient)
                                            .environmentObject(savedProductsManager)
                                            .environmentObject(cartManager)
                                    }
                                }
                                .padding(.horizontal, DS.horizontalPadding)
                            }
                        }
                        .padding(.bottom, 32)
                    } else if isLoadingSimilar {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SIMILAR PRODUCTS")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(DS.labelTracking)
                                .foregroundColor(Color(.systemGray))
                                .padding(.horizontal, DS.horizontalPadding)
                            
                            HStack(spacing: 16) {
                                ForEach(0..<3, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: DS.radiusMedium)
                                        .fill(Color(.systemGray6))
                                        .frame(width: 140, height: 200)
                                }
                            }
                            .padding(.horizontal, DS.horizontalPadding)
                        }
                        .padding(.bottom, 32)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .background(DS.cardBackground)
            
            // Custom Header (back button and logo)
            VStack(spacing: 0) {
                AppHeader(centerContent: .logo, onBack: { dismiss() })
                Spacer()
            }
            
            // Blue Plus Button (bottom right, fixed position)
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: {
                        cartManager.addToCart(product)
                    }) {
                        Image(systemName: cartManager.isInCart(product) ? "checkmark" : "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Group {
                                    if cartManager.isInCart(product) {
                                        Circle().fill(DS.brandGreen)
                                    } else {
                                        Circle().fill(DS.brandGradient)
                                    }
                                }
                            )
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            loadSimilarProducts()
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
                print("Error loading similar products: \(error)")
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
        Text(text.uppercased())
            .font(DS.label)
            .tracking(0.8)
            .foregroundColor(isPrimary ? DS.brandBlue : Color(.systemGray2))
            .lineLimit(1)
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

// MARK: - Similar Product Card Wrapper

struct SimilarProductCardWrapper: View {
    let product: Product
    @State private var showingDetail = false
    @EnvironmentObject var typesenseClient: TypesenseClient
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            SimilarProductCard(product: product)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            ProductDetailView(product: product)
                .environmentObject(typesenseClient)
                .environmentObject(savedProductsManager)
                .environmentObject(cartManager)
        }
    }
}

// MARK: - Similar Product Card Component

struct SimilarProductCard: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image
            CachedAsyncImage(url: URL(string: product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Color(.systemGray6)
                    ProgressView()
                }
            }
            .frame(width: 140, height: 140)
            .clipped()
            .cornerRadius(DS.radiusMedium)
            
            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                Text(product.company.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(Color(.systemGray))
                    .lineLimit(1)
                
                Text(product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
                
                Text(product.formattedPrice)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundColor(.black)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .frame(width: 140)
        .background(DS.cardBackground)
        .cornerRadius(DS.radiusMedium)
        .dsCardShadow()
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusMedium)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
    }
}

#Preview {
    ProductDetailView(product: Product.sampleShampoo)
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
        .environmentObject(TypesenseClient())
}
