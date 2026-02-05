import Foundation

/// Advanced classification engine using 6-tier analysis
/// Extracts product type, form, brand, ingredients, and size from OCR text
class AdvancedClassifier {
    
    // MARK: - Singleton
    
    static let shared = AdvancedClassifier()
    
    // MARK: - Dependencies
    
    private let productTaxonomy: ProductTaxonomy
    private let formTaxonomy: FormTaxonomy
    private let brandDatabase: BrandDatabase
    private let ingredientDatabase: IngredientDatabase
    private let sizeExtractor: SizeExtractor
    
    // MARK: - Initialization
    
    init() {
        self.productTaxonomy = .shared
        self.formTaxonomy = .shared
        self.brandDatabase = .shared
        self.ingredientDatabase = .shared
        self.sizeExtractor = .shared
    }
    
    // MARK: - Main Classification Method
    
    /// Classify OCR text using 6-tier analysis
    /// - Parameter ocrText: Raw text from camera OCR
    /// - Returns: Complete classification with all 6 tiers
    func classify(_ ocrText: String) -> ScanClassification {
        // Step 1: Preprocess text
        let processed = preprocessText(ocrText)
        
        // Step 2: TIER 1 - Extract product type (MOST IMPORTANT)
        let productType = classifyProductType(processed)
        
        // Step 3: TIER 2 - Extract form (use product type for inference)
        let form = classifyForm(processed, productType: productType.type)
        
        // Step 4: TIER 3 - Detect brand
        let brand = detectBrand(processed)
        
        // Step 5: TIER 4 - Analyze ingredients
        let (ingredients, clarity) = analyzeIngredients(processed, productType: productType.type)
        
        // Step 6: TIER 5 - Extract size
        let size = extractSize(processed)
        
        return ScanClassification(
            productType: productType,
            form: form,
            brand: brand,
            ingredients: ingredients,
            ingredientClarity: clarity,
            size: size,
            rawText: ocrText,
            processedText: processed,
            timestamp: Date()
        )
    }
    
    // MARK: - TIER 1: Product Type Classification
    
    /// Classify product type from text
    /// - Parameter text: Preprocessed text
    /// - Returns: Product type result with confidence
    private func classifyProductType(_ text: String) -> ProductTypeResult {
        // Use taxonomy to find best match
        if let match = productTaxonomy.findBestMatch(text) {
            return ProductTypeResult(
                type: match.type.canonical,
                confidence: match.confidence,
                matchedKeywords: match.type.keywords.filter { text.lowercased().contains($0.lowercased()) },
                category: match.type.category,
                subcategory: match.type.subcategory
            )
        }
        
        // Fallback: try to extract meaningful words
        let fallbackType = extractFallbackType(text)
        return ProductTypeResult(
            type: fallbackType,
            confidence: 0.3,
            matchedKeywords: [],
            category: nil,
            subcategory: nil
        )
    }
    
    private func extractFallbackType(_ text: String) -> String {
        // Extract capitalized words or meaningful phrases
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        let meaningfulWords = words.filter { word in
            word.count > 3 && word.allSatisfy { $0.isLetter || $0.isNumber }
        }
        
        if !meaningfulWords.isEmpty {
            return meaningfulWords.prefix(2).joined(separator: " ")
        }
        
        return "Other"
    }
    
    // MARK: - TIER 2: Form Classification
    
    /// Classify form/dispensing method
    /// - Parameters:
    ///   - text: Preprocessed text
    ///   - productType: Detected product type (for inference)
    /// - Returns: Form result or nil
    private func classifyForm(_ text: String, productType: String?) -> FormResult? {
        // Try explicit detection first
        if let extracted = formTaxonomy.extractForm(text) {
            return FormResult(
                form: extracted.form,
                confidence: extracted.confidence,
                source: .explicit
            )
        }
        
        // Try inference from product type
        if let productType = productType,
           let inferred = formTaxonomy.inferForm(productType: productType, productName: text) {
            return FormResult(
                form: inferred,
                confidence: 0.7,
                source: .inferred
            )
        }
        
        return FormResult(
            form: "other",
            confidence: 0.5,
            source: .unknown
        )
    }
    
