import SwiftUI
import VisionKit
import AVFoundation

/// Live camera scanner using VisionKit DataScannerViewController
/// Recognizes text and barcodes with debounced aggregation
@available(iOS 16.0, *)
struct LiveScannerView: UIViewControllerRepresentable {
    
    // MARK: - Properties
    
    let onRecognized: (String) -> Void
    let debounceDelay: TimeInterval
    @Binding var isTorchOn: Bool  // Flashlight control
    
    // MARK: - Initialization
    
    init(
        debounceDelay: TimeInterval = 1.0,
        isTorchOn: Binding<Bool> = .constant(false),
        onRecognized: @escaping (String) -> Void
    ) {
        self.debounceDelay = debounceDelay
        self._isTorchOn = isTorchOn
        self.onRecognized = onRecognized
    }
    
    // MARK: - UIViewControllerRepresentable
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
            .text(languages: ["en-US"]),
            .barcode(symbologies: [.upce, .code128, .code39, .code93, .ean8, .ean13])
        ]
        
        let dataScannerViewController = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        
        dataScannerViewController.delegate = context.coordinator
        return dataScannerViewController
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // Update coordinator's callback if needed
        context.coordinator.onRecognized = onRecognized
        context.coordinator.debounceDelay = debounceDelay
        
        // Update torch/flashlight state
        if let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            do {
                try device.lockForConfiguration()
                if isTorchOn {
                    try device.setTorchModeOn(level: 1.0)
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                print("❌ Failed to set torch: \(error)")
            }
        }
        
        // Start scanning if not already started
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            debounceDelay: debounceDelay,
            onRecognized: onRecognized
        )
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        
        // MARK: - Properties
        
        var onRecognized: (String) -> Void
        var debounceDelay: TimeInterval
        
        // Debouncing state
        private var recognizedTexts: Set<String> = []
        private var debounceTimer: Timer?
        private let textAggregationQueue = DispatchQueue(label: "com.blackscan.text-aggregation")
        
        // MARK: - Initialization
        
        init(debounceDelay: TimeInterval, onRecognized: @escaping (String) -> Void) {
            self.debounceDelay = debounceDelay
            self.onRecognized = onRecognized
            super.init()
        }
        
        // MARK: - DataScannerViewControllerDelegate
        
        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            processRecognizedItem(item)
        }
        
        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            // Process newly added items
            for item in addedItems {
                processRecognizedItem(item)
            }
        }
        
        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didRemove removedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            // Items removed from view - could clean up if needed
            // For now, we keep accumulated text for better recognition
        }
        
        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            print("⚠️ Scanner unavailable: \(error)")
            // Scanner is unavailable - could be camera access, device support, etc.
        }
        
        // MARK: - Private Methods
        
        private func processRecognizedItem(_ item: RecognizedItem) {
            let extractedText: String
            
            switch item {
            case .text(let text):
                extractedText = text.transcript
                
            case .barcode(let barcode):
                extractedText = barcode.payloadStringValue ?? ""
                
            @unknown default:
                return
            }
            
            // Filter out empty or very short text
            guard !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  extractedText.count >= 2 else {
                return
            }
            
            textAggregationQueue.async { [weak self] in
                self?.addRecognizedText(extractedText)
            }
        }
        
        private func addRecognizedText(_ text: String) {
            // Clean and normalize the text
            let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Add to our set of recognized texts
            recognizedTexts.insert(cleanedText)
            
            // Reset the debounce timer
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceDelay, repeats: false) { [weak self] _ in
                self?.processAggregatedText()
            }
        }
        
        private func processAggregatedText() {
            guard !recognizedTexts.isEmpty else { return }
            
            // Combine all recognized texts into a single string
            let combinedText = Array(recognizedTexts)
                .sorted { $0.count > $1.count } // Prioritize longer text
                .joined(separator: " ")
            
            // Call the recognition callback on main thread
            DispatchQueue.main.async { [weak self] in
                self?.onRecognized(combinedText)
            }
            
            // Clear the accumulated texts after processing
            recognizedTexts.removeAll()
        }
    }
}

// MARK: - Scanner Availability Check

@available(iOS 16.0, *)
extension LiveScannerView {
    
    /// Checks if DataScanner is available on the current device
    static var isSupported: Bool {
        DataScannerViewController.isSupported
    }
    
    /// Checks if DataScanner is available and authorized
    static var isAvailable: Bool {
        DataScannerViewController.isAvailable
    }
    
    /// Requests camera permission if not already granted
    static func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

// MARK: - Fallback View for Unsupported Devices

struct ScannerUnavailableView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Scanner Unavailable")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Scanner Container with Availability Check

struct ScannerContainerView: View {
    let onRecognized: (String) -> Void
    @Binding var isTorchOn: Bool
    
    init(isTorchOn: Binding<Bool> = .constant(false), onRecognized: @escaping (String) -> Void) {
        self._isTorchOn = isTorchOn
        self.onRecognized = onRecognized
    }
    
    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                if LiveScannerView.isSupported {
                    LiveScannerView(isTorchOn: $isTorchOn, onRecognized: onRecognized)
                } else {
                    ScannerUnavailableView(
                        message: "Camera scanning is not supported on this device. Please use a physical iPhone to scan products."
                    )
                }
            } else {
                ScannerUnavailableView(
                    message: "Camera scanning requires iOS 16 or later. Please update your device to use this feature."
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Scanner View") {
    ScannerContainerView { recognizedText in
        print("Recognized: \(recognizedText)")
    }
    .preferredColorScheme(.dark) // Test with dark mode
}

#Preview("Unavailable View") {
    ScannerUnavailableView(
        message: "Camera scanning is not supported on this device."
    )
}
