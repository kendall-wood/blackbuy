import SwiftUI

/// Detailed product view that slides in from the right
/// Shows full product information with similar products carousel
struct ProductDetailView: View {
    
    // MARK: - Properties
    
    let product: Product
    let allSearchResults: [Product] // Current search results for quick similar product lookup
    let onCategoryTapped: (String) -> Void
    let onProductTapped: (Product) -> Void
    let onBuyTapped: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var similarProductsLoader = SimilarProductsLoader()
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Product Image (1:1 ratio with padding)
                    productImageSection
                    
                    // Product Information
                    productInfoSection
                    
                    // Category Chips
                    categorySection
                    
                    // Shop Button
                    shopButtonSection
                    
                    // Similar Products Carousel
                    if !similarProductsLoader.similarProducts.isEmpty {
                        similarProductsSection
                    }
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignSystem.Colors.gray400)
                    }
                }
            }
        }
        .task {
            // Load similar products using hybrid approach
            await similarProductsLoader.loadSimilarProducts(
                for: product,
                from: allSearchResults
            )
        }
    }
    
    // MARK: - Product Image Section
    
    private var productImageSection: some View {
        VStack(spacing: 0) {
            AsyncImage(url: URL(string: product.imageUrl)) { phase in
                switch phase {
                case .empty:
                    // Loading state
                    ProgressView()
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.0, contentMode: .fit)
                        .background(DesignSystem.Colors.gray100)
                    
                case .success(let image):
                    // Successfully loaded image
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.0, contentMode: .fit)
                    
                case .failure:
                    // Failed to load image
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.gray300)
                        
                        Text("Image unavailable")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1.0, contentMode: .fit)
                    .background(DesignSystem.Colors.gray100)
                    
                @unknown default:
                    EmptyView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
            .padding(DesignSystem.Spacing.lg)
        }
    }
    
    // MARK: - Product Info Section
    
    private var productInfoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Product Name (Large, Bold)
            Text(product.name)
                .font(DesignSystem.Typography.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Company Name (Medium)
            Text(product.company)
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            // Price (Accent Color, Bold)
            Text(product.formattedPrice)
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.md)
    }
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Categories")
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Main Category Chip
                    CategoryChip(
                        title: product.mainCategory,
                        icon: "tag.fill"
                    ) {
                        onCategoryTapped(product.mainCategory)
                        dismiss()
                    }
                    
                    // Product Type Chip
                    CategoryChip(
                        title: product.productType,
                        icon: "cube.fill"
                    ) {
                        onCategoryTapped(product.productType)
                        dismiss()
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
        }
        .padding(.bottom, DesignSystem.Spacing.lg)
    }
    
    // MARK: - Shop Button Section
    
    private var shopButtonSection: some View {
        Button(action: onBuyTapped) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "cart.fill")
                    .font(DesignSystem.Typography.titleMedium)
                
                Text("Shop Now")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.semibold)
            }
            .foregroundColor(DesignSystem.Colors.textOnAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .primaryActionButton(cornerRadius: DesignSystem.CornerRadius.md)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.xl)
    }
    
    // MARK: - Similar Products Section
    
    private var similarProductsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Similar Products")
                        .font(DesignSystem.Typography.titleLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("More \(product.productType)")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Horizontal Scrolling Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(similarProductsLoader.similarProducts) { similarProduct in
                        SimilarProductCard(product: similarProduct) {
                            onProductTapped(similarProduct)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            
            // Loading indicator for similar products
            if similarProductsLoader.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading similar products...")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.backgroundSecondary)
    }
}

// MARK: - Category Chip Component

struct CategoryChip: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
            }
            .foregroundColor(DesignSystem.Colors.accent)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl, style: .continuous)
                    .fill(DesignSystem.Colors.accentLight)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Similar Product Card Component

