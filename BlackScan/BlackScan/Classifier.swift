import Foundation

/// Rule-based classifier that maps OCR text to product types and search queries
/// Provides deterministic classification for common hair care and beauty products
struct Classifier {
    
    // MARK: - Classification Result
    
    struct ClassificationResult {
        let productType: String
        let queryString: String
        let confidence: Float
        let matchedKeywords: [String]
        
        init(productType: String, queryString: String? = nil, confidence: Float = 1.0, matchedKeywords: [String] = []) {
            self.productType = productType
            self.queryString = queryString ?? productType
            self.confidence = confidence
            self.matchedKeywords = matchedKeywords
        }
    }
    
    // MARK: - Classification Rules
    
    /// Hair care product type mappings with keywords
    private static let hairCareRules: [String: [String]] = [
        "Shampoo": [
            "shampoo", "cleansing shampoo", "clarifying shampoo", "sulfate-free shampoo",
            "moisturizing shampoo", "dry shampoo", "purple shampoo", "baby shampoo"
        ],
        
        "Conditioner": [
            "conditioner", "rinse out conditioner", "daily conditioner", "moisturizing conditioner",
            "protein conditioner", "color safe conditioner"
        ],
        
        "Leave-In Conditioner": [
            "leave-in conditioner", "leave in conditioner", "leave-in", "leave in",
            "detangling spray", "leave-in treatment", "daily leave-in"
        ],
        
        "Co-Wash": [
            "co-wash", "cowash", "cleansing conditioner", "conditioning cleanser",
            "no-poo", "co wash", "cleansing cream"
        ],
        
        "Mask/Deep Conditioner": [
            "hair mask", "deep conditioner", "deep conditioning treatment", "protein treatment",
            "deep treatment", "intensive treatment", "hair treatment", "reconstructor",
            "deep repair", "mask", "conditioning mask"
        ],
        
        "Gel/Gelly": [
            "gel", "styling gel", "hair gel", "curl gel", "edge gel", "gelly",
            "defining gel", "hold gel", "strong hold gel", "light hold gel"
        ],
        
        "Curl Cream": [
            "curl cream", "curling cream", "curl defining cream", "styling cream",
            "curl enhancing cream", "twist cream", "curl activator", "defining cream"
        ],
        
        "Mousse/Foam": [
            "mousse", "foam", "styling mousse", "curl mousse", "volumizing mousse",
            "styling foam", "curl foam", "root lift mousse"
        ],
        
        "Edge Control": [
            "edge control", "edge gel", "edge cream", "edges", "baby hair gel",
            "edge tamer", "edge smoother", "hairline control"
        ],
        
        "Heat Protectant": [
            "heat protectant", "thermal protector", "heat protection", "blow dry cream",
            "heat shield", "thermal spray", "heat defense", "blow out cream"
        ],
        
        "Scalp Treatment": [
            "scalp treatment", "scalp oil", "scalp serum", "scalp care", "scalp therapy",
            "scalp moisturizer", "anti-dandruff", "scalp scrub"
        ],
        
        "Hair Oil": [
            "hair oil", "oil", "hair serum", "treatment oil", "nourishing oil",
            "argan oil", "jojoba oil", "coconut oil", "castor oil", "growth oil"
        ]
    ]
    
    /// Special product mappings
    private static let specialRules: [String: [String]] = [
        "Gift Card": [
            "gift card", "e-gift card", "digital gift card", "gift certificate",
            "egift card", "giftcard", "gift voucher"
        ]
    ]
    
    /// Brand name variations and common misspellings
    private static let brandVariations: [String: String] = [
        "shea moisture": "SheaMoisture",
        "cantu": "Cantu",
        "carol's daughter": "Carol's Daughter",
        "carols daughter": "Carol's Daughter",
        "mielle": "Mielle",
        "pattern": "Pattern",
        "fenty": "Fenty Beauty",
        "fenty beauty": "Fenty Beauty"
    ]
    
    // MARK: - Main Classification Method
    
    /// Classifies OCR text into product type and generates search query
    /// - Parameter ocrText: Raw text from camera OCR
    /// - Returns: ClassificationResult with product type and search query
    static func classify(_ ocrText: String) -> ClassificationResult {
        let cleanedText = preprocessText(ocrText)
        
        // Try exact product type matching first
        if let result = classifyProductType(cleanedText) {
            return result
        }
        
        // Try special categories (gift cards, etc.)
        if let result = classifySpecialProducts(cleanedText) {
            return result
        }
        
        // Fallback: extract brand name or use generic search
        let fallbackQuery = extractBrandOrKeywords(cleanedText)
        return ClassificationResult(
            productType: "Other",
            queryString: fallbackQuery,
            confidence: 0.3,
            matchedKeywords: []
        )
    }
    
    // MARK: - Text Preprocessing
    
