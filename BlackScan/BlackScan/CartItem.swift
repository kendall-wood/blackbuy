import Foundation

/// Cart item model wrapping a Product with quantity and completion status
struct CartItem: Codable, Identifiable, Hashable {
    let id: String // Use product ID as cart item ID
    let product: Product
    var quantity: Int
    var isChecked: Bool // Mark as "done/purchased"
    let dateAdded: Date
    
    init(product: Product, quantity: Int = 1) {
        self.id = product.id
        self.product = product
        self.quantity = quantity
        self.isChecked = false
        self.dateAdded = Date()
    }
    
    /// Total price for this cart item (price × quantity)
    var totalPrice: Double {
        return product.price * Double(quantity)
    }
    
    /// Formatted total price
    var formattedTotalPrice: String {
        if totalPrice > 0 {
            return String(format: "$%.2f", totalPrice)
        } else {
            return "Price varies"
        }
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CartItem, rhs: CartItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Sample Data for Previews

extension CartItem {
    static let sampleItems: [CartItem] = Product.sampleProducts.prefix(4).map { product in
        CartItem(product: product, quantity: Int.random(in: 1...3))
    }
}

