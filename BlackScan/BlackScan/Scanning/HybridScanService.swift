import Foundation
import UIKit

/// Hybrid scanning service that intelligently chooses between:
/// - Cheap: Multi-frame OCR + GPT-4o-mini Text API (~$0.0003 per scan)
/// - Expensive: OpenAI GPT-4o Vision API (~$0.006 per scan)
/// 
/// Strategy: Try cheap first, fallback to expensive if quality is low
class HybridScanService {
    
    static let shared = HybridScanService()
    
    private init() {}
    
    // MARK: - Models
    
    struct ScanResult {
        let analysis: ProductAnalysis
        let method: ScanMethod
        let cost: Double
        let processingTime: TimeInterval
    }
    
    enum ScanMethod {
        case ocrPlusText  // OCR + GPT-4o-mini Text (~$0.0003)
        case vision       // GPT-4o Vision (~$0.006)
        
        var displayName: String {
            switch self {
            case .ocrPlusText: return "OCR + Text API"
            case .vision: return "Vision API"
            }
        }
        
        var estimatedCost: Double {
            switch self {
            case .ocrPlusText: return 0.0003
            case .vision: return 0.006
            }
        }
    }
    
    struct ProductAnalysis {
        let brand: String?
        let productType: String
        let form: String?
        let size: String?
        let ingredients: [String]
        let confidence: Double
        let rawText: String
    }
    
    // MARK: - Public API
    
    /// Analyze product using hybrid approach with intelligent fallback
    /// - Parameter image: Single image of product label
    /// - Returns: ScanResult with analysis, method used, and cost
    func analyzeProduct(image: UIImage) async throws -> ScanResult {
        let startTime = Date()
        
        Log.debug("Hybrid Scan: Starting analysis (single frame mode)", category: .scan)
        
        // Single frame mode: Try OCR first, fallback to Vision
        do {
            // Try OCR + Text API (cheap!)
            let ocrResult = try await MultiFrameOCRService.shared.analyzeImages([image])
            
            if ocrResult.shouldUseCheapAPI {
                Log.debug("OCR quality good (\(Int(ocrResult.qualityScore * 100))%) - trying text API", category: .scan)
                
                let textAnalysis = try await GPT4TextService.shared.analyzeOCRText(ocrResult.text)
                
                // Check if GPT is confident
                if textAnalysis.confidence >= 0.7 {
                    let processingTime = Date().timeIntervalSince(startTime)
                    
                    Log.debug("Hybrid Scan: SUCCESS via OCR + Text API (\(String(format: "%.2f", processingTime))s)", category: .scan)
                    
                    let analysis = ProductAnalysis(
                        brand: textAnalysis.brand,
                        productType: textAnalysis.productType,
                        form: textAnalysis.form,
                        size: textAnalysis.size,
                        ingredients: textAnalysis.ingredients,
                        confidence: textAnalysis.confidence,
                        rawText: textAnalysis.rawText
                    )
                    
                    return ScanResult(
                        analysis: analysis,
                        method: .ocrPlusText,
                        cost: ScanMethod.ocrPlusText.estimatedCost,
                        processingTime: processingTime
                    )
                } else {
                    Log.debug("GPT confidence low (\(Int(textAnalysis.confidence * 100))%) - falling back to Vision", category: .scan)
                }
            } else {
                Log.debug("OCR quality low (\(Int(ocrResult.qualityScore * 100))%) - falling back to Vision", category: .scan)
            }
        } catch {
            Log.debug("OCR failed - falling back to Vision", category: .scan)
        }
        
        // Fallback to Vision API
        Log.debug("Using Vision API fallback", category: .scan)
        
        let visionAnalysis = try await OpenAIVisionService.shared.analyzeProduct(image: image)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        Log.debug("Hybrid Scan: Complete via Vision API (\(String(format: "%.2f", processingTime))s)", category: .scan)
        
        let analysis = ProductAnalysis(
            brand: visionAnalysis.brand,
            productType: visionAnalysis.productType,
            form: visionAnalysis.form,
            size: visionAnalysis.size,
            ingredients: visionAnalysis.ingredients,
            confidence: visionAnalysis.confidence,
            rawText: visionAnalysis.rawText
        )
        
        return ScanResult(
            analysis: analysis,
            method: .vision,
            cost: ScanMethod.vision.estimatedCost,
            processingTime: processingTime
        )
    }
    
    /// Analyze product with multi-frame OCR (preferred method when available)
    /// - Parameter images: Multiple frames captured rapidly
    /// - Returns: ScanResult with best method chosen automatically
    func analyzeMultiFrame(images: [UIImage]) async throws -> ScanResult {
        let startTime = Date()
        
        guard !images.isEmpty else {
            throw ScanError.noImages
        }
        
        Log.debug("Hybrid Scan: Multi-frame analysis with \(images.count) frames", category: .scan)
        
        // Step 1: Try OCR + Text API (cheap!)
        do {
            let ocrResult = try await MultiFrameOCRService.shared.analyzeImages(images)
            
            if ocrResult.shouldUseCheapAPI {
                Log.debug("OCR quality good (\(Int(ocrResult.qualityScore * 100))%) - using text API", category: .scan)
                
                let textAnalysis = try await GPT4TextService.shared.analyzeOCRText(ocrResult.text)
                
                if textAnalysis.confidence >= 0.7 {
                    let processingTime = Date().timeIntervalSince(startTime)
                    
                    Log.debug("Hybrid Scan: Complete via OCR + Text API (\(String(format: "%.2f", processingTime))s)", category: .scan)
                    
                    let analysis = ProductAnalysis(
                        brand: textAnalysis.brand,
                        productType: textAnalysis.productType,
                        form: textAnalysis.form,
                        size: textAnalysis.size,
                        ingredients: textAnalysis.ingredients,
                        confidence: textAnalysis.confidence,
                        rawText: textAnalysis.rawText
                    )
                    
                    return ScanResult(
                        analysis: analysis,
                        method: .ocrPlusText,
                        cost: ScanMethod.ocrPlusText.estimatedCost,
                        processingTime: processingTime
                    )
                } else {
                    Log.debug("GPT confidence low (\(Int(textAnalysis.confidence * 100))%) - falling back to Vision", category: .scan)
                }
            } else {
                Log.debug("OCR quality low (\(Int(ocrResult.qualityScore * 100))%) - falling back to Vision", category: .scan)
            }
        } catch {
            Log.debug("OCR failed - falling back to Vision API", category: .scan)
        }
        
        // Step 2: Fallback to Vision API (expensive but accurate)
        Log.debug("Using Vision API fallback", category: .scan)
        
        // Use the first/best image for Vision API
        let bestImage = images.first!
        let visionAnalysis = try await OpenAIVisionService.shared.analyzeProduct(image: bestImage)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        Log.debug("Hybrid Scan: Complete via Vision API (\(String(format: "%.2f", processingTime))s)", category: .scan)
        
        let analysis = ProductAnalysis(
            brand: visionAnalysis.brand,
            productType: visionAnalysis.productType,
            form: visionAnalysis.form,
            size: visionAnalysis.size,
            ingredients: visionAnalysis.ingredients,
            confidence: visionAnalysis.confidence,
            rawText: visionAnalysis.rawText
        )
        
        return ScanResult(
            analysis: analysis,
            method: .vision,
            cost: ScanMethod.vision.estimatedCost,
            processingTime: processingTime
        )
    }
    
    // MARK: - Error Types
    
    enum ScanError: LocalizedError {
        case noImages
        
        var errorDescription: String? {
            switch self {
            case .noImages:
                return "No images provided for scanning"
            }
        }
    }
}
