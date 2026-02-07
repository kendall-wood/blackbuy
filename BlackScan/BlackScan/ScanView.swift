import SwiftUI
import AVFoundation

/// Main scanning view using OpenAI GPT-4 Vision for product recognition
/// Captures image → AI analysis → Search → Results
struct ScanView: View {
    
    // MARK: - State Properties
    
    @Binding var selectedTab: AppTab
    @Binding var pendingShopSearch: String?
    @StateObject private var typesenseClient = TypesenseClient()
    @EnvironmentObject var cartManager: CartManager
    @State private var isShowingResults = false
    @State private var scanResults: [ScoredProduct] = []
    @State private var lastAnalysis: HybridScanService.ProductAnalysis?
    @State private var lastScanMethod: HybridScanService.ScanMethod?
    @State private var lastScanCost: Double = 0.0
    @State private var searchError: String?
    @State private var flashlightOn = false
    @State private var capturedImage: UIImage?
    @State private var shouldCapturePhoto = false
    @State private var selectedDetailProduct: Product?
    @State private var showingScanHistory = false
    
    // Default initializer for binding
    init(selectedTab: Binding<AppTab> = .constant(.scan), pendingShopSearch: Binding<String?> = .constant(nil)) {
        self._selectedTab = selectedTab
        self._pendingShopSearch = pendingShopSearch
    }
    
    // Scanning states for button UI
    enum ScanState {
        case initial        // "Start Scanning" - white button, blue text
        case capturing      // "Capturing..." - green button, white text
        case analyzing      // "Analyzing..." - green button, white text
        case searching      // "Searching..." - green button, white text
        case results        // "See X+ Results" - blue button, white text
    }
    
    @State private var scanState: ScanState = .initial
    
    // MARK: - UI Configuration
    
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Live Camera Feed
                CameraPreviewView(
                    flashlightOn: $flashlightOn,
                    capturedImage: $capturedImage,
                    shouldCapturePhoto: $shouldCapturePhoto
                )
                .ignoresSafeArea()
                
                // Top Left - Flashlight Button
                VStack {
                    HStack {
                        Button(action: {
                            flashlightOn.toggle()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 58, height: 58)
                                    .dsButtonShadow()
                                
                                Image(systemName: flashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(DS.brandBlue)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 20)
                        .padding(.top, 40)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
                
                // Top Right - Profile Button
                VStack {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            selectedTab = .profile
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 58, height: 58)
                                    .dsButtonShadow()
                                
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(DS.brandBlue)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .padding(.top, 40)
                    }
                    
                    Spacer()
                }
                
                // Top Center - Logo and Subtitle
                VStack(spacing: 24) {
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 24)
                        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 2)
                    
