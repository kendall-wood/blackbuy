import SwiftUI

/// Simple product detail view
struct ProductDetailView: View {
    
    let product: Product
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Product Image
                    AsyncImage(url: URL(string: product.imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color(.systemGray6)
                            .overlay(
                                ProgressView()
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    // Product Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(product.name)
                            .font(.system(size: 24, weight: .bold))
                        
                        Text(product.company)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                        
                        Text(product.formattedPrice)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // Category
                        Text(product.mainCategory)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        // Product Type
                        if !product.productType.isEmpty {
                            Text(product.productType)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Buy Button
                        Button(action: {
                            openProductURL(product.productUrl)
                        }) {
                            Text("Buy Now")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(red: 0, green: 0.48, blue: 1))
                                .cornerRadius(12)
                        }
                        
                        // Add to Cart Button
                        Button(action: {
                            cartManager.addToCart(product)
                        }) {
                            HStack {
                                Image(systemName: "bag")
                                Text("Add to Cart")
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0, green: 0.48, blue: 1), lineWidth: 2)
                            )
                        }
                        
                        // Save Button
                        Button(action: {
                            savedProductsManager.toggleSaveProduct(product)
                        }) {
                            HStack {
                                Image(systemName: savedProductsManager.isProductSaved(product) ? "heart.fill" : "heart")
                                Text(savedProductsManager.isProductSaved(product) ? "Saved" : "Save for Later")
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(savedProductsManager.isProductSaved(product) ? .red : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(.systemGray))
                    }
                }
            }
        }
    }
    
    private func openProductURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    ProductDetailView(product: Product.sampleShampoo)
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
}