    // MARK: - TIER 3: Brand Detection
    
    /// Detect brand from text
    /// - Parameter text: Preprocessed text
    /// - Returns: Brand result or nil
    private func detectBrand(_ text: String) -> BrandResult? {
        guard let brand = brandDatabase.detectBrand(text) else {
            return nil
        }
        
        return BrandResult(
            name: brand.name,
            positioning: brand.positioning,
            categories: brand.categories,
            confidence: brand.confidence
        )
    }
    
    // MARK: - TIER 4: Ingredient Analysis
    
    /// Analyze ingredients in text
    /// - Parameters:
    ///   - text: Preprocessed text
    ///   - productType: Detected product type
    /// - Returns: Tuple of (ingredients, clarity score)
    private func analyzeIngredients(_ text: String, productType: String) -> ([String], Double) {
        let ingredients = ingredientDatabase.detectIngredients(text)
        let clarity = ingredientDatabase.calculateClarityScore(text: text, productType: productType)
        
        return (ingredients, clarity)
    }
    
    // MARK: - TIER 5: Size Extraction
    
    /// Extract size from text
    /// - Parameter text: Preprocessed text
    /// - Returns: Product size or nil
    private func extractSize(_ text: String) -> ProductSize? {
        return sizeExtractor.extractSize(text)
    }
    
    // MARK: - Text Preprocessing
    
    /// Preprocess OCR text for better matching
    /// - Parameter text: Raw OCR text
    /// - Returns: Cleaned text
    private func preprocessText(_ text: String) -> String {
        var cleaned = text
        
        // Remove trademark symbols
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
        cleaned = cleaned.replacingOccurrences(of: "cleansr", with: "cleanser")
        
        return cleaned
    }
}

// MARK: - Classification Result Models

/// Complete scan classification with all 6 tiers
struct ScanClassification {
    // Tier 1: Product Type
    let productType: ProductTypeResult
    
    // Tier 2: Form
    let form: FormResult?
    
    // Tier 3: Brand
    let brand: BrandResult?
    
    // Tier 4: Ingredients
    let ingredients: [String]
    let ingredientClarity: Double
    
    // Tier 5: Size
    let size: ProductSize?
    
    // Raw data
    let rawText: String
    let processedText: String
    let timestamp: Date
    
    // Computed properties
    var inferredMainCategory: String {
        if let category = productType.category {
            return category
        }
        
        // Fallback based on brand
        if let brand = brand {
            return brand.categories.first ?? "Beauty & Personal Care"
        }
        
        return "Beauty & Personal Care"
    }
    
    var searchQuery: String {
        buildOptimizedSearchQuery()
    }
    
    // Build search query string
    private func buildOptimizedSearchQuery() -> String {
        var queryTerms: [String] = []
        
        // Primary: Product type
        queryTerms.append(productType.type)
        
        // Secondary: Form (if confident)
        if let form = form, form.confidence > 0.7 {
            queryTerms.append(form.form)
        }
        
        // Tertiary: Category
        if let category = productType.category {
            queryTerms.append(category.lowercased())
        }
        
        return queryTerms.joined(separator: " ")
    }
}

/// Product type classification result
struct ProductTypeResult {
    let type: String              // Canonical product type
    let confidence: Double        // 0.0-1.0
    let matchedKeywords: [String] // Keywords found in text
    let category: String?         // Main category
    let subcategory: String?      // Subcategory
}

/// Form/dispensing method result
struct FormResult {
    let form: String              // Canonical form name
    let confidence: Double        // 0.0-1.0
    let source: FormSource        // How it was determined
}

/// How form was determined
enum FormSource {
    case explicit      // Found explicitly in text
    case inferred      // Inferred from product type
    case unknown       // Could not determine
}

/// Brand detection result
struct BrandResult {
    let name: String              // Brand name
    let positioning: BrandPositioning
    let categories: [String]      // Brand's product categories
    let confidence: Double        // Detection confidence
}
