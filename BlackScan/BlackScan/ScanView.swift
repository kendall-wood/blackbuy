import SwiftUI
import AVFoundation

/// Main scanning view using OpenAI GPT-4 Vision for product recognition
/// Captures image → AI analysis → Search → Results
struct ScanView: View {
    
    // MARK: - State Properties
    
    @StateObject private var typesenseClient = TypesenseClient()
    @State private var isShowingResults = false
    @State private var scanResults: [ScoredProduct] = []
    @State private var lastAnalysis: OpenAIVisionService.ProductAnalysis?
    @State private var searchError: String?
    @State private var flashlightOn = false
    @State private var capturedImage: UIImage?
    @State private var shouldCapturePhoto = false
    
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
    
    private let resultSheetDetents: Set<PresentationDetent> = [
        .fraction(0.45),
        .large
    ]
    
    var body: some View {
        ZStack {
            // Live Camera Feed
            CameraPreviewView(
                flashlightOn: $flashlightOn,
                capturedImage: $capturedImage,
                shouldCapturePhoto: $shouldCapturePhoto
            )
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
                        if scanState != .initial && scanState != .results {
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
                .disabled(scanState == .capturing || scanState == .analyzing || scanState == .searching)
                
                Spacer()
                    .frame(height: 120) // Account for tab bar
            }
        }
        .sheet(isPresented: $isShowingResults) {
            resultsSheet
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                handleCapturedImage(image)
            }
        }
    }
    
    // MARK: - Button State Computed Properties
    
    private var buttonText: String {
        switch scanState {
        case .initial:
            return "Start Scanning"
        case .capturing:
            return "Capturing..."
        case .analyzing:
            return "Analyzing..."
        case .searching:
            return "Searching..."
        case .results:
            let count = scanResults.count
            return "See \(count)+ Result\(count == 1 ? "" : "s")"
        }
    }
    
    private var buttonBackgroundColor: Color {
        switch scanState {
        case .initial:
            return .white
        case .capturing, .analyzing, .searching:
            return .green
        case .results:
            return Color(red: 0.26, green: 0.63, blue: 0.95) // Blue
        }
    }
    
    private var buttonTextColor: Color {
        switch scanState {
        case .initial:
            return Color(red: 0.26, green: 0.63, blue: 0.95) // Blue
        case .capturing, .analyzing, .searching, .results:
            return .white
        }
    }
    
    // MARK: - Button Action
    
    private func handleButtonTap() {
        print("🔘 Button tapped! Current state: \(scanState), results: \(scanResults.count)")
        
        if scanState == .results {
            // Show results sheet
            print("📊 Showing results sheet with \(scanResults.count) results")
            isShowingResults = true
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
        
        print("🤖 Starting OpenAI Vision analysis...")
        
        do {
            let analysis = try await OpenAIVisionService.shared.analyzeProduct(image: image)
            
            print("✅ Analysis complete!")
            print("   Product Type: \(analysis.productType)")
            print("   Brand: \(analysis.brand ?? "unknown")")
            print("   Form: \(analysis.form ?? "unknown")")
            print("   Confidence: \(Int(analysis.confidence * 100))%")
            
            await MainActor.run {
                lastAnalysis = analysis
            }
            
            // Step 2: Search Typesense
            await searchForMatches(analysis: analysis)
            
        } catch {
            print("❌ OpenAI Vision error: \(error.localizedDescription)")
            
            await MainActor.run {
                searchError = "Failed to analyze product: \(error.localizedDescription)"
                scanState = .initial
            }
        }
    }
    
    private func searchForMatches(analysis: OpenAIVisionService.ProductAnalysis) async {
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
            
            let scoredResults = results.enumerated().compactMap { (index, product) -> ScoredProduct? in
                let nameLower = product.name.lowercased()
                let nameWords = Set(nameLower.split(separator: " ").map(String.init))
                
                // GATE: Calculate name match score
                let nameScore: Double
                let overlap = targetWords.intersection(nameWords)
                
                if nameLower.contains(targetLower) {
                    // Perfect: name contains full target ("Hand Sanitizer")
                    nameScore = 1.0
                } else if overlap.count >= 2 {
                    // Good: at least 2 words match
                    nameScore = 0.80
                } else if overlap.count == 1 {
                    // Weak: only 1 word matches
                    nameScore = 0.40
                } else {
                    // No match: skip this product entirely
                    if Env.isDebugMode {
                        print("   ❌ FILTERED OUT: '\(product.name)' - no name match")
                    }
                    return nil
                }
                
                // Typesense position score (secondary)
                let positionScore = 1.0 - (Double(index) / Double(results.count) * 0.20)
                
                // Final score: 70% name + 30% position
                let finalScore = (nameScore * 0.70) + (positionScore * 0.30)
                
                if Env.isDebugMode {
                    print("   ✅ #\(index + 1): \(product.name) = \(Int(finalScore * 100))% (name: \(Int(nameScore * 100))%, position: \(Int(positionScore * 100))%)")
                }
                
                return ScoredProduct(
                    id: product.id,
                    product: product,
                    confidenceScore: finalScore,
                    breakdown: ScoreBreakdown(
                        productTypeScore: nameScore,
                        formScore: positionScore,
                        brandScore: 0.85,
                        ingredientScore: 0.85,
                        sizeScore: 0.85,
                        visualScore: 0.85
                    ),
                    explanation: "Name: \(Int(nameScore * 100))%, Position: \(Int(positionScore * 100))%"
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
                scanState = filteredResults.isEmpty ? .initial : .results
                
                if filteredResults.isEmpty {
                    searchError = "No high-confidence matches found. Try scanning again with better lighting."
                }
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
    
    /// Convert OpenAI ProductAnalysis to ScanClassification
    private func convertToScanClassification(analysis: OpenAIVisionService.ProductAnalysis) -> ScanClassification {
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
                sheetHeader
                
                if let error = searchError {
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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let analysis = lastAnalysis {
                        Text("Found: \(analysis.productType)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 4) {
                            Text("Black-owned products")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
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
                    scanState = .initial
                    scanResults = []
                    lastAnalysis = nil
                    capturedImage = nil
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
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                isShowingResults = false
                scanState = .initial
                scanResults = []
                searchError = nil
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
            
            Text("No Matches Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try scanning again with better lighting or a clearer view of the product label.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Scan Again") {
                isShowingResults = false
                scanState = .initial
                scanResults = []
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var successResultsContent: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(scanResults) { scoredProduct in
                    NavigationLink(destination: ProductDetailView(product: scoredProduct.product)) {
                        ProductCard(product: scoredProduct.product, onBuyTapped: {
                            // Open product URL in Safari
                            if let url = URL(string: scoredProduct.product.productUrl) {
                                UIApplication.shared.open(url)
                            }
                        })
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.75 {
            return .green  // Excellent match (name + form match)
        } else if confidence >= 0.60 {
            return Color(red: 0.6, green: 0.8, blue: 0.4) // Light green (name match, form mismatch)
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
