import SwiftUI

/// Company-specific product view that shows all products from a company
/// Reuses existing components and follows the same design patterns
struct CompanyView: View {
    
    // MARK: - Properties
    
    let companyName: String
    let onBackTapped: () -> Void
    
    // MARK: - State Properties
    
    @StateObject private var typesenseClient = TypesenseClient()
    @State private var searchResults: [Product] = []
    @State private var isLoading = false
    @State private var searchError: String?
    @State private var selectedSort: SortOption = .suggested
    @State private var selectedProduct: Product?
    
    // MARK: - Sort Options (reuse from ShopView)
    
    enum SortOption: String, CaseIterable {
        case suggested = "Suggested"
        case priceLowToHigh = "Price: Low to High"
        case priceHighToLow = "Price: High to Low"
        case nameAZ = "Name: A-Z"
        case nameZA = "Name: Z-A"
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and company info
            companyHeader
            
            // Sort controls (only show if we have products)
            if !searchResults.isEmpty {
                sortControls
            }
            
            // Main content
            ScrollView {
                if isLoading {
                    loadingView
                } else if searchResults.isEmpty && !isLoading {
                    emptyStateView
                } else {
                    // Products grid
                    ProductCard.createGrid {
                        ForEach(searchResults) { product in
                            ProductCard(
                                product: product,
                                onImageTapped: {
                                    selectedProduct = product
                                },
                                onBuyTapped: {
                                    openProductURL(product.productUrl)
                                },
                                onCardTapped: {
                                    selectedProduct = product
                                }
                                // No onCompanyTapped since we're already viewing this company
                            )
                        }
                    }
                    .padding(.bottom, DesignSystem.Spacing.md)
                }
            }
        }
        .navigationBarHidden(true)
        .background(DesignSystem.Colors.background)
        .onAppear {
            loadCompanyProducts()
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(
                product: product,
                allSearchResults: searchResults,
                onCategoryTapped: { _ in
                    // Could add category filtering in the future
                },
                onProductTapped: { newProduct in
                    selectedProduct = newProduct
                },
                onBuyTapped: {
                    openProductURL(product.productUrl)
                }
            )
        }
    }
    
    // MARK: - Company Header
    
    private var companyHeader: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Back button
            Button(action: onBackTapped) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            
            // Company info
            VStack(alignment: .leading, spacing: 2) {
                Text(companyName)
                    .font(DesignSystem.Typography.headlineSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                if !searchResults.isEmpty {
                    Text("\(searchResults.count) products")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    // MARK: - Sort Controls
    
    private var sortControls: some View {
        HStack {
            Text("Sort by:")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Spacer()
            
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: {
                        selectedSort = option
                        sortResults()
                    }) {
                        HStack {
                            Text(option.rawValue)
                            if selectedSort == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(selectedSort.rawValue)
                        .font(DesignSystem.Typography.bodySmall)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                        .fill(DesignSystem.Colors.primary.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.md)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.accent))
            
            Text("Loading \(companyName) products...")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, DesignSystem.Spacing.xxxl)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "building.2")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No Products Found")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("We couldn't find any products from \(companyName) right now.")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.xxxl)
    }
    
    // MARK: - Private Methods
    
    private func loadCompanyProducts() {
        isLoading = true
        searchError = nil
        
        Task {
            do {
                // Search for products from this specific company
                let products = try await typesenseClient.searchProducts(
                    query: companyName, // Search by company name
                    page: 1,
                    perPage: 100 // Get more products for company view
                )
                
                // Filter to ensure we only get products from this exact company
                let companyProducts = products.filter { 
                    $0.company.lowercased() == companyName.lowercased() 
                }
                
                await MainActor.run {
                    searchResults = companyProducts
                    sortResults() // Apply initial sorting
                    isLoading = false
                }
                
                print("✅ Loaded \(companyProducts.count) products for company: \(companyName)")
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    searchError = error.localizedDescription
                    print("❌ Error loading company products: \(error)")
                }
            }
        }
    }
    
    private func sortResults() {
        switch selectedSort {
        case .suggested:
            // Keep original search relevance order
            break
            
        case .priceLowToHigh:
            searchResults = searchResults.sorted { $0.price < $1.price }
            
        case .priceHighToLow:
            searchResults = searchResults.sorted { $0.price > $1.price }
            
        case .nameAZ:
            searchResults = searchResults.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        case .nameZA:
            searchResults = searchResults.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
    }
    
    private func openProductURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid product URL: \(urlString)")
            return
        }
        
        UIApplication.shared.open(url)
    }
}

// MARK: - Preview

#Preview("Company View") {
    CompanyView(
        companyName: "Shea Moisture",
        onBackTapped: {
            print("Back tapped")
        }
    )
}
