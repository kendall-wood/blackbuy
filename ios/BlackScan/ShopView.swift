import SwiftUI

/// Shop view with search functionality and product grid
/// Allows users to browse and search Black-owned products manually
struct ShopView: View {
    
    // MARK: - State Properties
    
    @StateObject private var typesenseClient = TypesenseClient()
    @State private var searchText = ""
    @State private var searchResults: [Product] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var hasSearched = false
    
    // Debouncing
    @State private var searchWorkItem: DispatchWorkItem?
    
    // MARK: - UI Configuration
    
    private let searchDebounceDelay = Env.searchDebounceDelay
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Content Area
                if isSearching {
                    searchingContent
                } else if let error = searchError {
                    errorContent(error)
                } else if !hasSearched {
                    welcomeContent
                } else if searchResults.isEmpty {
                    emptyResultsContent
                } else {
                    successResultsContent
                }
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Load featured products on first appearance if no search has been made
            if !hasSearched && searchResults.isEmpty {
                loadFeaturedProducts()
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Search Icon
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                // Search TextField
                TextField("Search for brands, products, or categories", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { newValue in
                        handleSearchTextChange(newValue)
                    }
                
                // Clear Button
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Content Views
    
    private var welcomeContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome Header
                VStack(spacing: 12) {
                    Image(systemName: "storefront")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                    
                    Text("Discover Black-Owned Products")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("Search for your favorite brands, product types, or browse our curated collection of Black-owned beauty and care products.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 40)
                
                // Quick Search Suggestions
                quickSearchSuggestions
                
                Spacer(minLength: 40)
            }
        }
    }
    
    private var quickSearchSuggestions: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Popular Searches")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140), spacing: 12)
            ], spacing: 12) {
                ForEach(popularSearchTerms, id: \.self) { term in
                    Button(action: {
                        searchText = term
                        performSearch()
                    }) {
                        Text(term)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var searchingContent: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching products...")
                .font(.headline)
            
            Text("Looking for: \(searchText)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorContent(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Search Error")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button("Try Again") {
                performSearch()
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyResultsContent: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Products Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("We couldn't find any products matching '\(searchText)'. Try different keywords or browse our popular categories.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // Suggest popular searches
            VStack(spacing: 12) {
                Text("Try searching for:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100), spacing: 8)
                ], spacing: 8) {
                    ForEach(popularSearchTerms.prefix(6), id: \.self) { term in
                        Button(term) {
                            searchText = term
                            performSearch()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var successResultsContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Results header
                HStack {
                    Text("\(searchResults.count) products found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Future: Add sort/filter buttons here
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Product grid
                ProductCard.createGrid {
                    ForEach(searchResults) { product in
                        ProductCard(
                            product: product,
                            onBuyTapped: {
                                openProductURL(product.productUrl)
                            }
                        )
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Search Methods
    
    private func handleSearchTextChange(_ newValue: String) {
        // Cancel previous search
        searchWorkItem?.cancel()
        
        // Create new search work item
        let workItem = DispatchWorkItem {
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                performSearch()
            }
        }
        
        searchWorkItem = workItem
        
        // Execute search after debounce delay
        DispatchQueue.main.asyncAfter(deadline: .now() + searchDebounceDelay, execute: workItem)
    }
    
    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else {
            searchResults = []
            hasSearched = false
            return
        }
        
        isSearching = true
        searchError = nil
        hasSearched = true
        
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: query,
                    page: 1,
                    perPage: 50
                )
                
                await MainActor.run {
                    isSearching = false
                    searchResults = products
                    
                    if Env.isDebugMode {
                        print("🛍️ Shop search completed: \(products.count) products found for '\(query)'")
                    }
                }
                
            } catch {
                await MainActor.run {
                    isSearching = false
                    searchError = error.localizedDescription
                    
                    if Env.isDebugMode {
                        print("❌ Shop search error: \(error)")
                    }
                }
            }
        }
    }
    
    private func clearSearch() {
        searchText = ""
        searchResults = []
        searchError = nil
        hasSearched = false
        searchWorkItem?.cancel()
    }
    
    private func loadFeaturedProducts() {
        // Load popular/featured products for browsing
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: "*", // Wildcard search for all products
                    page: 1,
                    perPage: 20
                )
                
                await MainActor.run {
                    searchResults = products
                    hasSearched = true
                    
                    if Env.isDebugMode {
                        print("✨ Loaded \(products.count) featured products")
                    }
                }
                
            } catch {
                if Env.isDebugMode {
                    print("⚠️ Failed to load featured products: \(error)")
                }
            }
        }
    }
    
    /// Opens product URL in external browser
    private func openProductURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            if Env.isDebugMode {
                print("⚠️ Invalid product URL: \(urlString)")
            }
            return
        }
        
        UIApplication.shared.open(url)
    }
    
    // MARK: - Constants
    
    private let popularSearchTerms = [
        "Shampoo",
        "Conditioner",
        "Curl Cream",
        "Edge Control",
        "Hair Oil",
        "SheaMoisture",
        "Cantu",
        "Pattern",
        "Mielle",
        "Carol's Daughter",
        "Leave-In",
        "Deep Conditioner"
    ]
}

// MARK: - Preview

#Preview("Shop View") {
    ShopView()
}

#Preview("Shop View - Dark") {
    ShopView()
        .preferredColorScheme(.dark)
}
