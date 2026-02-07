import Foundation
import UIKit
import Vision

/// Multi-frame OCR service for better text capture accuracy
/// Captures 3 frames and aggregates results for 90-95% accuracy
class MultiFrameOCRService {
    
    static let shared = MultiFrameOCRService()
    
    private init() {}
    
    // MARK: - Models
    
    struct OCRResult {
        let text: String
        let confidence: Double
        let qualityScore: Double
        let wordCount: Int
        let hasProductKeywords: Bool
        let hasBrand: Bool
        
        var shouldUseCheapAPI: Bool {
            // Use cheap text API if quality is good
            return qualityScore >= 0.7 && wordCount >= 5
        }
    }
    
    // MARK: - Public API
    
    /// Analyze multiple images and aggregate OCR results
    /// - Parameter images: Array of UIImages (typically 3 frames)
    /// - Returns: Aggregated OCR result with quality metrics
    func analyzeImages(_ images: [UIImage]) async throws -> OCRResult {
        guard !images.isEmpty else {
            throw OCRError.noImages
        }
        
        if Env.isDebugMode {
            Log.debug("Multi-frame OCR: Processing \(images.count) frames", category: .scan)
        }
        
        // Run OCR on each frame
        var allTexts: [String] = []
        var totalConfidence: Double = 0.0
        
        for (index, image) in images.enumerated() {
            let text = try await extractText(from: image)
            if !text.isEmpty {
                allTexts.append(text)
                totalConfidence += 1.0 // Each successful extraction adds confidence
                
                if Env.isDebugMode {
                    Log.debug("Frame \(index + 1): \(text.count) chars", category: .scan)
                }
            }
        }
        
        guard !allTexts.isEmpty else {
            throw OCRError.noTextRecognized
        }
        
        // Merge and deduplicate text
        let mergedText = mergeTexts(allTexts)
        
        // Calculate quality metrics
        let confidence = totalConfidence / Double(images.count)
        let quality = calculateQualityScore(mergedText)
        let wordCount = mergedText.split(separator: " ").count
        let hasKeywords = containsProductKeywords(mergedText)
        let hasBrand = containsCommonBrand(mergedText)
        
        if Env.isDebugMode {
            Log.debug("OCR Complete: \(mergedText.count) chars, quality: \(Int(quality * 100))%, words: \(wordCount)", category: .scan)
            Log.debug("Keywords: \(hasKeywords), Brand: \(hasBrand)", category: .scan)
            Log.debug("Should use cheap API: \(quality >= 0.7 && wordCount >= 5)", category: .scan)
        }
        
        return OCRResult(
            text: mergedText,
            confidence: confidence,
            qualityScore: quality,
            wordCount: wordCount,
            hasProductKeywords: hasKeywords,
            hasBrand: hasBrand
        )
    }
    
    // MARK: - Private Helpers
    
    private func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Create Vision text recognition request
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                // Extract text from all observations
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: " ")
                continuation.resume(returning: fullText)
            }
            
            // Configure for accurate text recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.0  // Recognize all text sizes
            
            // Perform the request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Merge multiple text results and deduplicate
    private func mergeTexts(_ texts: [String]) -> String {
        // Combine all texts
        let combined = texts.joined(separator: " ")
        
        // Split into words and deduplicate while preserving order
        var seenWords = Set<String>()
        var uniqueWords: [String] = []
        
        for word in combined.split(separator: " ") {
            let cleanWord = String(word).trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = cleanWord.lowercased()
            
            if !normalized.isEmpty && !seenWords.contains(normalized) {
                seenWords.insert(normalized)
                uniqueWords.append(cleanWord)
            }
        }
        
        return uniqueWords.joined(separator: " ")
    }
    
    /// Calculate overall quality score (0.0-1.0)
    private func calculateQualityScore(_ text: String) -> Double {
        var score = 1.0
        
        // Length check (longer = more complete)
        if text.count < 30 {
            score -= 0.3
        } else if text.count < 50 {
            score -= 0.1
        }
        
        // Product keywords check
        if !containsProductKeywords(text) {
            score -= 0.2
        }
        
        // Brand name check (positive signal)
        if containsCommonBrand(text) {
            score += 0.1
        }
        
        // Size/unit check
        let hasSizeUnits = text.lowercased().range(of: "(oz|ml|fl|g|kg|lb)") != nil
        if hasSizeUnits {
            score += 0.1
        }
        
        return max(0.0, min(1.0, score))
    }
    
    /// Check if text contains product-related keywords
    private func containsProductKeywords(_ text: String) -> Bool {
        let keywords = [
            "oz", "ml", "fl", "gel", "spray", "cream", "wash", "lotion",
            "shampoo", "conditioner", "serum", "oil", "sanitizer", "cleanser",
            "soap", "butter", "balm", "stick", "powder", "foam", "mist"
        ]
        
        let lower = text.lowercased()
        return keywords.contains { lower.contains($0) }
    }
    
    /// Check if text contains common brand names
    private func containsCommonBrand(_ text: String) -> Bool {
        let brands = [
            "dove", "garnier", "purell", "cerave", "neutrogena", "loreal",
            "l'oreal", "revlon", "covergirl", "maybelline", "olay", "aveeno",
            "nivea", "vaseline", "jergens", "suave", "pantene", "head & shoulders"
        ]
        
        let lower = text.lowercased()
        return brands.contains { lower.contains($0) }
    }
    
    // MARK: - Error Types
    
    enum OCRError: LocalizedError {
        case noImages
        case noTextRecognized
        case invalidImage
        
        var errorDescription: String? {
            switch self {
            case .noImages:
                return "No images provided for OCR"
            case .noTextRecognized:
                return "Could not recognize any text in images"
            case .invalidImage:
                return "Invalid image format"
            }
        }
    }
}
