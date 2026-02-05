import Foundation
import UIKit

/// Hybrid scanning service that intelligently chooses between:
/// - Cheap: Multi-frame OCR + GPT-4 Text API (~$0.001 per scan)
/// - Expensive: OpenAI Vision API (~$0.01 per scan)
/// 
/// Strategy: Try cheap first, fallback to expensive if quality is low
@available(iOS 16.0, *)
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
        case ocrPlusText  // OCR + GPT-4 Text (~$0.001)
        case vision       // GPT-4 Vision (~$0.01)
        
        var displayName: String {
            switch self {
            case .ocrPlusText: return "OCR + Text API"
            case .vision: return "Vision API"
            }
        }
        
        var estimatedCost: Double {
            switch self {
            case .ocrPlusText: return 0.001
            case .vision: return 0.01
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
        
        if Env.isDebugMode {
            print("🔬 Hybrid Scan: Starting analysis...")
        }
        
        // For now, since we haven't implemented actual OCR yet,
        // we'll use Vision API as the primary method
        // TODO: Implement multi-frame OCR once camera capture is ready
        
        // Use Vision API (will be replaced with OCR+Text in next step)
        let visionAnalysis = try await OpenAIVisionService.shared.analyzeProduct(image: image)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        if Env.isDebugMode {
            print("✅ Hybrid Scan: Complete via Vision API")
            print("   Time: \(String(format: "%.2f", processingTime))s")
            print("   Cost: ~$\(String(format: "%.4f", ScanMethod.vision.estimatedCost))")
        }
        
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
        
        if Env.isDebugMode {
            print("🔬 Hybrid Scan: Multi-frame analysis with \(images.count) frames")
        }
        
        // Step 1: Try OCR + Text API (cheap!)
        do {
            let ocrResult = try await MultiFrameOCRService.shared.analyzeImages(images)
            
            if ocrResult.shouldUseCheapAPI {
                // OCR quality is good, use cheap text API
                if Env.isDebugMode {
                    print("✅ OCR quality good (\(Int(ocrResult.qualityScore * 100))%) - using cheap text API")
                }
                
                let textAnalysis = try await GPT4TextService.shared.analyzeOCRText(ocrResult.text)
                
                // Check if GPT is confident in its parsing
                if textAnalysis.confidence >= 0.7 {
                    let processingTime = Date().timeIntervalSince(startTime)
                    
                    if Env.isDebugMode {
                        print("✅ Hybrid Scan: Complete via OCR + Text API")
                        print("   Time: \(String(format: "%.2f", processingTime))s")
                        print("   Cost: ~$\(String(format: "%.4f", ScanMethod.ocrPlusText.estimatedCost))")
                        print("   💰 Saved: $\(String(format: "%.4f", ScanMethod.vision.estimatedCost - ScanMethod.ocrPlusText.estimatedCost))")
                    }
                    
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
                    if Env.isDebugMode {
                        print("⚠️ GPT confidence low (\(Int(textAnalysis.confidence * 100))%) - falling back to Vision API")
                    }
                }
            } else {
                if Env.isDebugMode {
                    print("⚠️ OCR quality low (\(Int(ocrResult.qualityScore * 100))%) - falling back to Vision API")
                }
            }
        } catch {
            if Env.isDebugMode {
                print("⚠️ OCR failed: \(error.localizedDescription) - falling back to Vision API")
            }
        }
        
        // Step 2: Fallback to Vision API (expensive but accurate)
        if Env.isDebugMode {
            print("🔄 Using Vision API fallback...")
        }
        
        // Use the first/best image for Vision API
        let bestImage = images.first!
        let visionAnalysis = try await OpenAIVisionService.shared.analyzeProduct(image: bestImage)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        if Env.isDebugMode {
            print("✅ Hybrid Scan: Complete via Vision API (fallback)")
            print("   Time: \(String(format: "%.2f", processingTime))s")
            print("   Cost: ~$\(String(format: "%.4f", ScanMethod.vision.estimatedCost))")
        }
        
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
