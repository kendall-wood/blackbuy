import SwiftUI

/// Main camera scanning view (legacy VisionKit-based scanner)
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
    
    var body: some View {
        ZStack {
            // Live Camera Feed
            ScannerContainerView { recognizedText in
                handleRecognizedText(recognizedText)
            }
            .ignoresSafeArea()
            
            // BlackScan Logo & Instructions Overlay
            VStack {
                Spacer()
                    .frame(height: 80)
                
                VStack(spacing: 8) {
                    Text("blackscan")
                        .font(.system(size: 32, weight: .thin))
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
            
            // Top Corner Button (flashlight)
            VStack {
                HStack {
                    Button(action: { flashlightOn.toggle() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: flashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.system(size: 22))
                                .foregroundColor(DS.brandBlue)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.top, 50)
                    
                    Spacer()
                }
                
                Spacer()
            }
            
            // Large Blue "View Products" Button
            if !searchResults.isEmpty && !isShowingResults {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            searchResults = []
                            lastClassificationResult = nil
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Scan Again")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundColor(DS.brandBlue)
                            .frame(width: 200, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: DS.radiusPill)
                                    .fill(Color.white)
                            )
                        }
                        
                        Button(action: { isShowingResults = true }) {
                            HStack(spacing: 16) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("View \(searchResults.count)+ Products")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    if let result = lastClassificationResult {
                                        Text("Black-owned \(result.productType)")
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, DS.horizontalPadding)
                            .frame(height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(DS.brandGradient)
                            )
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 160)
                }
            }
        }
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
    }
    
    // MARK: - Scanning Logic
    
    private func handleRecognizedText(_ recognizedText: String) {
        let classificationResult = Classifier.classify(recognizedText)
        lastClassificationResult = classificationResult
        
        if Env.isDebugMode {
            Log.debug("Recognized text from scan", category: .scan)
            Log.debug("Classified as: \(classificationResult.productType) (\(classificationResult.confidence))", category: .scan)
        }
        
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
    @EnvironmentObject var toastManager: ToastManager
    
    @State private var selectedProduct: Product?
    @StateObject private var typesenseClient = TypesenseClient()
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with classification info
                    if let classification = classification {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Black-owned \(classification.productType)")
                                .font(DS.pageTitle)
                            
                            Text("\(results.count) products found")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    // Products Grid using UnifiedProductCard
                    LazyVGrid(columns: UnifiedProductCard.gridColumns, spacing: DS.gridSpacing) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, product in
                            UnifiedProductCard(
                                product: product,
                                isSaved: savedProductsManager.isProductSaved(product),
                                isInCart: cartManager.isInCart(product),
                                numberBadge: index + 1,
                                onCardTapped: { selectedProduct = product },
                                onSaveTapped: {
                                    if savedProductsManager.isProductSaved(product) {
                                        savedProductsManager.removeSavedProduct(product)
                                        toastManager.show(.unsaved)
                                    } else {
                                        savedProductsManager.saveProduct(product)
                                        toastManager.show(.saved)
                                    }
                                },
                                onAddToCart: {
                                    if cartManager.isInCart(product) {
                                        cartManager.removeFromCart(product)
                                        toastManager.show(.removedFromCheckout)
                                    } else {
                                        cartManager.addToCart(product)
                                        toastManager.show(.addedToCheckout)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(DS.cardBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Rescan") {
                        onRescan()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
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

#Preview {
    CameraScanView()
        .environmentObject(SavedProductsManager())
        .environmentObject(CartManager())
}
