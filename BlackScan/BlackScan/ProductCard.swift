import SwiftUI

// MARK: - Unified Product Card

/// Single configurable product card used across the entire app.
/// Replaces ShortFeatureCard, SavedProductCard, ProductCardWithNumber, and old ProductCard.
struct UnifiedProductCard: View {
    let product: Product
    
    // State flags
    var isSaved: Bool = false
    var isInCart: Bool = false
    
    // Configuration
    var showHeart: Bool = true
    var showAddToCart: Bool = true
    var heartAlwaysFilled: Bool = false
    var numberBadge: Int? = nil
    
    // Callbacks
    var onCardTapped: (() -> Void)? = nil
    var onSaveTapped: (() -> Void)? = nil
    var onAddToCart: (() -> Void)? = nil
    var onCompanyTapped: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image area with optional badge and heart
            ZStack {
                // Number badge (top-left)
                if let number = numberBadge {
                    VStack {
                        HStack {
                            Text("\(number)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(DS.brandBlue)
                                .clipShape(Circle())
                                .padding(10)
                            Spacer()
                        }
                        Spacer()
                    }
                    .zIndex(2)
                }
                
                // Heart button (top-right)
                if showHeart {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { onSaveTapped?() }) {
                                Image(systemName: (heartAlwaysFilled || isSaved) ? "heart.fill" : "heart")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor((heartAlwaysFilled || isSaved) ? DS.brandRed : .gray)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.9))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(10)
                        }
                        Spacer()
                    }
                    .zIndex(2)
                }
                
                // Product image
                CachedAsyncImage(url: URL(string: product.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.white
                        .overlay(ProgressView())
                }
                .frame(width: 150, height: 150)
                .background(Color.white)
                .cornerRadius(DS.radiusMedium)
                .clipped()
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .onTapGesture { onCardTapped?() }
            
            // Product info
            VStack(alignment: .leading, spacing: 4) {
                // Company name
                if let onCompanyTapped = onCompanyTapped {
                    Button(action: onCompanyTapped) {
                        Text(product.company)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DS.brandBlue)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(product.company)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DS.brandBlue)
                        .lineLimit(1)
                }
                
                // Product name
                Text(product.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .padding(.bottom, 4)
                
                // Price and add-to-cart button
                HStack {
                    Text(product.formattedPrice)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    if showAddToCart {
                        Button(action: { onAddToCart?() }) {
                            Image(systemName: isInCart ? "checkmark" : "plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isInCart ? .white : DS.brandBlue)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle().fill(isInCart ? DS.brandBlue : Color.white)
                                )
                                .clipShape(Circle())
                                .dsCardShadow()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 6)
        }
        .background(DS.cardBackground)
        .cornerRadius(DS.radiusLarge)
        .dsCardShadow()
    }
}

// MARK: - Grid Layout Helper

extension UnifiedProductCard {
    /// Standard 2-column product grid columns used across the app.
    static var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: DS.gridSpacing),
            GridItem(.flexible(), spacing: DS.gridSpacing)
        ]
    }
}

// MARK: - Preview and Sample Data

#Preview("Single Card") {
    UnifiedProductCard(
        product: Product.sampleShampoo,
        isSaved: false,
        isInCart: false,
        onCardTapped: { print("Card tapped") },
        onSaveTapped: { print("Save tapped") },
        onAddToCart: { print("Add to cart") },
        onCompanyTapped: { print("Company tapped") }
    )
    .frame(width: 180)
    .padding()
}

#Preview("Numbered Card") {
    UnifiedProductCard(
        product: Product.sampleShampoo,
        isSaved: true,
        isInCart: false,
        numberBadge: 1,
        onCardTapped: { print("Card tapped") },
        onSaveTapped: { print("Save tapped") },
        onAddToCart: { print("Add to cart") }
    )
    .frame(width: 180)
    .padding()
}