                    Text("Scan any product to\nfind your black-owned option")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 1)
                    
                    Spacer()
                }
                .padding(.top, 52)
                
                // Center - Scan Button + Inline Results
                VStack(spacing: 10) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.45)
                    
                    Button(action: handleButtonTap) {
                        HStack(spacing: 10) {
                            if scanState == .capturing || scanState == .analyzing || scanState == .searching {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: DS.brandBlue))
                            } else {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 18))
                                    .foregroundColor(DS.brandBlue)
                            }
                            
                            Text(scanButtonText)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(DS.brandBlue)
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(DS.radiusPill)
                        .dsButtonShadow()
                    }
                    .buttonStyle(.plain)
                    .disabled(scanState == .capturing || scanState == .analyzing || scanState == .searching)
                    
                    Text("Shake to report issue")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.systemGray))
                    
                    // View Products button (appears after scan)
                    if scanState == .results && !scanResults.isEmpty {
                        Button(action: {
                            isShowingResults = true
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("View \(scanResults.count)+ Products")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    if let productType = lastAnalysis?.productType {
                                        Text("Black-owned \(productType)")
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 16)
                            .background(DS.brandGradient)
                            .cornerRadius(DS.radiusPill)
                            .dsButtonShadow()
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                        .transition(.opacity)
                    }
                    
                    // No results found - grey button to shop
                    if scanState == .results && scanResults.isEmpty {
                        Button(action: {
                            scanState = .initial
                            selectedTab = .shop
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("No products found")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text("Search the shop")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray))
                            .cornerRadius(DS.radiusPill)
                            .dsButtonShadow()
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                        .transition(.opacity)
                    }
                    
                    Spacer()
                }
                
                // Bottom Left - History Button
                VStack {
                    Spacer()
                    
                    HStack {
                        Button(action: { showingScanHistory = true }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 58, height: 58)
                                    .dsButtonShadow()
                                
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 22))
                                    .foregroundColor(DS.brandBlue)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 20)
                        .padding(.bottom, 80)
                        
                        Spacer()
                    }
                }
                
                // Bottom Right - Heart, Cart, and Shop Buttons
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 18) {
                            // Checkout Manager (aligned right edge with shop button)
                            Button(action: { selectedTab = .checkout }) {
                                ZStack(alignment: .topTrailing) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 58, height: 58)
                                            .dsButtonShadow()
                                        
                                        Image("cart_icon")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 28, height: 28)
                                            .foregroundColor(DS.brandBlue)
                                    }
                                    
                                    // Quantity badge
                                    if cartManager.totalItemCount > 0 {
                                        Text("\(cartManager.totalItemCount)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(minWidth: 20, minHeight: 20)
                                            .background(DS.brandBlue)
                                            .clipShape(Circle())
                                            .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            
                            // Heart and Shop row
                            HStack(spacing: 18) {
                                Button(action: { selectedTab = .saved }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 58, height: 58)
                                            .dsButtonShadow()
                                        
                                        Image(systemName: "heart")
                                            .font(.system(size: 22))
                                            .foregroundColor(DS.brandBlue)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { selectedTab = .shop }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 58, height: 58)
                                            .dsButtonShadow()
                                        
                                        Image(systemName: "storefront")
                                            .font(.system(size: 22))
                                            .foregroundColor(DS.brandBlue)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.bottom, 80)
                }
                
                
            }
        }
        .sheet(isPresented: $isShowingResults) {
            resultsSheet
        }
        .fullScreenCover(isPresented: $showingScanHistory) {
            RecentScansView(onSearchInShop: { query in
                showingScanHistory = false
                pendingShopSearch = query
                selectedTab = .shop
            })
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                handleCapturedImage(image)
            }
        }
    }
    
    // MARK: - Button State Computed Properties
    
    private var scanButtonText: String {
        switch scanState {
        case .initial:
            return "Start Scanning"
        case .capturing:
            return "Scanning..."
        case .analyzing:
            return "Scanning..."
        case .searching:
            return "Scanning..."
        case .results:
            return "Scan Again"
        }
    }
    
    private var buttonText: String {
        switch scanState {
        case .initial:
            return "Start Scanning"
        case .capturing:
            return "Scanning..."
        case .analyzing:
            return "Scanning..."
        case .searching:
            return "Scanning..."
        case .results:
            let count = scanResults.count
            if let productType = lastAnalysis?.productType {
                return "Found \(count) \(productType) Result\(count == 1 ? "" : "s")"
            } else {
                return "Found \(count) Result\(count == 1 ? "" : "s")"
            }
        }
    }
    
    private var buttonBackgroundColor: Color {
        switch scanState {
        case .initial:
            return .white
        case .capturing, .analyzing, .searching:
            return .green
        case .results:
            return DS.brandBlue // Blue
        }
    }
    
    private var buttonTextColor: Color {
        switch scanState {
        case .initial:
            return DS.brandBlue // Blue
        case .capturing, .analyzing, .searching, .results:
            return .white
        }
    }
    
    // MARK: - Button Action
    
    private func handleButtonTap() {
        print("🔘 Scan button tapped! Current state: \(scanState)")
        
        if scanState == .results {
            // Reset to scan again
            print("🔄 Resetting to scan again...")
            scanState = .initial
            scanResults = []
            lastAnalysis = nil
            capturedImage = nil
        } else if scanState == .initial {
            // Trigger image capture
            print("📸 Triggering image capture...")
            scanState = .capturing
            
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Trigger photo capture
            shouldCapturePhoto = true
        }
    }
    
    // MARK: - Image Processing Pipeline
    
    private func handleCapturedImage(_ image: UIImage) {
        print("📸 Image captured! Size: \(image.size)")
        
        Task {
            await analyzeAndSearch(image: image)
        }
    }
    
    private func analyzeAndSearch(image: UIImage) async {
        // Step 1: Analyze with OpenAI Vision
        await MainActor.run {
            scanState = .analyzing
        }
        
        print("🤖 Starting Hybrid Scan (OCR+Text or Vision)...")
        
        do {
            let scanResult = try await HybridScanService.shared.analyzeProduct(image: image)
            
            print("✅ Analysis complete!")
            print("   Method: \(scanResult.method.displayName)")
            print("   Cost: ~$\(String(format: "%.4f", scanResult.cost))")
            print("   Time: \(String(format: "%.2f", scanResult.processingTime))s")
            print("   Product Type: \(scanResult.analysis.productType)")
            print("   Brand: \(scanResult.analysis.brand ?? "unknown")")
            print("   Form: \(scanResult.analysis.form ?? "unknown")")
            print("   Confidence: \(Int(scanResult.analysis.confidence * 100))%")
            
            await MainActor.run {
                lastAnalysis = scanResult.analysis
                lastScanMethod = scanResult.method
                lastScanCost = scanResult.cost
            }
            
            // Step 2: Search Typesense
            await searchForMatches(analysis: scanResult.analysis)
            
        } catch {
            print("❌ OpenAI Vision error: \(error.localizedDescription)")
            
            await MainActor.run {
                searchError = "Failed to analyze product: \(error.localizedDescription)"
                scanState = .initial
            }
        }
    }
    
    private func searchForMatches(analysis: HybridScanService.ProductAnalysis) async {
        await MainActor.run {
            scanState = .searching
        }
        
        print("🔍 Searching Typesense for: \(analysis.productType)")
        
        do {
            // Convert OpenAI analysis to ScanClassification format
            let classification = convertToScanClassification(analysis: analysis)
            
            // Use advanced multi-pass search (retrieves up to 150 candidates for better coverage)
            let results = try await typesenseClient.searchForScanMatches(
                classification: classification,
                candidateCount: 150
            )
            
            print("✅ Found \(results.count) candidate products from Typesense")
            
            // NAME IS PRIMARY GATE: Filter by name first, then use Typesense ranking
            let targetLower = analysis.productType.lowercased()
            let targetWords = Set(targetLower.split(separator: " ").map(String.init))
            
            // Also check tags for matches (e.g., "sanitizer" tag)
            let scoredResults = results.enumerated().compactMap { (index, product) -> ScoredProduct? in
                let nameLower = product.name.lowercased()
                let nameWords = Set(nameLower.split(separator: " ").map(String.init))
                let tagsLower = (product.tags?.joined(separator: " ") ?? "").lowercased()
                let productTypeLower = product.productType.lowercased()
                
                // GATE 1: Filter out accessories when scanning core products
                let accessoryKeywords = ["brush", "applicator", "sponge", "tool", "mirror", "bag", "case", "holder", "dispenser", "blender"]
                let isAccessory = accessoryKeywords.contains { nameLower.contains($0) || productTypeLower.contains($0) }
                let isConsumableProduct = !["accessory", "tool", "equipment"].contains(productTypeLower)
                
                if isAccessory && isConsumableProduct {
                    // User scanned a product (e.g., foundation), not an accessory (e.g., foundation brush)
                    if Env.isDebugMode {
                        print("   ❌ FILTERED OUT: '\(product.name)' - accessory mismatch")
                    }
                    return nil
                }
                
                // GATE 2: Filter out use-case mismatches (e.g., feminine wash != hand wash)
                let useCaseMismatches: [(scanned: [String], wrong: [String])] = [
                    (scanned: ["hand", "wash"], wrong: ["feminine", "vaginal", "intimate", "yoni"]),
                    (scanned: ["hand", "sanitizer"], wrong: ["feminine", "vaginal", "intimate"]),
                    (scanned: ["face", "facial"], wrong: ["vaginal", "intimate", "yoni"]),
                    (scanned: ["body", "lotion"], wrong: ["facial", "face"]),
                    (scanned: ["shampoo"], wrong: ["conditioner"]),
                    (scanned: ["conditioner"], wrong: ["shampoo"])
                ]
                
                for mismatch in useCaseMismatches {
                    let hasScannedWords = mismatch.scanned.allSatisfy { targetLower.contains($0) }
                    let hasWrongWords = mismatch.wrong.contains { nameLower.contains($0) || productTypeLower.contains($0) }
                    
                    if hasScannedWords && hasWrongWords {
                        if Env.isDebugMode {
                            print("   ❌ FILTERED OUT: '\(product.name)' - use-case mismatch")
                        }
                        return nil
                    }
                }
                
                // GATE 3: Filter out form type mismatches (e.g., towelettes != lotion)
                if let targetForm = analysis.form?.lowercased() {
                    let formMismatches: [String: [String]] = [
                        "towelette": ["lotion", "cream", "serum", "oil", "gel"],
                        "wipe": ["lotion", "cream", "serum", "oil", "gel"],
                        "serum": ["lotion", "cream", "conditioner", "mask"],
                        "powder": ["liquid", "cream", "gel", "lotion"],
                        "bar": ["liquid", "gel", "cream", "lotion"],
                        "spray": ["cream", "lotion", "gel", "bar"],
                        "foam": ["cream", "lotion", "gel", "bar"]
                    ]
                    
                    if let invalidForms = formMismatches[targetForm],
                       let productForm = product.form?.lowercased(),
                       invalidForms.contains(productForm) {
                        if Env.isDebugMode {
                            print("   ❌ FILTERED OUT: '\(product.name)' - form mismatch (\(targetForm) vs \(productForm))")
                        }
                        return nil
                    }
                }
                
                // GATE 4: Strict name matching (MUST have specific descriptor match)
                let nameScore: Double
                let overlap = targetWords.intersection(nameWords)
                
                // Specific product descriptor roots (handles plurals: "towelette" matches "towelettes")
                let specificDescriptors = ["sanitizer", "cleanser", "cleansing", "wash", "soap", "shampoo", "conditioner", 
                                          "lotion", "cream", "serum", "oil", "gel", "balm", "butter", 
                                          "mask", "scrub", "toner", "primer", "foundation", "concealer",
                                          "powder", "spray", "foam", "bar", "wipe", "towelette", "treatment",
                                          "moisturizer", "exfoliant"]
                
                // Find specific descriptors in target and product (check if word STARTS WITH descriptor)
                func findDescriptors(in words: Set<String>) -> Set<String> {
                    var found = Set<String>()
                    for word in words {
                        for descriptor in specificDescriptors {
                            if word.hasPrefix(descriptor) {
                                found.insert(descriptor)
                            }
                        }
                    }
                    return found
                }
                
                let targetSpecific = findDescriptors(in: targetWords)
                let productSpecific = findDescriptors(in: nameWords)
                let specificOverlap = targetSpecific.intersection(productSpecific)
                
                // CRITICAL: If target has specific descriptors, product MUST match at least one
                if !targetSpecific.isEmpty && specificOverlap.isEmpty {
                    // Target says "Facial Towelettes" but product is "Facial Wash"
                    // → "towelette" ≠ "wash" = MISMATCH
                    if Env.isDebugMode {
                        print("   ❌ FILTERED OUT: '\(product.name)' - specific descriptor mismatch (need: \(targetSpecific), has: \(productSpecific))")
                    }
                    return nil
                }
                
                // Now score based on how well they match
                if nameLower.contains(targetLower) {
                    // Perfect: name contains full target phrase ("Hand Sanitizer")
                    nameScore = 1.0
                } else if specificOverlap.count >= 2 {
                    // Excellent: Multiple specific descriptors match (e.g., "leave-in serum" → "hydrating leave-in serum")
                    nameScore = 0.95
                } else if specificOverlap.count == 1 {
                    // Good: The specific descriptor matches (e.g., "serum" in "leave-in serum")
                    if overlap.count >= targetWords.count - 1 {
                        // Most words match (e.g., "leave-in serum" → "leave-in treatment")
                        nameScore = 0.85
                    } else {
                        // Only the specific descriptor matches (e.g., "hand sanitizer" → "sanitizer")
                        nameScore = 0.70
                    }
                } else {
                    // No specific descriptors matched (should be rare due to gate above)
                    if overlap.count >= 2 {
                        nameScore = 0.60
                    } else if targetWords.contains(where: { tagsLower.contains($0) }) {
                        nameScore = 0.50
                    } else {
                        // Not enough match
                        if Env.isDebugMode {
                            print("   ❌ FILTERED OUT: '\(product.name)' - insufficient match")
                        }
                        return nil
                    }
                }
                
                // Typesense position score (primary ranking signal - now includes form!)
                let positionScore = 1.0 - (Double(index) / Double(results.count) * 0.20)
                
                // Form match bonus (explicit boost for matching forms)
                let formBonus: Double
                if let targetForm = analysis.form?.lowercased(),
                   let productForm = product.form?.lowercased() {
                    if targetForm == productForm {
                        formBonus = 0.10  // +10% for exact form match
                    } else if isFormCompatible(targetForm, productForm) {
                        formBonus = 0.05  // +5% for compatible forms
                    } else {
                        formBonus = 0.0   // No bonus for different forms
                    }
                } else {
                    formBonus = 0.0  // No bonus if form unknown
                }
                
                // Final score: 30% name + 70% position + form bonus
                let baseScore = (nameScore * 0.30) + (positionScore * 0.70)
                let finalScore = min(baseScore + formBonus, 1.0)  // Cap at 100%
                
                if Env.isDebugMode {
                    let formInfo = formBonus > 0 ? ", form: +\(Int(formBonus * 100))%" : ""
                    print("   ✅ #\(index + 1): \(product.name) = \(Int(finalScore * 100))% (name: \(Int(nameScore * 100))%, position: \(Int(positionScore * 100))%\(formInfo))")
                }
                
                return ScoredProduct(
                    id: product.id,
                    product: product,
                    confidenceScore: finalScore,
                    breakdown: ScoreBreakdown(
                        productTypeScore: nameScore,
                        formScore: formBonus > 0 ? 1.0 : 0.85,  // Show perfect form match
                        brandScore: 0.85,
                        ingredientScore: 0.85,
                        sizeScore: 0.85,
                        visualScore: 0.85
                    ),
                    explanation: formBonus > 0 ? "Name: \(Int(nameScore * 100))%, Position: \(Int(positionScore * 100))%, Form: +\(Int(formBonus * 100))%" : "Name: \(Int(nameScore * 100))%, Position: \(Int(positionScore * 100))%"
                )
            }
            
            // Sort by score and show top 20
            let filteredResults = Array(scoredResults.sorted { $0.confidenceScore > $1.confidenceScore }.prefix(20))
            
            print("📊 After name filter: \(scoredResults.count) products (filtered from \(results.count))")
            print("📊 Showing top \(filteredResults.count) results")
            
            if Env.isDebugMode && !filteredResults.isEmpty {
                print("🏆 Top 5 matches:")
                for (index, result) in filteredResults.prefix(5).enumerated() {
                    print("   \(index + 1). \(result.product.name) - \(result.confidencePercentage)%")
                }
            }
            
            await MainActor.run {
                scanResults = filteredResults
                scanState = .results
            }
            
        } catch {
            print("❌ Search error: \(error.localizedDescription)")
            
            await MainActor.run {
                searchError = "Search failed: \(error.localizedDescription)"
                scanState = .initial
            }
        }
    }
    
    // MARK: - Simple Accurate Scoring (Trust Typesense)
    
    /// Score products accurately based on what matters (no fake base scores)
    /// Philosophy: Typesense found them, so they're relevant. Just rank them honestly.
    private func scoreProductsSimple(
        products: [Product],
        targetType: String,
        targetForm: String?
    ) -> [ScoredProduct] {
        print("🎯 Scoring \(products.count) products with simple accurate method...")
        
        let scored = products.map { product -> ScoredProduct in
            var score: Double = 0.0
            
            let targetLower = targetType.lowercased()
            let nameLower = product.name.lowercased()
            
            // TIER 1: Product NAME match (60% weight)
            // Most reliable signal - if name says "Hand Sanitizer", it IS one
            let nameScore: Double
            if nameLower.contains(targetLower) {
                // Name contains full target
                nameScore = 1.0
                if Env.isDebugMode {
                    print("   ✅ NAME MATCH: '\(product.name)' contains '\(targetType)' = 100%")
                }
            } else {
                // Check word overlap
                let targetWords = Set(targetLower.split(separator: " ").map(String.init))
                let nameWords = Set(nameLower.split(separator: " ").map(String.init))
                let overlap = targetWords.intersection(nameWords)
                
                if overlap.count >= 2 {
                    // At least 2 words match (e.g., "Hand" + "Sanitizer")
                    nameScore = 0.80
                    if Env.isDebugMode {
                        print("   ✅ NAME PARTIAL: '\(product.name)' has \(overlap.count) words = 80%")
                    }
                } else if overlap.count == 1 {
                    // Only 1 word matches
                    nameScore = 0.40
                    if Env.isDebugMode {
                        print("   ⚠️ NAME WEAK: '\(product.name)' has 1 word = 40%")
                    }
                } else {
                    // No match - but Typesense found it, so give some credit
                    nameScore = 0.20
                    if Env.isDebugMode {
                        print("   ⚠️ NO NAME MATCH: '\(product.name)' = 20%")
                    }
                }
            }
            score += nameScore * 0.60
            
            // TIER 2: Form match (25% weight)
            let formScore: Double
            if let targetForm = targetForm, let productForm = product.form {
                let targetFormLower = targetForm.lowercased()
                let productFormLower = productForm.lowercased()
                
                if targetFormLower == productFormLower {
                    formScore = 1.0  // Perfect match
                } else if targetFormLower.contains(productFormLower) || productFormLower.contains(targetFormLower) {
                    formScore = 0.80  // Partial match (e.g., "gel" in "spray gel")
                } else if isFormCompatible(targetFormLower, productFormLower) {
                    formScore = 0.60  // Compatible (e.g., spray/mist)
                } else {
                    formScore = 0.30  // Different but not a dealbreaker
                }
            } else {
                formScore = 0.50  // Unknown form = neutral
            }
            score += formScore * 0.25
            
            // TIER 3: Typesense ranking (15% weight)
            // Higher in search results = more relevant
            // (We'd need search position for this, so approximate for now)
            let searchRankScore = 0.80  // Assume good if Typesense found it
            score += searchRankScore * 0.15
            
            // Final score
            if Env.isDebugMode {
                print("   📊 \(product.name): \(Int(score * 100))% (name:\(Int(nameScore * 100))% form:\(Int(formScore * 100))%)")
            }
            
            return ScoredProduct(
                id: product.id,
                product: product,
                confidenceScore: score,
                breakdown: ScoreBreakdown(
                    productTypeScore: nameScore,  // Use name score as "product type"
                    formScore: formScore,
                    brandScore: 0.80,  // Neutral
                    ingredientScore: 0.80,  // Neutral
                    sizeScore: 0.80,  // Neutral
                    visualScore: 0.80
                ),
                explanation: "Name: \(Int(nameScore * 100))%, Form: \(Int(formScore * 100))%"
            )
        }
        
        // Sort by score (highest first)
        return scored.sorted { $0.confidenceScore > $1.confidenceScore }
    }
    
    /// Check if two forms are compatible (e.g., spray/mist)
    private func isFormCompatible(_ form1: String, _ form2: String) -> Bool {
        let compatibleGroups: [[String]] = [
            ["spray", "mist", "spritz"],
            ["gel", "jelly", "gelly"],
            ["cream", "lotion", "butter"],
            ["oil", "serum"],
            ["foam", "mousse"],
            ["stick", "bar"]
        ]
        
        for group in compatibleGroups {
            if group.contains(form1) && group.contains(form2) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Conversion
    
    /// Convert Hybrid ProductAnalysis to ScanClassification
    private func convertToScanClassification(analysis: HybridScanService.ProductAnalysis) -> ScanClassification {
        // Create ProductTypeResult
        let productTypeResult = ProductTypeResult(
            type: analysis.productType,
            confidence: analysis.confidence,
            matchedKeywords: [], // OpenAI doesn't provide this
            category: nil, // Will be inferred
            subcategory: nil
        )
        
        // Create FormResult if form exists
        let formResult: FormResult? = analysis.form.map { formString in
            FormResult(
                form: formString,
                confidence: 0.9,
                source: .explicit
            )
        }
        
        // Create ScanClassification
        return ScanClassification(
            productType: productTypeResult,
            form: formResult,
            brand: nil, // We don't need brand matching for Black-owned alternatives
            ingredients: analysis.ingredients,
            ingredientClarity: analysis.ingredients.isEmpty ? 0.5 : 0.9,
            size: nil, // Size parsing can be added later
            rawText: analysis.rawText,
            processedText: analysis.rawText.lowercased(),
            timestamp: Date()
        )
    }
    
    // MARK: - Results Sheet
    
    private var resultsSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let analysis = lastAnalysis {
                            HStack(spacing: 0) {
                                Text("Found: ")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.black)
                                Text(analysis.productType)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            
                            if !scanResults.isEmpty, let topResult = scanResults.first {
                                Text("Confidence: \(String(format: "%.1f", topResult.confidenceScore * 100))%")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(confidenceColor(topResult.confidenceScore))
                            }
                            
                            Text("Black-owned alternatives to \(analysis.productType)")
                                .font(.system(size: 14))
                                .foregroundColor(Color(.systemGray))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                            
                            Text("Not what you were looking for?")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.top, 1)
                        } else {
                            Text("Search Results")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundColor(.black)
                        }
                    }
                    
                    Spacer(minLength: 12)
                    
                    Button(action: {
                        isShowingResults = false
                        scanState = .initial
                        scanResults = []
                        lastAnalysis = nil
                        capturedImage = nil
                        searchError = nil
                    }) {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DS.brandBlue)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(DS.radiusPill)
                            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.top, 32)
                .padding(.bottom, 16)
                
                Divider()
                
                if !scanResults.isEmpty {
                    HStack {
                        Text("Showing \(scanResults.count) products")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(.systemGray))
                        Spacer()
                    }
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }
                
                // Product grid
                ScrollView {
                    LazyVGrid(columns: UnifiedProductCard.gridColumns, spacing: DS.gridSpacing) {
                        ForEach(scanResults) { scoredProduct in
                            UnifiedProductCard(
                                product: scoredProduct.product,
                                showHeart: false,
                                onCardTapped: {
                                    selectedDetailProduct = scoredProduct.product
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.top, 12)
                    
                    // See all results in Shop
                    if let productType = lastAnalysis?.productType {
                        Button(action: {
                            isShowingResults = false
                            scanState = .initial
                            pendingShopSearch = productType
                            selectedTab = .shop
                        }) {
                            HStack(spacing: 6) {
                                Text("See all \(productType) results")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(DS.brandBlue)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DS.brandBlue)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(DS.radiusLarge)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DS.horizontalPadding)
                        .padding(.top, 20)
                    }
                    
                    Spacer().frame(height: 80)
                }
            }
            .background(DS.cardBackground)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $selectedDetailProduct) { product in
            ProductDetailView(product: product)
                .environmentObject(typesenseClient)
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.75 {
            return .green  // Excellent match (name + form match)
        } else if confidence >= 0.60 {
            return Color(red: 0.6, green: 0.8, blue: 0.4) // light green for decent match // Light green (name match, form mismatch)
        } else if confidence >= 0.45 {
            return .orange  // Decent match (partial name match)
        } else {
            return .red  // Weak match
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    @Binding var flashlightOn: Bool
    @Binding var capturedImage: UIImage?
    @Binding var shouldCapturePhoto: Bool
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.setTorchMode(flashlightOn)
        
        // Trigger capture when shouldCapturePhoto becomes true
        if shouldCapturePhoto {
            DispatchQueue.main.async {
                self.shouldCapturePhoto = false
            }
            uiView.capturePhoto()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraPreviewDelegate {
        let parent: CameraPreviewView
        
        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }
        
        func didCaptureImage(_ image: UIImage) {
            DispatchQueue.main.async {
                self.parent.capturedImage = image
            }
        }
    }
}

// MARK: - Camera Preview UIView

protocol CameraPreviewDelegate: AnyObject {
    func didCaptureImage(_ image: UIImage)
}

class CameraPreviewUIView: UIView {
    
    weak var delegate: CameraPreviewDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var captureDevice: AVCaptureDevice?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        guard let captureSession = captureSession,
              let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("❌ Failed to access back camera")
            return
        }
        
        captureDevice = backCamera
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            photoOutput = AVCapturePhotoOutput()
            if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = bounds
            
            if let previewLayer = previewLayer {
                layer.addSublayer(previewLayer)
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
            
        } catch {
            print("❌ Camera setup error: \(error)")
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    func setTorchMode(_ on: Bool) {
        guard let device = captureDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("❌ Torch error: \(error)")
        }
    }
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraPreviewUIView: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ Photo capture error: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("❌ Failed to convert photo to UIImage")
            return
        }
        
        delegate?.didCaptureImage(image)
    }
}
