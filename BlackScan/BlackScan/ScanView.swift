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
    @State private var flashlightOn = false
    
    // MARK: - UI Configuration
    
    private let resultSheetDetents: Set<PresentationDetent> = [
        .fraction(0.45),
        .large
    ]
    
    var body: some View {
        ZStack {
            // Live Camera Feed with flashlight control - only active when listening
            // Increased debounce to 3.0s for better text capture
            ScannerContainerView(isTorchOn: $flashlightOn, isActive: $isListening, debounceDelay: 3.0) { recognizedText in
                handleRecognizedText(recognizedText)
            }
            .ignoresSafeArea()
            
            // Flashlight Button - top left
            VStack {
                HStack {
                    Button(action: {
                        flashlightOn.toggle()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: flashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color(red: 0.26, green: 0.63, blue: 0.95))
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.top, 50)
                    
                    Spacer()
                }
                
                Spacer()
            }
            
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
        print("🔘 Button tapped! Current state - isListening: \(isListening), isSearching: \(isSearching), results: \(scanResults.count)")
        
        if !scanResults.isEmpty {
            // Show results sheet
            print("📊 Showing results sheet with \(scanResults.count) results")
            isShowingResults = true
        } else if !isSearching && !isListening {
            // Start active scanning mode
            print("🟢 Starting active scanning mode...")
            isListening = true
            
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            print("⏱️ Scanning timeout set for 10 seconds")
            
            // Auto-stop after 15 seconds if no text detected (increased from 10s)
            Task {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                await MainActor.run {
                    if isListening && scanResults.isEmpty && !isSearching {
                        print("⏰ Scanning timeout reached - stopping")
                        isListening = false
                    }
                }
            }
        } else {
            print("⚠️ Button tap ignored - already scanning or searching")
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
            VStack(spacing: 0) {
                // Results count with confidence info
                HStack {
                    Text("Showing \(scanResults.count) of \(scanResults.count) products")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Show average confidence
                    if !scanResults.isEmpty {
                        let avgConfidence = scanResults.reduce(0.0) { $0 + $1.confidenceScore } / Double(scanResults.count)
                        Text("Avg: \(Int(avgConfidence * 100))% match")
                            .font(.subheadline)
                            .foregroundColor(confidenceColor(avgConfidence))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Clean product grid - just like shop view
                ProductCard.createGrid {
                    ForEach(scanResults) { scanResult in
                        ProductCard(
                            product: scanResult.product,
                            onBuyTapped: {
                                openProductURL(scanResult.product.productUrl)
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
        print("📥 handleRecognizedText called! Text length: \(recognizedText.count), isListening: \(isListening), isSearching: \(isSearching)")
        
        // Only process if we're in listening mode or already searching
        guard isListening || isSearching else {
            print("⏸️ Ignoring text - not in scanning mode (isListening: \(isListening), isSearching: \(isSearching))")
            return
        }
        
        // Require minimum text length for quality scan
        guard recognizedText.count >= 50 else {
            print("⚠️ Text too short (\(recognizedText.count) chars) - need at least 50 chars for accurate classification")
            isListening = false  // Stop listening, let user try again
            return
        }
        
        print("📸 Camera detected text: \(recognizedText.prefix(100))...")
        
        // Classify the recognized text using Advanced Classifier
        let classification = AdvancedClassifier.shared.classify(recognizedText)
        lastClassification = classification
        
        // ALWAYS log classification results for debugging
        print("🔍 OCR Text: \(recognizedText)")
        print("📋 Classification:")
        print("   Product Type: '\(classification.productType.type)' (confidence: \(classification.productType.confidence))")
        print("   Form: \(classification.form?.form ?? "Unknown")")
        print("   Brand: \(classification.brand?.name ?? "None")")
        print("   Ingredients: \(classification.ingredients.joined(separator: ", "))")
        if let size = classification.size {
            print("   Size: \(size.value) \(size.unit)")
        }
        
        // Reject low confidence classifications
        guard classification.productType.confidence >= 0.5 else {
            print("⚠️ Classification confidence too low (\(classification.productType.confidence)) - need at least 0.5")
            isListening = false  // Stop listening, let user try again
            return
        }
        
        // Perform search with classification result
        performSearch(with: classification)
    }
    
    /// Performs advanced product search with confidence scoring
    private func performSearch(with classification: ScanClassification) {
        // Don't search if no product type was detected
        guard !classification.productType.type.isEmpty else {
            print("⚠️ Skipping search - no product type detected")
            print("   Raw text was: \(classification.productType.type)")
            
            // Reset state so user can try again
            isListening = false
            searchError = "Could not identify product type. Please try scanning clearer text."
            return
        }
        
        print("✅ Starting search with product type: \(classification.productType.type)")
        
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
                
                if Env.isDebugMode {
                    print("📊 Score Distribution:")
                    for (index, result) in scoredResults.prefix(10).enumerated() {
                        print("   \(index + 1). \(result.product.name.prefix(50))")
                        print("      Total: \(result.confidencePercentage)%")
                        print("      Product Type: \(Int(result.breakdown.productTypeScore * 100))%")
                        print("      Form: \(Int(result.breakdown.formScore * 100))%")
                        print("      Brand: \(Int(result.breakdown.brandScore * 100))%")
                        print("      Ingredients: \(Int(result.breakdown.ingredientScore * 100))%")
                        print("      Size: \(Int(result.breakdown.sizeScore * 100))%")
                    }
                }
                
                // Step 3: Filter by minimum confidence (85% for now) and take top 20
                let minConfidence = 0.85
                let qualityResults = scoredResults.filter { $0.confidenceScore >= minConfidence }
                let topResults = Array(qualityResults.prefix(20))
                
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
