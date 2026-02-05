import Foundation

/// Master product taxonomy with normalized types, variations, and synonyms
/// Provides canonical product type names and fuzzy matching capabilities
class ProductTaxonomy {
    
    // MARK: - Singleton
    
    static let shared = ProductTaxonomy()
    
    // MARK: - Properties
    
    private let types: [ProductType]
    private let typesByCanonical: [String: ProductType]
    private let typesByCategory: [String: [ProductType]]
    
    // MARK: - Initialization
    
    private init() {
        self.types = Self.buildTaxonomy()
        
        // Build lookup dictionaries
        var byCanonical: [String: ProductType] = [:]
        var byCategory: [String: [ProductType]] = [:]
        
        for type in types {
            byCanonical[type.canonical.lowercased()] = type
            
            let category = type.category.lowercased()
            if byCategory[category] == nil {
                byCategory[category] = []
            }
            byCategory[category]?.append(type)
        }
        
        self.typesByCanonical = byCanonical
        self.typesByCategory = byCategory
    }
    
    // MARK: - Public Methods
    
    /// Normalize a product type to its canonical form
    /// - Parameter input: Raw product type string
    /// - Returns: Canonical type name, or nil if not found
    func normalize(_ input: String) -> String? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try exact match first
        if let type = typesByCanonical[lowercased] {
            return type.canonical
        }
        
        // Try variations
        for type in types {
            if type.variations.contains(where: { $0.lowercased() == lowercased }) {
                return type.canonical
            }
        }
        
        // Try synonyms
        for type in types {
            if type.synonyms.contains(where: { $0.lowercased() == lowercased }) {
                return type.canonical
            }
        }
        
