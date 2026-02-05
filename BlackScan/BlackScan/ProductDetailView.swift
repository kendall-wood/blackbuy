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
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                        
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
                    .padding(.top, 80)
                    .padding(.bottom, 24)
                    
                    // Product Info Section
                    VStack(alignment: .leading, spacing: 8) {
                        // Company name
                        Text(product.company)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        // Product name
                        Text(product.name)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(3)
                        
                        // Price
                        Text(product.formattedPrice)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.top, 4)
                        
                        // Categories label
                        Text("Categories")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(.systemGray))
                            .padding(.top, 12)
                        
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
                            Text("Similar Products")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(similarProducts) { similarProduct in
                                        NavigationLink(destination: ProductDetailView(product: similarProduct)) {
                                            SimilarProductCard(product: similarProduct)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.bottom, 32)
                    } else if isLoadingSimilar {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Similar Products")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
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
                    // Back Button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .frame(height: 44)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
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
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isPrimary ? .white : .black)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isPrimary ? Color(red: 0.26, green: 0.63, blue: 0.95) : Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPrimary ? Color.clear : Color.black.opacity(0.15), lineWidth: 0.5)
            )
    }
}

// MARK: - Similar Product Card Component

struct SimilarProductCard: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Product Image
            AsyncImage(url: URL(string: product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Color(.systemGray6)
                    
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                // Product Name (2 lines max)
                Text(product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Company Name
                Text(product.company)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Price
                Text(product.formattedPrice)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 140)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ProductDetailView(product: Product.sampleShampoo)
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
        .environmentObject(TypesenseClient())
}
