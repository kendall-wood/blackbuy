import SwiftUI

/// Main scanning view that integrates camera scanning, classification, and product search
/// Presents results in a bottom sheet with customizable detents
struct ScanView: View {
    
    // MARK: - State Properties
    
    @StateObject private var typesenseClient = TypesenseClient()
    @State private var isShowingResults = false
    @State private var searchResults: [Product] = []
    @State private var lastClassificationResult: Classifier.ClassificationResult?
    @State private var isSearching = false
    @State private var searchError: String?
    
    // MARK: - UI Configuration
    
    private let resultSheetDetents: Set<PresentationDetent> = [
        .fraction(0.45),
        .large
    ]
    
    var body: some View {
        ZStack {
            // Camera Scanner Background
            ScannerContainerView { recognizedText in
                handleRecognizedText(recognizedText)
            }
            .ignoresSafeArea(.all)
            
            // Scanning Overlay UI
            scanningOverlay
        }
        .sheet(isPresented: $isShowingResults) {
            resultsSheet
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Overlay UI
    
    private var scanningOverlay: some View {
        VStack {
            // Top instruction area
            VStack(spacing: 8) {
                Text("Point camera at product")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("Text and barcodes will be scanned automatically")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .padding(.top, 60) // Account for status bar
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Bottom status area
            if isSearching {
                searchingIndicator
                    .padding(.bottom, 100)
            } else if let lastResult = lastClassificationResult {
                lastSearchStatus(lastResult)
                    .padding(.bottom, 100)
            }
        }
    }
    
    private var searchingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("Searching for products...")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func lastSearchStatus(_ result: Classifier.ClassificationResult) -> some View {
        VStack(spacing: 4) {
            Text("Found: \(result.productType)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            if searchResults.count > 0 {
                Text("\(searchResults.count) Black-owned products")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.ultraThinMaterial)
        )
        .onTapGesture {
            if !searchResults.isEmpty {
                isShowingResults = true
            }
        }
    }
    
    // MARK: - Results Sheet
    
    private var resultsSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sheet Header
                sheetHeader
                
                // Results Content
                if isSearching {
                    searchingContent
                } else if let error = searchError {
                    errorContent(error)
                } else if searchResults.isEmpty {
                    emptyResultsContent
                } else {
                    successResultsContent
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDetents(resultSheetDetents)
        .presentationDragIndicator(.visible)
    }
    
    private var sheetHeader: some View {
        VStack(spacing: 8) {
            // Drag indicator (iOS will show this automatically, but we add visual context)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let lastResult = lastClassificationResult {
                        Text("Found: \(lastResult.productType)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Black-owned products")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Search Results")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
                
                Button("Done") {
                    isShowingResults = false
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
    
    private var searchingContent: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching for Black-owned products...")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if let result = lastClassificationResult {
                Text("Looking for: \(result.productType)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
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
                .padding(.horizontal)
            
            Button("Try Again") {
                if let lastResult = lastClassificationResult {
                    performSearch(with: lastResult)
                }
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
            
            Text("We couldn't find any Black-owned products matching your scan. Try scanning different text or search manually in the Shop tab.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var successResultsContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Results count
                HStack {
                    Text("\(searchResults.count) products found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
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
    
    // MARK: - Text Processing Methods
    
    /// Handles OCR text recognition from the camera scanner
    private func handleRecognizedText(_ recognizedText: String) {
        // Classify the recognized text
        let classificationResult = Classifier.classify(recognizedText)
        lastClassificationResult = classificationResult
        
        if Env.isDebugMode {
            print("🔍 OCR Text: \(recognizedText)")
            print("📋 Classification: \(classificationResult.productType) (confidence: \(classificationResult.confidence))")
            print("🔎 Search Query: \(classificationResult.queryString)")
        }
        
        // Perform search with classification result
        performSearch(with: classificationResult)
    }
    
    /// Performs product search using classification result
    private func performSearch(with result: Classifier.ClassificationResult) {
        // Don't search for very low confidence results
        guard result.confidence >= 0.2 else {
            if Env.isDebugMode {
                print("⚠️ Skipping search due to low confidence: \(result.confidence)")
            }
            return
        }
        
        isSearching = true
        searchError = nil
        
        Task {
            do {
                let products = try await typesenseClient.searchProducts(
                    query: result.queryString,
                    page: 1,
                    perPage: 20
                )
                
                await MainActor.run {
                    isSearching = false
                    searchResults = products
                    
                    // Show results sheet if we found products
                    if !products.isEmpty {
                        isShowingResults = true
                    }
                    
                    if Env.isDebugMode {
                        print("✅ Search completed: \(products.count) products found")
                    }
                }
                
            } catch {
                await MainActor.run {
                    isSearching = false
                    searchError = error.localizedDescription
                    
                    if Env.isDebugMode {
                        print("❌ Search error: \(error)")
                    }
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
}

// MARK: - Preview

#Preview("Scan View") {
    ScanView()
        .preferredColorScheme(.dark)
}

#Preview("Scan View - Light") {
    ScanView()
        .preferredColorScheme(.light)
}
