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
            // Build search query from analysis
            let searchQuery = analysis.productType
            
            // Search Typesense
            let results = try await typesenseClient.searchProducts(
                query: searchQuery,
                page: 1,
                perPage: 20
            )
            
            print("✅ Found \(results.count) products from Typesense")
            
            // Convert OpenAI analysis to ScanClassification format
            let classification = convertToScanClassification(analysis: analysis)
            
            // Use existing ConfidenceScorer (already tested and working!)
            let scoredResults = ConfidenceScorer.shared.scoreProducts(
                candidates: results,
                classification: classification
            )
            
            // Filter to 90%+ confidence
            let filteredResults = scoredResults.filter { $0.confidenceScore >= 0.90 }
            
            print("📊 After 90% confidence filter: \(filteredResults.count) products")
            
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
        if confidence >= 0.95 {
            return .green
        } else if confidence >= 0.90 {
            return Color(red: 0.6, green: 0.8, blue: 0.4) // Light green
        } else if confidence >= 0.85 {
            return .orange
        } else {
            return .red
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
