import SwiftUI

/// Simple product detail view
struct ProductDetailView: View {
    
    let product: Product
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var typesenseClient: TypesenseClient
    
    @State private var productCategories: [String] = []
    
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
                    .padding(.horizontal, 20)
                    .padding(.top, 80)
                    .padding(.bottom, 24)
                    
                    // Product Info Section
                    VStack(alignment: .leading, spacing: 8) {
                        // Company name (light grey)
                        Text(product.company)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color(.systemGray2))
                        
                        // Product name (black, prominent)
                        Text(product.name)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.black)
                            .lineLimit(3)
                        
                        // Price (black, large)
                        Text(product.formattedPrice)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.black)
                            .padding(.top, 4)
                        
                        // Category chips (from actual product categories)
                        if !productCategories.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(productCategories.prefix(4), id: \.self) { category in
                                    Text(category)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                                        )
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    
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
                .padding(.horizontal, 20)
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
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(red: 0, green: 0.48, blue: 1))
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
            loadCategories()
        }
    }
    
    private func loadCategories() {
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: product.company,
                    page: 1,
                    perPage: 100
                )
                
                let companyProducts = products.filter { $0.company == product.company }
                
                // Extract unique categories from product types
                let categoryStrings = companyProducts.compactMap { product -> String? in
                    guard !product.productType.isEmpty, product.productType != "Other" else { return nil }
                    return product.productType
                }
                let uniqueCategories = Array(Set(categoryStrings)).sorted()
                
                await MainActor.run {
                    productCategories = Array(uniqueCategories.prefix(4))
                }
            } catch {
                print("Error loading categories: \(error)")
            }
        }
    }
}

#Preview {
    ProductDetailView(product: Product.sampleShampoo)
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
        .environmentObject(TypesenseClient())
}
