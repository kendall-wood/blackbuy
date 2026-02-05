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

/// Simple product detail view
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
                            Color.white
                                .overlay(
                                    ProgressView()
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                        
                        // Heart Button (overlayed in top right)
                        Button(action: {
                            savedProductsManager.toggleSaveProduct(product)
                        }) {
                            Image(systemName: savedProductsManager.isProductSaved(product) ? "heart.fill" : "heart")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(savedProductsManager.isProductSaved(product) ? .red : .gray)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.95))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 90)
                    .padding(.bottom, 24)
                    
                    // Product Info Section
                    VStack(alignment: .leading, spacing: 8) {
                        // Company name
                        Text(product.company.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(Color(.systemGray))
                        
                        // Product name
                        Text(product.name)
                            .font(.system(size: 24, weight: .semibold))
                            .tracking(-0.3)
                            .foregroundColor(.black)
                            .lineLimit(3)
                            .lineSpacing(2)
                            .padding(.top, 2)
                        
                        // Price with tight kerning
                        Text(product.formattedPrice)
                            .font(.system(size: 26, weight: .semibold))
                            .tracking(-0.5)
                            .foregroundColor(.black)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        
                        // Categories label
                        Text("CATEGORIES")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(Color(.systemGray))
                            .padding(.top, 16)
                        
                        // Category chips from taxonomy
                        FlowLayout(spacing: 8) {
                            // Main Category chip
                            if !product.mainCategory.isEmpty && product.mainCategory != "Other" {
                                CategoryChip(text: product.mainCategory, isPrimary: true)
                            }
                            
                            // Product Type chip (subcategory)
                            if !product.productType.isEmpty && product.productType != "Other" {
                                CategoryChip(text: product.productType, isPrimary: false)
                            }
                            
                            // Form chip if available
                            if let form = product.form, !form.isEmpty && form != "other" {
                                CategoryChip(text: form.capitalized, isPrimary: false)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    
                    // Similar Products Section
                    if !similarProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SIMILAR PRODUCTS")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(Color(.systemGray))
                                .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(similarProducts) { similarProduct in
                                        SimilarProductCardWrapper(product: similarProduct)
                                            .environmentObject(typesenseClient)
                                            .environmentObject(savedProductsManager)
                                            .environmentObject(cartManager)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.bottom, 32)
                    } else if isLoadingSimilar {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SIMILAR PRODUCTS")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(Color(.systemGray))
                                .padding(.horizontal, 24)
                            
                            HStack(spacing: 16) {
                                ForEach(0..<3, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                        .frame(width: 140, height: 200)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 32)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color.white)
            
            // Custom Header (back button only)
            VStack(spacing: 0) {
                HStack {
                    // Back Button - matching scan page style
                    Button(action: {
                        dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)

                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(red: 0.26, green: 0.63, blue: 0.95))
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .background(Color.white)
                
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
                            .background(cartManager.isInCart(product) ? Color(red: 0, green: 0.75, blue: 0.33) : Color(red: 0.26, green: 0.63, blue: 0.95))
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
                // Search for products in the same category and product type
                let products = try await typesenseClient.searchProducts(
                    query: product.productType,
                    page: 1,
                    perPage: 20
                )
                
                // Filter to same main category, exclude current product, and limit to 10
                let filtered = products
                    .filter { $0.id != product.id && $0.mainCategory == product.mainCategory }
                    .prefix(10)
                
                await MainActor.run {
                    similarProducts = Array(filtered)
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
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundColor(isPrimary ? Color(red: 0.26, green: 0.63, blue: 0.95) : Color(.systemGray2))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPrimary ? Color(red: 0.26, green: 0.63, blue: 0.95) : Color(.systemGray5), lineWidth: 1.5)
            )
    }
}

// MARK: - Similar Product Card Wrapper

struct SimilarProductCardWrapper: View {
    let product: Product
    @State private var isNavigating = false
    @EnvironmentObject var typesenseClient: TypesenseClient
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        ZStack {
            NavigationLink(destination: ProductDetailView(product: product)
                .environmentObject(typesenseClient)
                .environmentObject(savedProductsManager)
                .environmentObject(cartManager), isActive: $isNavigating) {
                EmptyView()
            }
            .opacity(0)
            
            Button(action: {
                isNavigating = true
            }) {
                SimilarProductCard(product: product)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Similar Product Card Component

struct SimilarProductCard: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image
            AsyncImage(url: URL(string: product.imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_):
                    ZStack {
                        Color(.systemGray6)
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(Color(.systemGray))
                    }
                case .empty:
                    ZStack {
                        Color(.systemGray6)
                        ProgressView()
                    }
                @unknown default:
                    Color(.systemGray6)
                }
            }
            .frame(width: 140, height: 140)
            .clipped()
            .cornerRadius(12)
            
            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                // Company Name (uppercase with tracking)
                Text(product.company.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(Color(.systemGray))
                    .lineLimit(1)
                
                // Product Name (2 lines max)
                Text(product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
                
                // Price with tight tracking
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
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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
