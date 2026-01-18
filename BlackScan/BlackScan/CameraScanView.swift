import SwiftUI

/// Main camera scanning view - matches screenshots 6 & 7 exactly
struct CameraScanView: View {
    
    @StateObject private var typesenseClient = TypesenseClient()
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
    @State private var isShowingResults = false
    @State private var searchResults: [Product] = []
    @State private var lastClassificationResult: Classifier.ClassificationResult?
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var flashlightOn = false
    @State private var showingProfile = false
    @State private var showingSaved = false
    @State private var showingShop = false
    @State private var showingScanHistory = false
    
    var body: some View {
        ZStack {
            // Live Camera Feed
            ScannerContainerView { recognizedText in
                handleRecognizedText(recognizedText)
            }
            .ignoresSafeArea()
            
            // BlackScan Logo & Instructions Overlay (centered top area)
            VStack {
                Spacer()
                    .frame(height: 140)
                
                VStack(spacing: 12) {
                    // Logo - use SVG asset
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                    
                    // Instructions
                    Text("Find nearby text or barcodes.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white)
                    
                    Text("blackscan")
                        .font(.system(size: 44, weight: .thin))
                        .foregroundColor(.white)
                        .tracking(2)
                    
                    Text("Scan any product to")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                    + Text("\nfind your black-owned option")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                }
                .multilineTextAlignment(.center)
                
                Spacer()
            }
            
            // Top Corner Buttons (flashlight & profile)
            VStack {
                HStack {
                    // Flashlight Button - top left
                    Button(action: {
                        flashlightOn.toggle()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: flashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // Profile Button - top right
                    Button(action: {
                        showingProfile = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0, green: 0.48, blue: 1))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                
                Spacer()
            }
            
            // Large Blue "View Products" Button (appears when scan finds results)
            if !searchResults.isEmpty && !isShowingResults {
                VStack {
                    Spacer()
                    
                    Button(action: {
                        isShowingResults = true
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("View \(searchResults.count)+ Products")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                
                                if let result = lastClassificationResult {
                                    Text("Black-owned \(result.productType)")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .frame(height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(red: 0, green: 0.48, blue: 1))
                        )
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 140)
                }
            }
            
            // Bottom Navigation Icons
            VStack {
                Spacer()
                
                HStack(spacing: 60) {
                    // Scan History Button
                    Button(action: {
                        showingScanHistory = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "clock.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                        }
                    }
                    
                    // Saved Button
                    Button(action: {
                        showingSaved = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "heart.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                        }
                    }
                    
                    // Shop Button
                    Button(action: {
                        showingShop = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "storefront.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
        // Scan Results Bottom Sheet
        .sheet(isPresented: $isShowingResults) {
            ScanResultsSheet(
                results: searchResults,
                classification: lastClassificationResult,
                isSearching: isSearching,
                searchError: searchError,
                onRescan: {
                    isShowingResults = false
                    searchResults = []
                }
            )
        }
        // Profile Modal
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        // Saved Modal
        .fullScreenCover(isPresented: $showingSaved) {
            SavedView()
        }
        // Shop Modal
        .fullScreenCover(isPresented: $showingShop) {
            ShopView()
        }
        // Scan History Modal
        .fullScreenCover(isPresented: $showingScanHistory) {
            ScanHistoryView()
        }
    }
    
    // MARK: - Scanning Logic
    
    private func handleRecognizedText(_ recognizedText: String) {
        let classificationResult = Classifier.classify(recognizedText)
        lastClassificationResult = classificationResult
        
        if Env.isDebugMode {
            print("🔍 Recognized: \(recognizedText)")
            print("📋 Classified as: \(classificationResult.productType) (\(classificationResult.confidence))")
        }
        
        // Only search if confidence is reasonable
        guard classificationResult.confidence >= 0.2 else { return }
        
        performSearch(with: classificationResult)
    }
    
    private func performSearch(with result: Classifier.ClassificationResult) {
        guard !isSearching else { return }
        
        isSearching = true
        searchError = nil
        
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: result.productType,
                    page: 1,
                    perPage: 50
                )
                
                await MainActor.run {
                    isSearching = false
                    searchResults = products
                    if !products.isEmpty {
                        isShowingResults = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    searchError = error.localizedDescription
                }
            }
        }
    }
}

/// Bottom sheet showing scan results
struct ScanResultsSheet: View {
    let results: [Product]
    let classification: Classifier.ClassificationResult?
    let isSearching: Bool
    let searchError: String?
    let onRescan: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var savedProductsManager: SavedProductsManager
    @EnvironmentObject var cartManager: CartManager
    
    @State private var selectedProduct: Product?
    @StateObject private var typesenseClient = TypesenseClient()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with classification info
                    if let classification = classification {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Black-owned \(classification.productType)")
                                .font(.system(size: 24, weight: .bold))
                            
                            Text("\(results.count) products found")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    // Products Grid (2 columns with numbers)
                    let columns = [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, product in
                            ProductCardWithNumber(
                                product: product,
                                number: index + 1,
                                isSaved: savedProductsManager.isProductSaved(product),
                                onSaveTapped: {
                                    savedProductsManager.toggleSaveProduct(product)
                                },
                                onAddToCart: {
                                    cartManager.addToCart(product)
                                },
                                onCardTapped: {
                                    selectedProduct = product
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Rescan") {
                        onRescan()
                        dismiss()
                    }
                }
                
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
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
                .environmentObject(typesenseClient)
        }
    }
}

/// Product card with number badge (for scan results)
struct ProductCardWithNumber: View {
    let product: Product
    let number: Int
    let isSaved: Bool
    let onSaveTapped: () -> Void
    let onAddToCart: () -> Void
    let onCardTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Product Image with number badge
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: product.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemGray6)
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(height: 180)
                .clipped()
                
                // Number Badge
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color(red: 0, green: 0.48, blue: 1))
                    .clipShape(Circle())
                    .padding(10)
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(product.company)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(product.formattedPrice)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: onSaveTapped) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isSaved ? .red : .gray)
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onTapGesture {
            onCardTapped()
        }
    }
}

#Preview {
    CameraScanView()
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
}