#Preview("Grid Layout") {
    ScrollView {
        LazyVGrid(columns: UnifiedProductCard.gridColumns, spacing: DS.gridSpacing) {
            ForEach(Product.sampleProducts) { product in
                UnifiedProductCard(
                    product: product,
                    onCardTapped: { print("Tapped \(product.name)") },
                    onSaveTapped: { print("Save \(product.name)") },
                    onAddToCart: { print("Cart \(product.name)") }
                )
            }
        }
        .padding(.horizontal, DS.horizontalPadding)
    }
    .background(Color(.systemGroupedBackground))
}

// MARK: - Sample Data Extension

extension Product {
    /// Sample product for previews and testing
    static let sampleShampoo = Product(
        id: "sample-1",
        name: "Moisturizing Curl Shampoo for Natural Hair",
        company: "CurlCare Co.",
        price: 24.99,
        imageUrl: "https://via.placeholder.com/200x200/FF6B9D/FFFFFF?text=Shampoo",
        productUrl: "https://example.com/shampoo",
        mainCategory: "Hair Care",
        productType: "Shampoo",
        form: "liquid",
        setBundle: "single",
        tags: ["shampoo", "curl", "moisturizing"]
    )
    
    /// Sample products array for previews
    static let sampleProducts: [Product] = [
        Product(
            id: "sample-1",
            name: "Moisturizing Curl Shampoo",
            company: "CurlCare Co.",
            price: 24.99,
            imageUrl: "https://via.placeholder.com/200x200/FF6B9D/FFFFFF?text=Shampoo",
            productUrl: "https://example.com/shampoo",
            mainCategory: "Hair Care",
            productType: "Shampoo",
            form: "liquid",
            setBundle: "single",
            tags: ["shampoo"]
        ),
        Product(
            id: "sample-2",
            name: "Deep Conditioning Hair Mask",
            company: "NaturalRoots",
            price: 32.00,
            imageUrl: "https://via.placeholder.com/200x200/9B7EDE/FFFFFF?text=Mask",
            productUrl: "https://example.com/mask",
            mainCategory: "Hair Care",
            productType: "Mask/Deep Conditioner",
            form: "cream",
            setBundle: "single",
            tags: ["mask", "deep conditioner"]
        ),
        Product(
            id: "sample-3",
            name: "Curl Defining Gel Strong Hold",
            company: "CoilCare",
            price: 18.50,
            imageUrl: "https://via.placeholder.com/200x200/4ECDC4/FFFFFF?text=Gel",
            productUrl: "https://example.com/gel",
            mainCategory: "Hair Care",
            productType: "Gel/Gelly",
            form: "gel",
            setBundle: "single",
            tags: ["gel", "curl"]
        ),
        Product(
            id: "sample-4",
            name: "Leave-In Conditioner Spray",
            company: "MelaninHair",
            price: 22.00,
            imageUrl: "https://via.placeholder.com/200x200/45B7D1/FFFFFF?text=Spray",
            productUrl: "https://example.com/spray",
            mainCategory: "Hair Care",
            productType: "Leave-In Conditioner",
            form: "spray",
            setBundle: "single",
            tags: ["leave-in", "spray"]
        ),
        Product(
            id: "sample-5",
            name: "Edge Control Styling Cream",
            company: "EdgeMasters",
            price: 12.99,
            imageUrl: "https://via.placeholder.com/200x200/F7DC6F/000000?text=Edge",
            productUrl: "https://example.com/edge",
            mainCategory: "Hair Care",
            productType: "Edge Control",
            form: "cream",
            setBundle: "single",
            tags: ["edge control"]
        ),
        Product(
            id: "sample-6",
            name: "Gift Card",
            company: "BeautyStore",
            price: 50.00,
            imageUrl: "https://via.placeholder.com/200x200/E74C3C/FFFFFF?text=Gift",
            productUrl: "https://example.com/gift",
            mainCategory: "Gifts/Cards",
            productType: "Gift Card",
            form: "other",
            setBundle: "single",
            tags: ["gift card"]
        )
    ]
}