    /// Cleans and normalizes OCR text for better matching
    private static func preprocessText(_ text: String) -> String {
        var cleaned = text.lowercased()
        
        // Remove common OCR artifacts
        cleaned = cleaned.replacingOccurrences(of: "™", with: "")
        cleaned = cleaned.replacingOccurrences(of: "®", with: "")
        cleaned = cleaned.replacingOccurrences(of: "©", with: "")
        
        // Normalize whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fix common OCR mistakes
        cleaned = cleaned.replacingOccurrences(of: "sharnpoo", with: "shampoo")
        cleaned = cleaned.replacingOccurrences(of: "conditoner", with: "conditioner")
        cleaned = cleaned.replacingOccurrences(of: "moisturzer", with: "moisturizer")
        
        return cleaned
    }
    
    // MARK: - Product Type Classification
    
    /// Attempts to classify text as a specific hair care product type
    private static func classifyProductType(_ text: String) -> ClassificationResult? {
        var bestMatch: ClassificationResult?
        var highestScore = 0
        
        for (productType, keywords) in hairCareRules {
            let (score, matchedKeywords) = calculateMatchScore(text: text, keywords: keywords)
            
            if score > highestScore {
                highestScore = score
                let confidence = min(Float(score) / Float(keywords.count), 1.0)
                bestMatch = ClassificationResult(
                    productType: productType,
                    queryString: productType,
                    confidence: confidence,
                    matchedKeywords: matchedKeywords
                )
            }
        }
        
        // Only return if we have a reasonable confidence
        if highestScore > 0 {
            return bestMatch
        }
        
        return nil
    }
    
    /// Classifies special product categories like gift cards
    private static func classifySpecialProducts(_ text: String) -> ClassificationResult? {
        for (productType, keywords) in specialRules {
            let (score, matchedKeywords) = calculateMatchScore(text: text, keywords: keywords)
            
            if score > 0 {
                return ClassificationResult(
                    productType: productType,
                    queryString: productType,
                    confidence: 0.9,
                    matchedKeywords: matchedKeywords
                )
            }
        }
        
        return nil
    }
    
    /// Calculates match score based on keyword presence
    private static func calculateMatchScore(text: String, keywords: [String]) -> (score: Int, matchedKeywords: [String]) {
        var score = 0
        var matchedKeywords: [String] = []
        
        for keyword in keywords {
            if text.contains(keyword) {
                score += 1
                matchedKeywords.append(keyword)
                
                // Bonus for exact word match vs substring
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
                if text.range(of: pattern, options: .regularExpression) != nil {
                    score += 1
                }
            }
        }
        
        return (score, matchedKeywords)
    }
    
    // MARK: - Fallback Methods
    
    /// Extracts brand name or meaningful keywords when product type is unclear
    private static func extractBrandOrKeywords(_ text: String) -> String {
        // Check for known brand variations
        for (variation, canonical) in brandVariations {
            if text.contains(variation) {
                return canonical
            }
        }
        
        // Extract meaningful words (longer than 2 characters, not common stop words)
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        let stopWords = Set(["the", "and", "for", "with", "from", "hair", "care", "beauty", "product"])
        
        let meaningfulWords = words.filter { word in
            word.count > 2 && !stopWords.contains(word.lowercased()) && word.allSatisfy { $0.isLetter }
        }
        
        if !meaningfulWords.isEmpty {
            // Return first 2-3 meaningful words
            return meaningfulWords.prefix(3).joined(separator: " ")
        }
        
        // Ultimate fallback
        return "hair care"
    }
    
    // MARK: - Utility Methods
    
    /// Returns all supported product types for debugging/testing
    static var supportedProductTypes: [String] {
        return Array(hairCareRules.keys).sorted()
    }
    
    /// Tests classification with sample inputs (for development/debugging)
    static func runTests() {
        let testCases = [
            "SheaMoisture Coconut & Hibiscus Curl & Shine Shampoo",
            "Cantu Natural Hair Leave-In Conditioning Repair Cream",
            "Pattern Curl Gel Strong Hold",
            "Mielle Organics Rosemary Mint Scalp & Hair Strengthening Oil",
            "Carol's Daughter Black Vanilla Moisture & Shine Sulfate-Free Shampoo",
            "Edge Control for Natural Hair",
            "Deep Conditioning Hair Mask",
            "Gift Card $50",
            "Co-wash Cleansing Conditioner",
            "Heat Protection Spray"
        ]
        
        Log.debug("Classifier Test Results:", category: .scan)
        for testCase in testCases {
            let result = classify(testCase)
            Log.debug("Input: \(testCase)", category: .scan)
            Log.debug("Type: \(result.productType), Query: \(result.queryString), Confidence: \(result.confidence)", category: .scan)
            Log.debug("Matched: \(result.matchedKeywords)", category: .scan)
        }
    }
}
