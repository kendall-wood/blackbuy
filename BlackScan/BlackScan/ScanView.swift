import SwiftUI

/// Main scanning view that integrates camera scanning, classification, and product search
/// Presents results in a bottom sheet with customizable detents
struct ScanView: View {
    
    // MARK: - State Properties
    
    @StateObject private var typesenseClient = TypesenseClient()
    @State private var isShowingResults = false
    @State private var scanResults: [ScoredProduct] = []
    @State private var lastClassification: ScanClassification?
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var isListening = false  // Shows user that camera is actively scanning
    
    // MARK: - UI Configuration
    
    private let resultSheetDetents: Set<PresentationDetent> = [
        .fraction(0.45),
        .large
    ]
    
    var body: some View {
        ZStack {
            // Live Camera Feed (same as CameraScanView)
            ScannerContainerView { recognizedText in
                handleRecognizedText(recognizedText)
            }
            .ignoresSafeArea()
            
            // Center Button UI
            VStack {
                Spacer()
                
                // Scan Button
                Button(action: handleButtonTap) {
                    HStack(spacing: 12) {
                        if isSearching || isListening {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        
                        Text(buttonText)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .frame(width: 280, height: 56)
                    .background(buttonBackgroundColor)
                    .foregroundColor(buttonTextColor)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 6)
                }
                .disabled(isSearching || isListening)
                
                Spacer()
                    .frame(height: 120) // Account for tab bar
            }
        }
        .sheet(isPresented: $isShowingResults) {
            resultsSheet
        }
    }
    
    // MARK: - Center Button UI
    
    private var centerButton: some View {
        VStack {
            Spacer()
            
            Button(action: handleButtonTap) {
                HStack(spacing: 12) {
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    
                    Text(buttonText)
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(width: 280, height: 56)
                .background(buttonBackgroundColor)
                .foregroundColor(buttonTextColor)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 6)
            }
            .disabled(isSearching)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Button State Computed Properties
    
    private var buttonText: String {
        if isSearching {
            return "Scanning"
        } else if !scanResults.isEmpty {
            return "See \(scanResults.count)+ Results"
        } else if isListening {
            return "Scanning"
        } else {
            return "Start Scanning"
        }
    }
    
    private var buttonBackgroundColor: Color {
        if isSearching {
            return .green
        } else if !scanResults.isEmpty {
            return .blue
        } else if isListening {
            return .green  // Green when actively listening for text
        } else {
            return .white
        }
    }
    
    private var buttonTextColor: Color {
        if isSearching {
            return .white
        } else if !scanResults.isEmpty {
            return .white
        } else if isListening {
            return .white
        } else {
            return .blue
        }
    }
    
    private func handleButtonTap() {
        if !scanResults.isEmpty {
            // Show results sheet
            isShowingResults = true
        } else if !isSearching && !isListening {
            // Start active scanning mode
            isListening = true
            
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Auto-stop after 10 seconds if no text detected
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                await MainActor.run {
                    if isListening && scanResults.isEmpty && !isSearching {
                        isListening = false
                    }
                }
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
                } else if scanResults.isEmpty {
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
        VStack(spacing: 12) {
            // Classification info
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let classification = lastClassification {
                        let productType = classification.productType.type
                        Text("Found: \(productType)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 4) {
                            Text("Black-owned products")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // Show confidence indicator
                            if !scanResults.isEmpty, let topResult = scanResults.first {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text("\(topResult.confidencePercentage)% match")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(confidenceColor(topResult.confidenceScore))
                            }
                        }
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
            
            if let classification = lastClassification {
                let productType = classification.productType.type
                Text("Looking for: \(productType)")
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
                if let lastClass = lastClassification {
                    performSearch(with: lastClass)
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
                // Results count with confidence info
                HStack {
                    Text("\(scanResults.count) products found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Show average confidence
                    if !scanResults.isEmpty {
                        let avgConfidence = scanResults.reduce(0.0) { $0 + $1.confidenceScore } / Double(scanResults.count)
                        Text("Avg: \(Int(avgConfidence * 100))% match")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(confidenceColor(avgConfidence))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Product grid with confidence scores
                ProductCard.createGrid {
                    ForEach(scanResults) { scanResult in
                        VStack(alignment: .leading, spacing: 8) {
                            ProductCard(
                                product: scanResult.product,
                                onBuyTapped: {
                                    openProductURL(scanResult.product.productUrl)
                                }
                            )
                            
                            // Confidence badge
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(confidenceColor(scanResult.confidenceScore))
                                    .frame(width: 6, height: 6)
                                
                                Text("\(scanResult.confidencePercentage)% match")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(confidenceColor(scanResult.confidenceScore))
                                
                                Spacer()
                                
                                // Match breakdown on tap
                                Button(action: {
                                    // TODO: Show match details sheet
                                }) {
                                    Text("Details")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 4)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Text Processing Methods
    
    /// Handles OCR text recognition from the camera scanner
    private func handleRecognizedText(_ recognizedText: String) {
        // Only process if we're in listening mode or already searching
        guard isListening || isSearching else {
            print("⏸️ Ignoring text - not in scanning mode")
            return
        }
        
        print("📸 Camera detected text: \(recognizedText.prefix(100))...")
        
        // Classify the recognized text using Advanced Classifier
        let classification = AdvancedClassifier.shared.classify(recognizedText)
        lastClassification = classification
        
        if Env.isDebugMode {
            print("🔍 OCR Text: \(recognizedText)")
            print("📋 Classification:")
            print("   Product Type: \(classification.productType.type)")
            print("   Form: \(classification.form?.form ?? "Unknown")")
            print("   Brand: \(classification.brand?.name ?? "None")")
            print("   Ingredients: \(classification.ingredients.joined(separator: ", "))")
            if let size = classification.size {
                print("   Size: \(size.value) \(size.unit)")
            }
        }
        
        // Perform search with classification result
        performSearch(with: classification)
    }
    
    /// Performs advanced product search with confidence scoring
    private func performSearch(with classification: ScanClassification) {
        // Don't search if no product type was detected
        guard !classification.productType.type.isEmpty else {
            if Env.isDebugMode {
                print("⚠️ Skipping search - no product type detected")
            }
            return
        }
        
        isSearching = true
        isListening = false  // Clear listening state when search starts
        searchError = nil
        
        Task {
            do {
                // Step 1: Get candidate products from Typesense (multi-pass search)
                let candidates = try await typesenseClient.searchForScanMatches(
                    classification: classification,
                    candidateCount: 100
                )
                
                if Env.isDebugMode {
                    print("🔍 Retrieved \(candidates.count) candidates from Typesense")
                }
                
                // Step 2: Score candidates locally with confidence scorer
                let scoredResults = ConfidenceScorer.shared.scoreProducts(
                    candidates: candidates,
                    classification: classification
                )
                
                // Step 3: Take top 20 results
                let topResults = Array(scoredResults.prefix(20))
                
                await MainActor.run {
                    isSearching = false
                    scanResults = topResults
                    
                    // Show results sheet if we found products
                    if !topResults.isEmpty {
                        isShowingResults = true
                    }
                    
                    if Env.isDebugMode {
                        print("✅ Search completed: \(topResults.count) products matched")
                        if let topMatch = topResults.first {
                            print("   Top match: \(topMatch.product.name) (\(topMatch.confidencePercentage)%)")
                            print("   Breakdown:")
                            print("     Product Type: \(topMatch.breakdown.productTypeScore)")
                            print("     Form: \(topMatch.breakdown.formScore)")
                            print("     Brand: \(topMatch.breakdown.brandScore)")
                            print("     Ingredients: \(topMatch.breakdown.ingredientScore)")
                            print("     Size: \(topMatch.breakdown.sizeScore)")
                        }
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
    
    /// Get color for confidence level
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
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