struct SimilarProductCard: View {
    let product: Product
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Product Image (Square)
                AsyncImage(url: URL(string: product.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 120, height: 120)
                            .background(DesignSystem.Colors.gray100)
                        
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipped()
                        
                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                            .foregroundColor(DesignSystem.Colors.gray300)
                            .frame(width: 120, height: 120)
                            .background(DesignSystem.Colors.gray100)
                        
                    @unknown default:
                        EmptyView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous))
                
                // Product Info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(product.name)
                        .font(DesignSystem.Typography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(product.company)
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                    
                    Text(product.formattedPrice)
                        .font(DesignSystem.Typography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.accent)
                }
                .frame(width: 120, alignment: .leading)
            }
            .padding(DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: DesignSystem.Colors.gray900.opacity(0.08), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Similar Products Loader

@MainActor
class SimilarProductsLoader: ObservableObject {
    @Published var similarProducts: [Product] = []
    @Published var isLoading = false
    
    // Cache for similar products (max 20 product types to prevent memory bloat)
    private static var cache: [String: CachedProducts] = [:]
    private static let maxCacheSize = 20
    private static let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    private let typesenseClient = TypesenseClient()
    
    struct CachedProducts {
        let products: [Product]
        let timestamp: Date
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > SimilarProductsLoader.cacheTimeout
        }
    }
    
    /// Load similar products using hybrid approach
    func loadSimilarProducts(for product: Product, from searchResults: [Product]) async {
        let productType = product.productType
        
        print("🔍 Loading similar products for: \(productType)")
        
        // Step 1: Try to get similar products from current search results (instant)
        let localSimilar = searchResults
            .filter { $0.productType == productType && $0.id != product.id }
            .shuffled() // Randomize for variety
            .prefix(6)
        
        print("📦 Found \(localSimilar.count) similar products in current results")
        
        // If we have enough products locally, use them immediately
        if localSimilar.count >= 3 {
            similarProducts = Array(localSimilar)
            print("✅ Using local similar products (instant)")
            return
        }
        
        // Step 2: Check cache for this product type
        if let cached = Self.cache[productType], !cached.isExpired {
            let cachedSimilar = cached.products
                .filter { $0.id != product.id }
                .prefix(6)
            
            if !cachedSimilar.isEmpty {
                similarProducts = Array(cachedSimilar)
                print("✅ Using cached similar products (instant)")
                return
            }
        }
        
        // Step 3: Need to fetch from API
        isLoading = true
        
        do {
            print("🌐 Fetching similar products from API...")
            
            // Fetch similar products with timeout protection
            let fetchedProducts = try await withTimeout(seconds: 5.0) {
                try await self.typesenseClient.searchProducts(
                    query: productType,
                    page: 1,
                    perPage: 12 // Fetch extra for variety
                )
            }
            
            // Filter out current product and randomize
            let filtered = fetchedProducts
                .filter { $0.id != product.id }
                .shuffled()
                .prefix(6)
            
            similarProducts = Array(filtered)
            
            // Cache the results
            Self.cache[productType] = CachedProducts(
                products: fetchedProducts,
                timestamp: Date()
            )
            
            // Limit cache size
            if Self.cache.count > Self.maxCacheSize {
                // Remove oldest entry
                if let oldestKey = Self.cache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key {
                    Self.cache.removeValue(forKey: oldestKey)
                    print("🧹 Cache limit reached, removed oldest entry")
                }
            }
            
            print("✅ Fetched \(similarProducts.count) similar products from API")
            
        } catch {
            print("⚠️ Failed to fetch similar products: \(error)")
            
            // Fallback: Use whatever local products we have
            if !localSimilar.isEmpty {
                similarProducts = Array(localSimilar)
                print("🔄 Falling back to \(localSimilar.count) local products")
            }
        }
        
        isLoading = false
    }
    
    /// Helper to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            // Return first result (either success or timeout)
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    struct TimeoutError: Error {}
}

// MARK: - Preview

#Preview("Product Detail") {
    ProductDetailView(
        product: Product(
            id: "1",
            name: "Moisturizing Shampoo for Natural Hair",
            company: "SheaMoisture",
            price: 12.99,
            imageUrl: "https://example.com/image.jpg",
            productUrl: "https://example.com/product",
            mainCategory: "Hair Care",
            productType: "Shampoo",
            form: "liquid",
            setBundle: "single",
            tags: ["natural", "moisturizing"]
        ),
        allSearchResults: [],
        onCategoryTapped: { _ in },
        onProductTapped: { _ in },
        onBuyTapped: { }
    )
}