        return nil
    }
    
    /// Check if two product types are synonyms
    /// - Parameters:
    ///   - type1: First type
    ///   - type2: Second type
    /// - Returns: True if they are synonyms
    func areSynonyms(_ type1: String, _ type2: String) -> Bool {
        guard let canonical1 = normalize(type1),
              let canonical2 = normalize(type2) else {
            return false
        }
        
        // Same canonical name = synonyms
        if canonical1 == canonical2 {
            return true
        }
        
        // Check if one is in the other's synonym list
        if let productType = typesByCanonical[canonical1.lowercased()] {
            return productType.synonyms.contains(where: { normalize($0) == canonical2 })
        }
        
        return false
    }
    
    /// Get product type by canonical name
    /// - Parameter canonical: Canonical type name
    /// - Returns: ProductType if found
    func getType(_ canonical: String) -> ProductType? {
        return typesByCanonical[canonical.lowercased()]
    }
    
    /// Get all product types in a category
    /// - Parameter category: Category name
    /// - Returns: Array of product types
    func getTypesInCategory(_ category: String) -> [ProductType] {
        return typesByCategory[category.lowercased()] ?? []
    }
    
    /// Get category for a product type
    /// - Parameter type: Product type string
    /// - Returns: Category name if found
    func getCategory(_ type: String) -> String? {
        guard let canonical = normalize(type),
              let productType = typesByCanonical[canonical.lowercased()] else {
            return nil
        }
        return productType.category
    }
    
    /// Find best match from OCR text using keyword detection
    /// - Parameter text: OCR text to analyze
    /// - Returns: Tuple of (ProductType, confidence) or nil
    func findBestMatch(_ text: String) -> (type: ProductType, confidence: Double)? {
        let lowercased = text.lowercased()
        var bestMatch: (type: ProductType, score: Int)?
        
        for type in types {
            var score = 0
            
            // Check keywords
            for keyword in type.keywords {
                if lowercased.contains(keyword.lowercased()) {
                    score += 2  // Keyword match
                }
            }
            
            // Check canonical name
            if lowercased.contains(type.canonical.lowercased()) {
                score += 3  // Direct match
            }
            
            // Check variations
            for variation in type.variations {
                if lowercased.contains(variation.lowercased()) {
                    score += 2
                }
            }
            
            // Update best match
            if bestMatch == nil || score > bestMatch!.score {
                if score > 0 {
                    bestMatch = (type, score)
                }
            }
        }
        
        guard let match = bestMatch else { return nil }
        
        // Calculate confidence (0.0-1.0)
        // Score of 5+ = high confidence
        let confidence = min(Double(match.score) / 5.0, 1.0)
        
        return (match.type, confidence)
    }
    
    /// Get all supported product types (canonical names)
    var allCanonicalTypes: [String] {
        return types.map { $0.canonical }.sorted()
    }
    
    // MARK: - Taxonomy Data
    
    private static func buildTaxonomy() -> [ProductType] {
        return [
            // MARK: - Hair Care Products
            
            ProductType(
                canonical: "Shampoo",
                variations: ["shampoo", "hair shampoo", "cleansing shampoo"],
                synonyms: ["Hair Cleanser", "Hair Wash"],
                category: "Hair Care",
                subcategory: "Cleansers",
                typicalForms: ["liquid", "cream", "bar"],
                keywords: ["shampoo", "cleanser", "wash", "cleansing"]
            ),
            
            ProductType(
                canonical: "Conditioner",
                variations: ["conditioner", "hair conditioner", "rinse out conditioner"],
                synonyms: ["Hair Conditioner", "Rinse-Out Conditioner"],
                category: "Hair Care",
                subcategory: "Conditioners",
                typicalForms: ["cream", "liquid"],
                keywords: ["conditioner", "conditioning", "rinse"]
            ),
            
            ProductType(
                canonical: "Leave-In Conditioner",
                variations: ["leave-in conditioner", "leave in conditioner", "leave-in", "leavein"],
                synonyms: ["Leave-In Treatment", "Daily Leave-In"],
                category: "Hair Care",
                subcategory: "Conditioners",
                typicalForms: ["liquid", "cream", "spray"],
                keywords: ["leave", "in", "conditioner", "leave-in", "leavein"]
            ),
            
            ProductType(
                canonical: "Hair Oil",
                variations: ["hair oil", "oil", "hair serum", "treatment oil"],
                synonyms: ["Hair Serum", "Growth Oil", "Scalp Oil"],
                category: "Hair Care",
                subcategory: "Treatments",
                typicalForms: ["oil"],
                keywords: ["oil", "serum", "treatment", "growth"]
            ),
            
            ProductType(
                canonical: "Hair Mask",
                variations: ["hair mask", "conditioning mask", "deep conditioning mask"],
                synonyms: ["Deep Conditioner", "Intensive Treatment", "Hair Treatment"],
                category: "Hair Care",
                subcategory: "Treatments",
                typicalForms: ["cream", "other"],
                keywords: ["mask", "deep", "treatment", "intensive", "conditioning"]
            ),
            
            ProductType(
                canonical: "Hair Cream",
                variations: ["hair cream", "curl cream", "styling cream"],
                synonyms: ["Curl Cream", "Defining Cream", "Moisturizing Cream"],
                category: "Hair Care",
                subcategory: "Styling",
                typicalForms: ["cream"],
                keywords: ["cream", "curl", "defining", "styling"]
            ),
            
            ProductType(
                canonical: "Hair Gel",
                variations: ["hair gel", "styling gel", "curl gel", "gelly"],
                synonyms: ["Styling Gel", "Curl Gel", "Defining Gel", "Edge Gel"],
                category: "Hair Care",
                subcategory: "Styling",
                typicalForms: ["gel"],
                keywords: ["gel", "gelly", "styling", "hold", "defining"]
            ),
            
            ProductType(
                canonical: "Hair Butter",
                variations: ["hair butter", "curl butter", "styling butter"],
                synonyms: ["Curl Butter", "Moisturizing Butter"],
                category: "Hair Care",
                subcategory: "Styling",
                typicalForms: ["cream", "butter"],
                keywords: ["butter", "curl", "moisturizing"]
            ),
            
            ProductType(
                canonical: "Edge Control",
                variations: ["edge control", "edge gel", "edge cream"],
                synonyms: ["Edge Gel", "Edge Tamer", "Hairline Control"],
                category: "Hair Care",
                subcategory: "Styling",
                typicalForms: ["gel", "cream"],
                keywords: ["edge", "control", "tamer", "hairline"]
            ),
            
            // MARK: - Skin Care Products
            
            ProductType(
                canonical: "Facial Cleanser",
                variations: ["facial cleanser", "face cleanser", "face wash", "facial wash"],
                synonyms: ["Face Wash", "Cleansing Gel", "Face Soap"],
                category: "Skincare",
                subcategory: "Cleansers",
                typicalForms: ["foam", "gel", "liquid", "cream"],
                keywords: ["facial", "face", "cleanser", "wash", "cleansing"]
            ),
            
            ProductType(
                canonical: "Face Serum",
                variations: ["face serum", "facial serum", "serum"],
                synonyms: ["Facial Serum", "Treatment Serum", "Anti-Aging Serum"],
                category: "Skincare",
                subcategory: "Treatments",
                typicalForms: ["liquid", "oil"],
                keywords: ["serum", "facial", "face", "treatment"]
            ),
            
            ProductType(
                canonical: "Face Cream",
                variations: ["face cream", "facial cream", "moisturizer", "facial moisturizer"],
                synonyms: ["Facial Moisturizer", "Face Moisturizer", "Day Cream", "Night Cream"],
                category: "Skincare",
                subcategory: "Moisturizers",
                typicalForms: ["cream"],
                keywords: ["cream", "moisturizer", "facial", "face"]
            ),
            
            ProductType(
                canonical: "Face Mask",
                variations: ["face mask", "facial mask", "clay mask"],
                synonyms: ["Facial Mask", "Clay Mask", "Sheet Mask"],
                category: "Skincare",
                subcategory: "Treatments",
                typicalForms: ["cream", "other"],
                keywords: ["mask", "facial", "face", "clay"]
            ),
            
            ProductType(
                canonical: "Face Oil",
                variations: ["face oil", "facial oil"],
                synonyms: ["Facial Oil", "Beauty Oil"],
                category: "Skincare",
                subcategory: "Treatments",
                typicalForms: ["oil"],
                keywords: ["oil", "facial", "face", "beauty"]
            ),
            
            ProductType(
                canonical: "Toner",
                variations: ["toner", "facial toner", "face toner"],
                synonyms: ["Facial Toner", "Balancing Toner"],
                category: "Skincare",
                subcategory: "Toners",
                typicalForms: ["liquid"],
                keywords: ["toner", "balancing", "facial"]
            ),
            
            // MARK: - Body Care Products
            
            ProductType(
                canonical: "Body Butter",
                variations: ["body butter", "body cream"],
                synonyms: ["Body Cream", "Body Moisturizer", "Moisturizing Cream"],
                category: "Body Care",
                subcategory: "Moisturizers",
                typicalForms: ["cream", "butter"],
                keywords: ["body", "butter", "cream", "moisturizer"]
            ),
            
            ProductType(
                canonical: "Body Oil",
                variations: ["body oil", "massage oil", "moisturizing oil"],
                synonyms: ["Massage Oil", "Body Serum", "Dry Oil"],
                category: "Body Care",
                subcategory: "Oils",
                typicalForms: ["oil"],
                keywords: ["body", "oil", "massage"]
            ),
            
            ProductType(
                canonical: "Body Scrub",
                variations: ["body scrub", "sugar scrub", "salt scrub"],
                synonyms: ["Exfoliating Scrub", "Body Exfoliant"],
                category: "Body Care",
                subcategory: "Exfoliants",
                typicalForms: ["cream", "gel"],
                keywords: ["scrub", "exfoliating", "sugar", "salt", "body"]
            ),
            
            ProductType(
                canonical: "Body Wash",
                variations: ["body wash", "shower gel", "body cleanser"],
                synonyms: ["Shower Gel", "Body Cleanser", "Bath Gel"],
                category: "Body Care",
                subcategory: "Cleansers",
                typicalForms: ["liquid", "gel"],
                keywords: ["body", "wash", "shower", "gel", "cleanser"]
            ),
            
            ProductType(
                canonical: "Body Lotion",
                variations: ["body lotion", "lotion", "moisturizing lotion"],
                synonyms: ["Moisturizing Lotion", "Body Moisturizer"],
                category: "Body Care",
                subcategory: "Moisturizers",
                typicalForms: ["liquid", "cream"],
                keywords: ["lotion", "body", "moisturizing"]
            ),
            
            ProductType(
                canonical: "Bar Soap",
                variations: ["bar soap", "soap bar", "natural soap"],
                synonyms: ["Soap Bar", "Bath Soap", "Body Soap"],
                category: "Body Care",
                subcategory: "Cleansers",
                typicalForms: ["bar"],
                keywords: ["bar", "soap", "bath", "body"]
            ),
            
            ProductType(
                canonical: "Deodorant",
                variations: ["deodorant", "deodorant stick", "stick deodorant"],
                synonyms: ["Deodorant Stick", "Anti-Perspirant", "Cream Deodorant"],
                category: "Body Care",
                subcategory: "Deodorants",
                typicalForms: ["stick", "cream", "spray"],
                keywords: ["deodorant", "antiperspirant", "stick"]
            ),
            
            // MARK: - Lip Care Products
            
            ProductType(
                canonical: "Lip Balm",
                variations: ["lip balm", "chapstick", "lip treatment"],
                synonyms: ["Chapstick", "Lip Moisturizer", "Lip Therapy"],
                category: "Lip Care",
                subcategory: "Balms",
                typicalForms: ["balm", "stick"],
                keywords: ["lip", "balm", "chapstick", "treatment"]
            ),
            
            ProductType(
                canonical: "Lip Gloss",
                variations: ["lip gloss", "gloss", "lip shine"],
                synonyms: ["Gloss", "Lip Shine", "Clear Gloss"],
                category: "Makeup",
                subcategory: "Lips",
                typicalForms: ["liquid", "gel"],
                keywords: ["lip", "gloss", "shine"]
            ),
            
            ProductType(
                canonical: "Lipstick",
                variations: ["lipstick", "lip color", "lip stick"],
                synonyms: ["Lip Color", "Matte Lipstick", "Liquid Lipstick"],
                category: "Makeup",
                subcategory: "Lips",
                typicalForms: ["stick", "liquid"],
                keywords: ["lipstick", "lip", "color"]
            ),
            
            // MARK: - Makeup Products
            
            ProductType(
                canonical: "Foundation",
                variations: ["foundation", "liquid foundation", "foundation cream"],
                synonyms: ["Liquid Foundation", "Face Foundation"],
                category: "Makeup",
                subcategory: "Face",
                typicalForms: ["liquid", "cream", "powder"],
                keywords: ["foundation", "face", "base"]
            ),
            
            ProductType(
                canonical: "Mascara",
                variations: ["mascara", "lash mascara"],
                synonyms: ["Lash Mascara", "Eye Mascara"],
                category: "Makeup",
                subcategory: "Eyes",
                typicalForms: ["liquid"],
                keywords: ["mascara", "lash", "eye"]
            ),
            
            ProductType(
                canonical: "Eyeshadow Palette",
                variations: ["eyeshadow palette", "eye shadow palette", "eyeshadow"],
                synonyms: ["Eye Shadow", "Eye Palette"],
                category: "Makeup",
                subcategory: "Eyes",
                typicalForms: ["powder", "cream"],
                keywords: ["eyeshadow", "eye", "shadow", "palette"]
            ),
            
            ProductType(
                canonical: "False Eyelashes",
                variations: ["false eyelashes", "fake eyelashes", "lashes"],
                synonyms: ["Fake Lashes", "Strip Lashes"],
                category: "Makeup",
                subcategory: "Eyes",
                typicalForms: ["other"],
                keywords: ["eyelashes", "lashes", "false", "fake"]
            ),
            
            // MARK: - Fragrance Products
            
            ProductType(
                canonical: "Perfume",
                variations: ["perfume", "fragrance", "cologne"],
                synonyms: ["Fragrance", "Cologne", "Scent"],
                category: "Fragrance",
                subcategory: "Perfumes",
                typicalForms: ["liquid", "spray"],
                keywords: ["perfume", "fragrance", "cologne", "scent"]
            ),
            
            ProductType(
                canonical: "Eau de Parfum",
                variations: ["eau de parfum", "edp", "parfum"],
                synonyms: ["EDP", "Parfum", "Eau de Toilette"],
                category: "Fragrance",
                subcategory: "Perfumes",
                typicalForms: ["liquid", "spray"],
                keywords: ["eau", "parfum", "edp", "fragrance"]
            ),
            
            ProductType(
                canonical: "Perfume Oil",
                variations: ["perfume oil", "fragrance oil", "roll-on perfume"],
                synonyms: ["Fragrance Oil", "Roll-On Perfume", "Perfume Roller"],
                category: "Fragrance",
                subcategory: "Oils",
                typicalForms: ["oil", "roll-on"],
                keywords: ["perfume", "oil", "fragrance", "roll"]
            ),
            
            // MARK: - Candles & Home
            
            ProductType(
                canonical: "Scented Candle",
                variations: ["scented candle", "candle", "soy candle"],
                synonyms: ["Candle", "Soy Candle", "Aromatherapy Candle"],
                category: "Home Care",
                subcategory: "Candles",
                typicalForms: ["other"],
                keywords: ["candle", "scented", "soy", "aromatherapy"]
            ),
            
            // MARK: - Supplements
            
            ProductType(
                canonical: "Vitamins",
                variations: ["vitamins", "vitamin", "supplements", "capsules"],
                synonyms: ["Supplements", "Dietary Supplement", "Hair Vitamins"],
                category: "Health & Wellness",
                subcategory: "Supplements",
                typicalForms: ["other"],
                keywords: ["vitamin", "supplement", "capsule", "dietary"]
            ),
            
            // MARK: - Gift Cards
            
            ProductType(
                canonical: "Gift Card",
                variations: ["gift card", "e-gift card", "digital gift card"],
                synonyms: ["E-Gift Card", "Gift Certificate", "Digital Gift Card"],
                category: "Gifts",
                subcategory: "Gift Cards",
                typicalForms: ["other"],
                keywords: ["gift", "card", "certificate"]
            ),
        ]
    }
}

// MARK: - ProductType Model

/// Represents a single product type with all its variations and metadata
struct ProductType {
    let canonical: String           // Canonical/normalized name
    let variations: [String]        // Common variations (e.g., case, spelling)
    let synonyms: [String]          // Synonyms (different but same meaning)
    let category: String            // Main category
    let subcategory: String         // Sub-category
    let typicalForms: [String]      // Common forms for this type
    let keywords: [String]          // Keywords for matching
}
