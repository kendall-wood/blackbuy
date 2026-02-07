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
    @EnvironmentObject var scanHistoryManager: ScanHistoryManager
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
    @State private var cameraAuthStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    
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
        Group {
            switch cameraAuthStatus {
            case .authorized:
                cameraBody
            case .notDetermined:
                cameraPermissionRequestView
            default:
                cameraPermissionDeniedView
            }
        }
        .onAppear {
            cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
    
    // MARK: - Camera Permission Views
    
    /// Shown when the user hasn't been asked yet — auto-requests on appear
    private var cameraPermissionRequestView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Requesting camera access...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraAuthStatus = granted ? .authorized : .denied
                }
            }
        }
    }
    
    /// Shown when camera access was denied or restricted
    private var cameraPermissionDeniedView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Top navigation buttons (same as camera view)
                HStack {
                    // Profile button for navigation
                    Spacer()
                    
                    Button(action: { selectedTab = .profile }) {
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
                }
                .padding(.top, 40)
                
                Spacer()
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 56))
                    .foregroundColor(DS.brandBlue)
                    .padding(.bottom, 8)
                
                Text("Camera Access Required")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text("BlackScan needs camera access to scan\nproduct labels and find Black-owned alternatives.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(action: {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }) {
                    Text("Open Settings")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(DS.brandGradient)
                        .cornerRadius(DS.radiusPill)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                
                // Still allow navigation to other tabs
                HStack(spacing: 18) {
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
                    
                    Button(action: { selectedTab = .checkout }) {
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
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                
                Spacer()
                Spacer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
    
    // MARK: - Camera Body
    
    private var cameraBody: some View {
        GeometryReader { geometry in
            ZStack {
                // Live Camera Feed
                CameraPreviewView(
                    flashlightOn: $flashlightOn,
                    capturedImage: $capturedImage,
                    shouldCapturePhoto: $shouldCapturePhoto
                )
                .ignoresSafeArea()
                
                // Scanning glow effect (stays blue on results until dismissed)
                if scanState == .capturing || scanState == .analyzing || scanState == .searching || scanState == .results {
                    ScanGlowOverlay(isResults: scanState == .results, hasProducts: !scanResults.isEmpty)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.4), value: scanState)
                }
                
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
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 18))
                                    .foregroundColor(DS.brandBlue)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            Text(scanButtonText)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(DS.brandBlue)
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: scanState)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(DS.radiusPill)
                        .dsButtonShadow()
                    }
                    .buttonStyle(DSButtonStyle())
                    .disabled(scanState == .capturing || scanState == .analyzing || scanState == .searching)
                    
                    Text("Shake to report issue")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.systemGray))
                    
                    // View Products button (appears after scan)
                    if scanState == .results && !scanResults.isEmpty {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                scanState = .initial
                            }
                            isShowingResults = true
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: "square.stack.fill")
                                    .font(.system(size: 22, weight: .medium))
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
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 16)
                            .background(DS.brandGradient)
                            .cornerRadius(DS.radiusPill)
                            .dsButtonShadow()
                        }
                        .buttonStyle(DSButtonStyle())
                        .padding(.top, 6)
                        .transition(.opacity)
                    }
                    
                    // No results found - grey button to shop
                    if scanState == .results && scanResults.isEmpty {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                scanState = .initial
                            }
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
                        .buttonStyle(DSButtonStyle())
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
        Log.debug("Scan button tapped, state: \(scanState)", category: .scan)
        
        if scanState == .results {
            // Reset to scan again
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                scanState = .initial
            }
            scanResults = []
            lastAnalysis = nil
            capturedImage = nil
        } else if scanState == .initial {
            // Trigger image capture
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                scanState = .capturing
            }
            
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Trigger photo capture
            shouldCapturePhoto = true
        }
    }
    
    // MARK: - Image Processing Pipeline
    
    private func handleCapturedImage(_ image: UIImage) {
        Log.debug("Image captured, size: \(image.size)", category: .scan)
        
        Task {
            await analyzeAndSearch(image: image)
        }
    }
    
    private func analyzeAndSearch(image: UIImage) async {
        // Step 1: Analyze with OpenAI Vision
        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                scanState = .analyzing
            }
        }
        
        Log.debug("Starting Hybrid Scan", category: .scan)
        
        do {
            let scanResult = try await HybridScanService.shared.analyzeProduct(image: image)
            
            Log.debug("Analysis complete via \(scanResult.method.displayName): \(scanResult.analysis.productType) (\(Int(scanResult.analysis.confidence * 100))%)", category: .scan)
            
            await MainActor.run {
                lastAnalysis = scanResult.analysis
                lastScanMethod = scanResult.method
                lastScanCost = scanResult.cost
            }
            
            // Step 2: Search Typesense
            await searchForMatches(analysis: scanResult.analysis)
            
        } catch {
            Log.error("Scan analysis failed", category: .scan)
            
            await MainActor.run {
                searchError = error.localizedDescription
                withAnimation(.easeOut(duration: 0.3)) {
                    scanState = .initial
                }
            }
        }
    }
    
    private func searchForMatches(analysis: HybridScanService.ProductAnalysis) async {
        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                scanState = .searching
            }
        }
        
        Log.debug("Searching for: \(analysis.productType)", category: .scan)
        
        do {
            // Convert OpenAI analysis to ScanClassification format
            let classification = convertToScanClassification(analysis: analysis)
            
            // Use advanced multi-pass search (retrieves up to 150 candidates for better coverage)
            let results = try await typesenseClient.searchForScanMatches(
                classification: classification,
                candidateCount: 150
            )
            
            Log.debug("Found \(results.count) candidate products", category: .scan)
            
            // NAME IS PRIMARY GATE: Filter by name first, then use Typesense ranking
            let targetLower = analysis.productType.lowercased()
            let targetWords = Set(targetLower.split(separator: " ").map(String.init))
            
            // Resolve taxonomy synonyms for the scanned product type (improves matching)
            let taxonomySynonyms: Set<String> = {
                var syns = Set<String>()
                if let canonical = ProductTaxonomy.shared.normalize(analysis.productType),
                   let type = ProductTaxonomy.shared.getType(canonical) {
                    for synonym in type.synonyms {
                        syns.insert(synonym.lowercased())
                    }
                    for variation in type.variations {
                        syns.insert(variation.lowercased())
                    }
                }
                return syns
            }()
            
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
                    Log.debug("FILTERED: '\(product.name)' - accessory mismatch", category: .scan)
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
                        Log.debug("FILTERED: '\(product.name)' - use-case mismatch", category: .scan)
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
                        Log.debug("FILTERED: '\(product.name)' - form mismatch", category: .scan)
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
                                          "moisturizer", "exfoliant", "mist", "gloss", "lipstick", "mascara",
                                          "eyeliner", "bronzer", "highlighter", "blush", "deodorant"]
                
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
                
                // Descriptor synonym groups: descriptors in the same group are treated as equivalent
                // e.g., "wash" and "soap" serve the same cleansing purpose
                let descriptorSynonymGroups: [[String]] = [
                    ["wash", "soap", "cleanser", "cleansing"],
                    ["conditioner", "mask", "masque", "treatment"],
                    ["cream", "lotion", "moisturizer", "butter", "balm"],
                    ["mist", "spray"],
                    ["wipe", "towelette"],
                    ["scrub", "exfoliant"],
                    ["serum", "oil"],
                ]
                
                // Expand overlap: check if target and product descriptors belong to the same synonym group
                var synonymOverlap = specificOverlap
                if synonymOverlap.isEmpty && !targetSpecific.isEmpty && !productSpecific.isEmpty {
                    for group in descriptorSynonymGroups {
                        let targetInGroup = !targetSpecific.intersection(Set(group)).isEmpty
                        let productInGroup = !productSpecific.intersection(Set(group)).isEmpty
                        if targetInGroup && productInGroup {
                            // Found a synonym-group match — add a synthetic overlap marker
                            synonymOverlap.insert("~synonym_group~")
                            break
                        }
                    }
                }
                
                // Check if product name or productType matches a taxonomy synonym of the scanned type
                let isTaxonomySynonym = taxonomySynonyms.contains(where: { syn in
                    nameLower.contains(syn) || productTypeLower.contains(syn)
                })
                
                // CRITICAL: If target has specific descriptors, product MUST match at least one
                // (taxonomy synonyms and descriptor synonym groups bypass this gate)
                if !targetSpecific.isEmpty && synonymOverlap.isEmpty && !isTaxonomySynonym {
                    Log.debug("FILTERED: '\(product.name)' - descriptor mismatch", category: .scan)
                    return nil
                }
                
                // Determine if this is an exact descriptor match or synonym-group match
                let hasExactDescriptorMatch = !specificOverlap.isEmpty
                let hasSynonymGroupMatch = !synonymOverlap.isEmpty && !hasExactDescriptorMatch
                
                // Now score based on how well they match
                if nameLower.contains(targetLower) {
                    // Perfect: name contains full target phrase ("Hand Sanitizer")
                    nameScore = 1.0
                } else if isTaxonomySynonym {
                    // Taxonomy synonym match (e.g., "Hand Gel" for "Hand Sanitizer")
                    nameScore = 0.92
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
                } else if hasSynonymGroupMatch {
                    // Descriptor synonym group match (e.g., "Body Wash" → "African Black Soap",
                    // "Deep Conditioner" → "Deep Conditioning Masque")
                    if overlap.count >= 2 {
                        // Multiple words overlap + synonym group match
                        nameScore = 0.88
                    } else {
                        // Just the synonym group match
                        nameScore = 0.78
                    }
                } else {
                    // No specific descriptors matched (should be rare due to gate above)
                    if overlap.count >= 2 {
                        nameScore = 0.60
                    } else if targetWords.contains(where: { tagsLower.contains($0) }) {
                        nameScore = 0.50
                    } else {
                        Log.debug("FILTERED: '\(product.name)' - insufficient match", category: .scan)
                        return nil
                    }
                }
                
                // Typesense position score (secondary ranking signal)
                // Wider range (0.60–1.0) so position is more discriminating between results
                let positionScore = 1.0 - (Double(index) / Double(results.count) * 0.40)
                
                // Form match bonus
                let formBonus: Double
                if let targetForm = analysis.form?.lowercased(),
                   let productForm = product.form?.lowercased() {
                    if targetForm == productForm {
                        formBonus = 0.08  // +8% for exact form match
                    } else if isFormCompatible(targetForm, productForm) {
                        formBonus = 0.04  // +4% for compatible forms
                    } else {
                        formBonus = 0.0   // No bonus for different forms
                    }
                } else {
                    formBonus = 0.0  // No bonus if form unknown
                }
                
                // Product type field match bonus (rewards products whose productType metadata aligns)
                let typeFieldBonus: Double = {
                    if productTypeLower == targetLower { return 0.05 }
                    if ProductTaxonomy.shared.areSynonyms(product.productType, analysis.productType) { return 0.04 }
                    return 0.0
                }()
                
                // Final score: 55% name quality + 30% position + bonuses
                // Name match quality is the PRIMARY signal for accuracy
                let baseScore = (nameScore * 0.55) + (positionScore * 0.30)
                let finalScore = min(baseScore + formBonus + typeFieldBonus, 1.0)
                
                Log.debug("#\(index + 1): \(product.name) = \(Int(finalScore * 100))% (name:\(Int(nameScore * 100)) pos:\(Int(positionScore * 100)))", category: .scan)
                
                return ScoredProduct(
                    id: product.id,
                    product: product,
                    confidenceScore: finalScore,
                    breakdown: ScoreBreakdown(
                        productTypeScore: nameScore,
                        formScore: formBonus > 0 ? 1.0 : 0.85,
                        brandScore: typeFieldBonus > 0 ? 1.0 : 0.85,
                        ingredientScore: 0.85,
                        sizeScore: 0.85,
                        visualScore: 0.85
                    ),
                    explanation: "Name: \(Int(nameScore * 100))%, Rank: \(Int(positionScore * 100))%\(formBonus > 0 ? ", Form: +\(Int(formBonus * 100))%" : "")\(typeFieldBonus > 0 ? ", Type: +\(Int(typeFieldBonus * 100))%" : "")"
                )
            }
            
            // Sort by score, limit to 2 per company for variety, show top 20
            let sortedResults = scoredResults.sorted { $0.confidenceScore > $1.confidenceScore }
            var companyCounts: [String: Int] = [:]
            var filteredResults: [ScoredProduct] = []
            for result in sortedResults {
                let company = result.product.company
                let count = companyCounts[company, default: 0]
                if count < 2 {
                    filteredResults.append(result)
                    companyCounts[company] = count + 1
                }
                if filteredResults.count >= 20 { break }
            }
            
            Log.debug("After filter: \(scoredResults.count) products (from \(results.count)), showing top \(filteredResults.count)", category: .scan)
            
            await MainActor.run {
                scanResults = filteredResults
                withAnimation(.easeOut(duration: 0.3)) {
                    scanState = .results
                }
                
                // Save scan to history
                scanHistoryManager.addScan(
                    recognizedText: analysis.rawText,
                    classifiedProduct: analysis.productType,
                    resultCount: filteredResults.count
                )
            }
            
        } catch {
            Log.error("Search failed", category: .scan)
            
            await MainActor.run {
                searchError = error.localizedDescription
                withAnimation(.easeOut(duration: 0.3)) {
                    scanState = .initial
                }
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
        Log.debug("Scoring \(products.count) products", category: .scan)
        
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
            } else {
                // Check word overlap
                let targetWords = Set(targetLower.split(separator: " ").map(String.init))
                let nameWords = Set(nameLower.split(separator: " ").map(String.init))
                let overlap = targetWords.intersection(nameWords)
                
                if overlap.count >= 2 {
                    // At least 2 words match (e.g., "Hand" + "Sanitizer")
                    nameScore = 0.80
                } else if overlap.count == 1 {
                    // Only 1 word matches
                    nameScore = 0.40
                } else {
                    // No match - but Typesense found it, so give some credit
                    nameScore = 0.20
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
            Log.debug("\(product.name): \(Int(score * 100))%", category: .scan)
            
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
            Log.error("Failed to access back camera", category: .scan)
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
            Log.error("Camera setup error", category: .scan)
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
            Log.error("Torch error", category: .scan)
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
            Log.error("Photo capture error", category: .scan)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Log.error("Failed to convert photo to UIImage", category: .scan)
            return
        }
        
        delegate?.didCaptureImage(image)
    }
}

