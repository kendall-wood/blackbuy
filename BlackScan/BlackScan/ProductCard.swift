import SwiftUI

/// Reusable product card component matching PRD's clean aesthetic
/// Displays product image, name, company, and price with "Buy" action
struct ProductCard: View {
    let product: Product
    let onBuyTapped: () -> Void
    
    // MARK: - Layout Constants
    
    private let cardCornerRadius: CGFloat = 12
    private let imageHeight: CGFloat = 160
    private let cardPadding: CGFloat = 12
    private let spacing: CGFloat = 8
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            // Product Image
            productImage
            
            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                // Product Name (2 lines max)
                Text(product.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(height: 36, alignment: .top)
                    .multilineTextAlignment(.leading)
                
                // Company Name
                Text(product.company)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Price and Buy Button Row
                HStack {
                    // Price
                    Text(product.formattedPrice)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Buy Button
                    buyButton
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, cardPadding)
            .padding(.bottom, cardPadding)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )
    }
    
    // MARK: - Subviews
    
    private var productImage: some View {
        AsyncImage(url: URL(string: product.imageUrl)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            // Placeholder with subtle background and icon
            ZStack {
                Color(.systemGray6)
                
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: imageHeight)
        .clipShape(
            RoundedRectangle(
                cornerRadius: cardCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            // Subtle overlay for better text readability if needed
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color.clear)
        )
    }
    
    private var buyButton: some View {
        Button(action: onBuyTapped) {
            Text("Buy")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Grid Layout Helper

extension ProductCard {
    /// Creates a LazyVGrid for product cards with responsive columns
    static func createGrid<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        let columns = [
            GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
        ]
        
        return LazyVGrid(columns: columns, spacing: 16) {
            content()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview and Sample Data

#Preview("Single Card") {
    ProductCard(
        product: Product.sampleShampoo,
        onBuyTapped: {
            print("Buy tapped for sample product")
        }
    )
    .frame(width: 180)
    .padding()
}

#Preview("Grid Layout") {
    ScrollView {
        ProductCard.createGrid {
            ForEach(Product.sampleProducts) { product in
                ProductCard(
                    product: product,
                    onBuyTapped: {
                        print("Buy tapped for \(product.name)")
                    }
                )
            }
        }
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
