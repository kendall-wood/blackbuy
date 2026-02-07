import Foundation
import SwiftUI

/// Cart Manager for managing shopping cart items with company grouping
/// Provides persistence, quantity management, and checkout features
@MainActor
class CartManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var cartItems: [CartItem] = []
    @Published var isLoading = false
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let cartItemsKey = "cart_items"
    
    // MARK: - Initialization
    
    init() {
        loadCartItems()
    }
    
    // MARK: - Public Methods
    
    /// Add a product to the cart
    func addToCart(_ product: Product, quantity: Int = 1) {
        // Check if product already exists in cart
        if let existingIndex = cartItems.firstIndex(where: { $0.id == product.id }) {
            cartItems[existingIndex].quantity += quantity
        } else {
            let newItem = CartItem(product: product, quantity: quantity)
            cartItems.append(newItem)
        }
        
        persistCartItems()
        Log.debug("Added to cart: \(product.name)", category: .storage)
    }
    
    /// Remove a product from the cart
    func removeFromCart(_ product: Product) {
        cartItems.removeAll { $0.id == product.id }
        persistCartItems()
        Log.debug("Removed from cart: \(product.name)", category: .storage)
    }
    
    /// Update quantity for a cart item
    func updateQuantity(for product: Product, quantity: Int) {
        guard quantity > 0 else {
            removeFromCart(product)
            return
        }
        
        if let index = cartItems.firstIndex(where: { $0.id == product.id }) {
            cartItems[index].quantity = quantity
            persistCartItems()
        }
    }
    
    /// Toggle checked status for a cart item
    func toggleChecked(for product: Product) {
        if let index = cartItems.firstIndex(where: { $0.id == product.id }) {
            cartItems[index].isChecked.toggle()
            persistCartItems()
        }
    }
    
    /// Clear all items from the cart
    func clearCart() {
        cartItems.removeAll()
        persistCartItems()
        Log.debug("Cart cleared", category: .storage)
    }
    
    /// Remove all checked items from cart
    func removeCheckedItems() {
        let removedCount = cartItems.filter { $0.isChecked }.count
        cartItems.removeAll { $0.isChecked }
        persistCartItems()
        Log.debug("Removed \(removedCount) checked items", category: .storage)
    }
    
    /// Check if a product is in the cart
    func isInCart(_ product: Product) -> Bool {
        return cartItems.contains { $0.id == product.id }
    }
    
    /// Get quantity for a product in cart
    func quantity(for product: Product) -> Int {
        return cartItems.first { $0.id == product.id }?.quantity ?? 0
    }
    
    // MARK: - Cart Calculations
    
    /// Total number of items in cart
    var totalItemCount: Int {
        return cartItems.reduce(0) { $0 + $1.quantity }
    }
    
    /// Total price of all items in cart
    var totalPrice: Double {
        return cartItems.reduce(0) { $0 + $1.totalPrice }
    }
    
    /// Formatted total price
    var formattedTotalPrice: String {
        return String(format: "$%.2f", totalPrice)
    }
    
    /// Number of unique companies in cart
    var companyCount: Int {
        return Set(cartItems.map { $0.product.company }).count
    }
    
    // MARK: - Company Grouping
    
    /// Group cart items by company
    func groupedByCompany() -> [CartItemGroup] {
        let grouped = Dictionary(grouping: cartItems) { $0.product.company }
        
        return grouped.map { company, items in
            CartItemGroup(
                company: company,
                items: items.map { CartItemEntry(item: $0) }
            )
        }.sorted { $0.company < $1.company }
    }
    
    // MARK: - Private Methods
    
    /// Load cart items from UserDefaults
    private func loadCartItems() {
        guard let data = userDefaults.data(forKey: cartItemsKey) else {
            cartItems = []
            return
        }
        
        do {
            cartItems = try JSONDecoder().decode([CartItem].self, from: data)
            Log.debug("Loaded \(cartItems.count) cart items", category: .storage)
        } catch {
            Log.error("Failed to load cart items", category: .storage)
            cartItems = []
        }
    }
    
    /// Persist cart items to UserDefaults
    private func persistCartItems() {
        do {
            let data = try JSONEncoder().encode(cartItems)
            userDefaults.set(data, forKey: cartItemsKey)
            Log.debug("Persisted \(cartItems.count) cart items", category: .storage)
        } catch {
            Log.error("Failed to persist cart items", category: .storage)
        }
    }
}

// MARK: - Cart Item Group Models

/// Group of cart items from the same company
struct CartItemGroup: Identifiable {
    let id = UUID()
    let company: String
    let items: [CartItemEntry]
    
    var totalPrice: Double {
        return items.reduce(0) { $0 + $1.item.totalPrice }
    }
    
    var formattedTotalPrice: String {
        return String(format: "$%.2f", totalPrice)
    }
    
    var totalItems: Int {
        return items.reduce(0) { $0 + $1.item.quantity }
    }
}

/// Cart item entry wrapper for UI
struct CartItemEntry: Identifiable {
    let id = UUID()
    let item: CartItem
}