// MARK: - Scan Glow Overlay

/// A pulsing edge glow that hugs the device's screen corners while scanning.
/// Turns solid blue when results are found and stays until dismissed.
struct ScanGlowOverlay: View {
    var isResults: Bool = false
    var hasProducts: Bool = false
    @State private var pulse = false
    
    /// The device's display corner radius (reads from UIScreen private key, falls back to 44)
    private var screenRadius: CGFloat {
        UIScreen.main.value(forKey: "_displayCornerRadius") as? CGFloat ?? 44
    }
    
    private var glowColor: Color {
        isResults && hasProducts ? DS.brandBlue : DS.brandBlue
    }
    
    private var secondaryColor: Color {
        isResults && hasProducts ? DS.brandBlue : DS.brandGreen
    }
    
    var body: some View {
        let cr = screenRadius
        
        ZStack {
            // Layer 1: Ultra-wide ambient glow
            // lineWidth & blur stay fixed to avoid layout churn — only opacity animates
            RoundedRectangle(cornerRadius: cr)
                .stroke(
                    AngularGradient(
                        colors: [
                            glowColor.opacity(isResults ? 0.6 : (pulse ? 0.70 : 0.20)),
                            secondaryColor.opacity(isResults ? 0.5 : (pulse ? 0.55 : 0.12)),
                            glowColor.opacity(isResults ? 0.6 : (pulse ? 0.65 : 0.18)),
                            secondaryColor.opacity(isResults ? 0.5 : (pulse ? 0.55 : 0.12)),
                            glowColor.opacity(isResults ? 0.6 : (pulse ? 0.70 : 0.20))
                        ],
                        center: .center
                    ),
                    lineWidth: isResults ? 14 : 10
                )
                .blur(radius: isResults ? 32 : 28)
            
            // Layer 2: Medium body glow
            RoundedRectangle(cornerRadius: cr)
                .stroke(
                    LinearGradient(
                        colors: [
                            glowColor.opacity(isResults ? 0.7 : (pulse ? 0.60 : 0.15)),
                            secondaryColor.opacity(isResults ? 0.55 : (pulse ? 0.50 : 0.10)),
                            glowColor.opacity(isResults ? 0.7 : (pulse ? 0.60 : 0.15))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isResults ? 8 : 6
                )
                .blur(radius: isResults ? 16 : 13)
            
            // Layer 3: Tight inner glow
            RoundedRectangle(cornerRadius: cr)
                .stroke(
                    LinearGradient(
                        colors: [
                            glowColor.opacity(isResults ? 0.65 : (pulse ? 0.50 : 0.12)),
                            secondaryColor.opacity(isResults ? 0.55 : (pulse ? 0.40 : 0.08)),
                            glowColor.opacity(isResults ? 0.65 : (pulse ? 0.50 : 0.12))
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: isResults ? 4 : 3.5
                )
                .blur(radius: isResults ? 6 : 4.5)
            
            // Layer 4: Crisp edge stroke aligned to screen rim
            RoundedRectangle(cornerRadius: cr)
                .stroke(
                    LinearGradient(
                        colors: [
                            glowColor.opacity(isResults ? 0.8 : (pulse ? 0.55 : 0.15)),
                            secondaryColor.opacity(isResults ? 0.7 : (pulse ? 0.45 : 0.10)),
                            glowColor.opacity(isResults ? 0.8 : (pulse ? 0.55 : 0.15))
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: isResults ? 2.5 : 1.8
                )
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.4)
                .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
        }
    }
}
