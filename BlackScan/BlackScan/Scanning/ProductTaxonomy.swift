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
    /// Uses word-boundary matching for single-word terms to prevent false positives
    /// (e.g., "ring" inside "covering" no longer matches Jewelry)
    /// - Parameter text: OCR text to analyze
    /// - Returns: Tuple of (ProductType, confidence) or nil
    func findBestMatch(_ text: String) -> (type: ProductType, confidence: Double)? {
        let lowercased = text.lowercased()
        // Build a set of individual words for boundary-safe single-word matching
        let wordSet = Set(lowercased.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        var bestMatch: (type: ProductType, score: Int)?
        
        /// Check if a term appears in the text using word-boundary-safe matching.
        /// Single words must be standalone tokens; multi-word phrases use substring matching.
        func textContains(_ term: String) -> Bool {
            let termLower = term.lowercased()
            if termLower.contains(" ") {
                // Multi-word phrase — substring match is fine (low false-positive risk)
                return lowercased.contains(termLower)
            } else {
                // Single word — must be a standalone word, not a substring of another
                return wordSet.contains(termLower)
            }
        }
        
        for type in types {
            var score = 0
            
            // Check keywords
            for keyword in type.keywords {
                if textContains(keyword) {
                    score += 2  // Keyword match
                }
            }
            
            // Check canonical name
            if textContains(type.canonical) {
                score += 3  // Direct match
            }
            
            // Check variations
            for variation in type.variations {
                if textContains(variation) {
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
                variations: ["shampoo", "hair shampoo", "cleansing shampoo", "clarifying shampoo", "moisturizing shampoo", "sulfate-free shampoo", "sulfate free shampoo", "color safe shampoo", "volumizing shampoo", "anti-dandruff shampoo", "dandruff shampoo", "dry shampoo"],
                synonyms: ["Hair Cleanser", "Hair Wash", "Clarifying Shampoo", "Dry Shampoo"],
                category: "Hair Care",
                subcategory: "Cleansers",
                typicalForms: ["liquid", "cream", "bar", "powder"],
                keywords: ["shampoo", "cleanser", "wash", "cleansing", "clarifying"]
            ),
            
            ProductType(
                canonical: "Conditioner",
                variations: ["conditioner", "hair conditioner", "rinse out conditioner", "rinse-out conditioner", "daily conditioner", "moisturizing conditioner", "hydrating conditioner", "detangling conditioner"],
                synonyms: ["Hair Conditioner", "Rinse-Out Conditioner", "Daily Conditioner"],
                category: "Hair Care",
                subcategory: "Conditioners",
                typicalForms: ["cream", "liquid"],
                keywords: ["conditioner", "conditioning", "rinse", "detangling"]
            ),
            
            ProductType(
                canonical: "Leave-In Conditioner",
                variations: ["leave-in conditioner", "leave in conditioner", "leave-in", "leavein", "leave-in spray", "leave-in milk", "hair milk", "moisturizing leave-in", "detangling leave-in"],
                synonyms: ["Leave-In Treatment", "Daily Leave-In", "Hair Milk", "Conditioning Milk"],
                category: "Hair Care",
                subcategory: "Conditioners",
                typicalForms: ["liquid", "cream", "spray"],
                keywords: ["leave", "in", "conditioner", "leave-in", "leavein", "milk"]
            ),
            
            ProductType(
                canonical: "Co-Wash",
                variations: ["co-wash", "co wash", "cowash", "cleansing conditioner", "conditioning cleanser", "no-poo", "no poo"],
                synonyms: ["Cleansing Conditioner", "Conditioning Cleanser", "No-Poo"],
                category: "Hair Care",
                subcategory: "Conditioners",
                typicalForms: ["cream", "liquid"],
                keywords: ["co-wash", "cowash", "cleansing", "conditioner", "no-poo"]
            ),
            
            ProductType(
                canonical: "Protein Treatment",
                variations: ["protein treatment", "protein conditioner", "protein mask", "reconstructor", "keratin treatment", "bond repair", "bond builder"],
                synonyms: ["Reconstructor", "Keratin Treatment", "Bond Repair", "Bond Builder"],
                category: "Hair Care",
                subcategory: "Treatments",
                typicalForms: ["cream", "liquid"],
                keywords: ["protein", "reconstructor", "keratin", "bond", "repair", "strengthen"]
            ),
            
            ProductType(
                canonical: "Detangler",
                variations: ["detangler", "detangling spray", "detangling cream", "knot remover", "tangle free"],
                synonyms: ["Detangling Spray", "Knot Remover", "Detangling Cream"],
                category: "Hair Care",
                subcategory: "Conditioners",
                typicalForms: ["spray", "cream", "liquid"],
                keywords: ["detangle", "detangler", "detangling", "knot", "tangle"]
            ),
            
            ProductType(
                canonical: "Hair Rinse",
                variations: ["hair rinse", "apple cider vinegar rinse", "acv rinse", "tea rinse", "herbal rinse", "clarifying rinse"],
                synonyms: ["ACV Rinse", "Apple Cider Vinegar Rinse", "Herbal Rinse"],
                category: "Hair Care",
                subcategory: "Treatments",
                typicalForms: ["liquid"],
                keywords: ["rinse", "acv", "vinegar", "herbal", "clarifying"]
            ),
            
            ProductType(
                canonical: "Hair Oil",
                variations: ["hair oil", "hair growth oil", "growth oil", "scalp oil", "hot oil", "treatment oil", "hair serum oil", "moisture oil", "nourishing hair oil", "lightweight hair oil"],
                synonyms: ["Growth Oil", "Scalp Oil", "Hot Oil", "Treatment Oil"],
                category: "Hair Care",
                subcategory: "Treatments",
                typicalForms: ["oil"],
                keywords: ["hair", "growth", "scalp", "treatment", "nourishing"]
            ),
            
            ProductType(
                canonical: "Castor Oil",
                variations: ["castor oil", "jamaican black castor oil", "jbco", "black castor oil", "haitian castor oil", "pure castor oil", "cold pressed castor oil", "organic castor oil"],
                synonyms: ["Jamaican Black Castor Oil", "JBCO", "Black Castor Oil", "Haitian Castor Oil"],
                category: "Hair Care",
                subcategory: "Oils",
                typicalForms: ["oil"],
                keywords: ["castor", "jbco", "jamaican", "haitian"]
            ),
            
            ProductType(
                canonical: "Essential Oil",
                variations: ["essential oil", "essential oils", "tea tree oil", "lavender oil", "peppermint oil", "rosemary oil", "eucalyptus oil", "lemongrass oil", "frankincense oil"],
                synonyms: ["Tea Tree Oil", "Lavender Oil", "Peppermint Oil", "Rosemary Oil", "Aromatherapy Oil"],
                category: "Body Care",
                subcategory: "Oils",
                typicalForms: ["oil"],
                keywords: ["essential", "tea tree", "lavender", "peppermint", "rosemary", "eucalyptus", "aromatherapy"]
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
                variations: ["facial cleanser", "face cleanser", "face wash", "facial wash", "foaming cleanser", "gel cleanser", "cream cleanser", "cleansing gel", "cleansing foam", "facial bar"],
                synonyms: ["Face Wash", "Cleansing Gel", "Face Soap", "Foaming Cleanser", "Facial Bar"],
                category: "Skincare",
                subcategory: "Cleansers",
                typicalForms: ["foam", "gel", "liquid", "cream", "bar"],
                keywords: ["facial", "face", "cleanser", "wash", "cleansing", "foaming"]
            ),
            
            ProductType(
                canonical: "Micellar Water",
                variations: ["micellar water", "micellar cleansing water", "micellar cleanser", "micellar solution"],
                synonyms: ["Micellar Cleanser", "Cleansing Water"],
                category: "Skincare",
                subcategory: "Cleansers",
                typicalForms: ["liquid"],
                keywords: ["micellar", "water", "cleansing"]
            ),
            
            ProductType(
                canonical: "Makeup Remover",
                variations: ["makeup remover", "make up remover", "eye makeup remover", "makeup removing", "makeup eraser"],
                synonyms: ["Eye Makeup Remover", "Makeup Eraser"],
                category: "Skincare",
                subcategory: "Cleansers",
                typicalForms: ["liquid", "wipe", "oil"],
                keywords: ["makeup", "remover", "removing", "eraser"]
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
                variations: ["face oil", "facial oil", "beauty oil", "glow oil", "face serum oil", "radiance oil", "complexion oil"],
                synonyms: ["Facial Oil", "Beauty Oil", "Glow Oil", "Radiance Oil"],
                category: "Skincare",
                subcategory: "Treatments",
                typicalForms: ["oil"],
                keywords: ["face", "facial", "beauty", "glow", "radiance", "complexion"]
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
                canonical: "Hand Sanitizer",
                variations: ["hand sanitizer", "hand sanitizer gel", "hand sanitizer spray", "foaming hand sanitizer"],
                synonyms: ["Hand Gel", "Sanitizing Gel", "Hand Cleaner"],
                category: "Body Care",
                subcategory: "Hand Care",
                typicalForms: ["gel", "liquid", "foam", "spray"],
                keywords: ["hand", "sanitizer", "sanitizing", "clean", "antibacterial", "kills germs"]
            ),
            
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
                canonical: "Body Mist",
                variations: ["body mist", "body spray", "fragrance mist", "body fragrance"],
                synonyms: ["Body Spray", "Fragrance Mist", "Moisturizing Mist"],
                category: "Body Care",
                subcategory: "Mists",
                typicalForms: ["spray", "mist"],
                keywords: ["body", "mist", "spray", "fragrance"]
            ),
            
            ProductType(
                canonical: "Cleansing Wipes",
                variations: ["cleansing wipes", "cleansing towelettes", "facial wipes", "makeup remover wipes", "face wipes", "micellar wipes"],
                synonyms: ["Facial Wipes", "Makeup Remover Wipes", "Cleansing Towelettes"],
                category: "Skincare",
                subcategory: "Cleansers",
                typicalForms: ["wipe", "towelette"],
                keywords: ["wipe", "wipes", "towelette", "towelettes", "cleansing", "remover"]
            ),
            
            ProductType(
                canonical: "Body Oil",
                variations: ["body oil", "massage oil", "moisturizing oil", "dry oil", "bath oil", "shower oil", "body glow oil", "shimmer oil", "body serum oil"],
                synonyms: ["Massage Oil", "Body Serum", "Dry Oil", "Bath Oil", "Shimmer Oil"],
                category: "Body Care",
                subcategory: "Oils",
                typicalForms: ["oil", "spray"],
                keywords: ["body", "massage", "bath", "shimmer", "glow", "moisturizing"]
            ),
            
            ProductType(
                canonical: "Cuticle Oil",
                variations: ["cuticle oil", "nail oil", "nail cuticle oil", "nail care oil"],
                synonyms: ["Nail Oil", "Nail Care Oil"],
                category: "Makeup",
                subcategory: "Nails",
                typicalForms: ["oil"],
                keywords: ["cuticle", "nail"]
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
                variations: ["body wash", "shower gel", "body cleanser", "shower cream", "bath gel", "body soap liquid", "exfoliating body wash"],
                synonyms: ["Shower Gel", "Body Cleanser", "Bath Gel", "Shower Cream"],
                category: "Body Care",
                subcategory: "Cleansers",
                typicalForms: ["liquid", "gel", "cream"],
                keywords: ["body", "wash", "shower", "gel", "cleanser", "bath"]
            ),
            
            ProductType(
                canonical: "Intimate Wash",
                variations: ["intimate wash", "feminine wash", "feminine hygiene wash", "ph balanced wash", "vaginal wash"],
                synonyms: ["Feminine Wash", "Feminine Hygiene Wash"],
                category: "Body Care",
                subcategory: "Cleansers",
                typicalForms: ["liquid", "gel", "foam"],
                keywords: ["intimate", "feminine", "hygiene", "ph"]
            ),
            
            ProductType(
                canonical: "Body Lotion",
                variations: ["body lotion", "moisturizing lotion", "moisturizing body lotion"],
                synonyms: ["Moisturizing Lotion", "Body Moisturizer"],
                category: "Body Care",
                subcategory: "Moisturizers",
                typicalForms: ["liquid", "cream"],
                keywords: ["body", "lotion", "moisturizing"]
            ),
            
            ProductType(
                canonical: "Hand Lotion",
                variations: ["hand lotion", "hand cream", "hand moisturizer", "hand and body lotion", "hand & body lotion", "moisturizing hand cream"],
                synonyms: ["Hand Cream", "Hand Moisturizer", "Hand & Body Lotion"],
                category: "Body Care",
                subcategory: "Hand Care",
                typicalForms: ["cream", "liquid"],
                keywords: ["hand", "lotion", "cream", "moisturizer"]
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
                variations: ["foundation", "liquid foundation", "foundation cream", "powder foundation", "foundation powder"],
                synonyms: ["Liquid Foundation", "Face Foundation", "Powder Foundation"],
                category: "Makeup",
                subcategory: "Face",
                typicalForms: ["liquid", "cream", "powder"],
                keywords: ["foundation", "face", "base"]
            ),
            
            ProductType(
                canonical: "Setting Powder",
                variations: ["setting powder", "loose setting powder", "pressed setting powder", "translucent powder", "translucent setting powder", "hd powder", "baking powder"],
                synonyms: ["Translucent Powder", "HD Powder", "Baking Powder"],
                category: "Makeup",
                subcategory: "Face",
                typicalForms: ["powder"],
                keywords: ["setting", "translucent", "baking", "hd", "loose"]
            ),
            
            ProductType(
                canonical: "Face Powder",
                variations: ["face powder", "pressed powder", "loose powder", "compact powder", "finishing powder", "mineral powder"],
                synonyms: ["Pressed Powder", "Finishing Powder", "Loose Powder", "Compact Powder", "Mineral Powder"],
                category: "Makeup",
                subcategory: "Face",
                typicalForms: ["powder", "compact"],
                keywords: ["powder", "pressed", "loose", "finishing", "compact", "mineral", "face"]
            ),
            
            ProductType(
                canonical: "Body Powder",
                variations: ["body powder", "talcum powder", "talc powder", "dusting powder", "baby powder"],
                synonyms: ["Talcum Powder", "Dusting Powder", "Baby Powder", "Talc-Free Powder"],
                category: "Body Care",
                subcategory: "Powders",
                typicalForms: ["powder"],
                keywords: ["body", "powder", "talc", "talcum", "dusting", "baby"]
            ),
            
            ProductType(
                canonical: "Concealer",
                variations: ["concealer", "liquid concealer", "concealer stick", "color corrector"],
                synonyms: ["Color Corrector", "Blemish Concealer"],
                category: "Makeup",
                subcategory: "Face",
                typicalForms: ["liquid", "cream", "stick"],
                keywords: ["concealer", "color", "corrector", "blemish"]
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
            
            // MARK: - Additional Makeup Products
            
            ProductType(
                canonical: "Blush",
                variations: ["blush", "liquid blush", "blush stick", "cream blush"],
                synonyms: ["Cheek Color", "Liquid Blush", "Blush Stick"],
                category: "Makeup",
                subcategory: "Face",
                typicalForms: ["powder", "liquid", "cream", "stick"],
                keywords: ["blush", "cheek", "color"]
            ),
            
            ProductType(
                canonical: "Highlighter",
                variations: ["highlighter", "face highlighter", "liquid highlighter"],
                synonyms: ["Glow", "Illuminator", "Shimmer"],
                category: "Makeup",
                subcategory: "Face",
                typicalForms: ["powder", "liquid", "cream"],
                keywords: ["highlighter", "glow", "illuminator", "shimmer"]
            ),
            
            ProductType(
                canonical: "Bronzer",
                variations: ["bronzer", "bronzing powder"],
                synonyms: ["Bronzing Powder", "Contour"],
                category: "Makeup",
                subcategory: "Face",
                typicalForms: ["powder", "cream"],
                keywords: ["bronzer", "bronzing", "contour"]
            ),
            
            ProductType(
                canonical: "Primer",
                variations: ["primer", "face primer", "makeup primer"],
                synonyms: ["Face Primer", "Makeup Base"],
                category: "Makeup",
                subcategory: "Face",
                typicalForms: ["liquid", "cream", "gel"],
                keywords: ["primer", "base", "prep"]
            ),
            
            ProductType(
                canonical: "Setting Spray",
                variations: ["setting spray", "makeup setting spray", "finishing spray", "makeup fixer", "setting mist", "fixing spray"],
                synonyms: ["Makeup Setting Spray", "Finishing Spray", "Makeup Fixer"],
                category: "Makeup",
                subcategory: "Face",
                typicalForms: ["spray", "mist"],
                keywords: ["setting", "finishing", "fixer", "fix", "set"]
            ),
            
            ProductType(
                canonical: "Eyeliner",
                variations: ["eyeliner", "eye liner", "liquid eyeliner"],
                synonyms: ["Eye Liner", "Liquid Liner", "Pencil Liner"],
                category: "Makeup",
                subcategory: "Eyes",
                typicalForms: ["liquid", "pencil", "gel"],
                keywords: ["eyeliner", "liner", "eye"]
            ),
            
            ProductType(
                canonical: "Eyeshadow",
                variations: ["eyeshadow", "eye shadow", "liquid eyeshadow"],
                synonyms: ["Eye Shadow", "Liquid Eyeshadow"],
                category: "Makeup",
                subcategory: "Eyes",
                typicalForms: ["powder", "liquid", "cream"],
                keywords: ["eyeshadow", "eye", "shadow"]
            ),
            
            ProductType(
                canonical: "Brow Gel",
                variations: ["brow gel", "eyebrow gel", "brow pomade"],
                synonyms: ["Eyebrow Gel", "Brow Pomade"],
                category: "Makeup",
                subcategory: "Eyes",
                typicalForms: ["gel", "cream"],
                keywords: ["brow", "eyebrow", "gel", "pomade"]
            ),
            
            ProductType(
                canonical: "Brow Pencil",
                variations: ["brow pencil", "eyebrow pencil", "brow pen", "eyebrow pen", "brow definer"],
                synonyms: ["Eyebrow Pencil", "Brow Pen", "Brow Definer"],
                category: "Makeup",
                subcategory: "Eyes",
                typicalForms: ["pencil", "stick"],
                keywords: ["brow", "eyebrow", "pencil", "pen", "definer"]
            ),
            
            ProductType(
                canonical: "Contour",
                variations: ["contour", "contour stick", "contour cream", "contour palette", "contour powder", "contour kit"],
                synonyms: ["Contour Stick", "Face Contour", "Sculpting Stick"],
                category: "Makeup",
                subcategory: "Face",
                typicalForms: ["stick", "cream", "powder"],
                keywords: ["contour", "sculpt", "sculpting", "define"]
            ),
            
            ProductType(
                canonical: "Lash Serum",
                variations: ["lash serum", "eyelash serum", "lash growth serum", "lash enhancer", "lash conditioner"],
                synonyms: ["Eyelash Serum", "Lash Growth Serum", "Lash Enhancer"],
                category: "Makeup",
                subcategory: "Eyes",
                typicalForms: ["liquid", "serum"],
                keywords: ["lash", "eyelash", "serum", "growth", "enhancer"]
            ),
            
            ProductType(
                canonical: "Tinted Moisturizer",
                variations: ["tinted moisturizer", "tinted moisturiser", "bb cream", "cc cream", "skin tint", "tinted cream"],
                synonyms: ["BB Cream", "CC Cream", "Skin Tint", "Tinted Cream"],
                category: "Makeup",
                subcategory: "Face",
                typicalForms: ["cream", "liquid"],
                keywords: ["tinted", "moisturizer", "bb", "cc", "tint", "skin"]
            ),
            
            ProductType(
                canonical: "Makeup Brush",
                variations: ["makeup brush", "cosmetic brush", "brush"],
                synonyms: ["Cosmetic Brush", "Beauty Brush"],
                category: "Makeup",
                subcategory: "Tools",
                typicalForms: ["other"],
                keywords: ["brush", "makeup", "cosmetic"]
            ),
            
            // MARK: - Additional Skincare Products
            
            ProductType(
                canonical: "Eye Cream",
                variations: ["eye cream", "under eye cream", "eye gel"],
                synonyms: ["Under Eye Cream", "Eye Gel", "Eye Treatment"],
                category: "Skincare",
                subcategory: "Treatments",
                typicalForms: ["cream", "gel"],
                keywords: ["eye", "cream", "under", "treatment"]
            ),
            
            ProductType(
                canonical: "Moisturizer",
                variations: ["moisturizer", "facial moisturizer", "hydrating cream"],
                synonyms: ["Hydrating Cream", "Face Cream", "Facial Moisturizer"],
                category: "Skincare",
                subcategory: "Moisturizers",
                typicalForms: ["cream", "liquid"],
                keywords: ["moisturizer", "hydrating", "facial"]
            ),
            
            ProductType(
                canonical: "Facial Mist",
                variations: ["facial mist", "face mist", "hydrating mist"],
                synonyms: ["Face Mist", "Hydrating Spray", "Facial Spray"],
                category: "Skincare",
                subcategory: "Toners",
                typicalForms: ["spray", "liquid"],
                keywords: ["mist", "spray", "facial", "face"]
            ),
            
            ProductType(
                canonical: "Facial Scrub",
                variations: ["facial scrub", "face scrub", "exfoliating scrub"],
                synonyms: ["Face Scrub", "Exfoliating Scrub", "Face Exfoliant"],
                category: "Skincare",
                subcategory: "Exfoliants",
                typicalForms: ["cream", "gel"],
                keywords: ["scrub", "exfoliating", "facial", "face"]
            ),
            
            ProductType(
                canonical: "Sunscreen",
                variations: ["sunscreen", "sun screen", "spf", "sunblock"],
                synonyms: ["Sun Protection", "SPF", "Sunblock"],
                category: "Skincare",
                subcategory: "Sun Care",
                typicalForms: ["cream", "liquid", "spray"],
                keywords: ["sunscreen", "spf", "sun", "protection"]
            ),
            
            // MARK: - Additional Body Care Products
            
            ProductType(
                canonical: "Body Balm",
                variations: ["body balm", "skin balm", "healing balm"],
                synonyms: ["Skin Balm", "Healing Balm", "Body Salve"],
                category: "Body Care",
                subcategory: "Moisturizers",
                typicalForms: ["balm", "cream"],
                keywords: ["balm", "body", "skin", "healing"]
            ),
            
            ProductType(
                canonical: "Sugar Scrub",
                variations: ["sugar scrub", "body sugar scrub"],
                synonyms: ["Body Sugar Scrub", "Sweet Scrub"],
                category: "Body Care",
                subcategory: "Exfoliants",
                typicalForms: ["cream"],
                keywords: ["sugar", "scrub", "body", "exfoliating"]
            ),
            
            ProductType(
                canonical: "Hand Soap",
                variations: ["hand soap", "foaming hand soap", "liquid hand soap", "hand wash", "foaming hand wash", "antibacterial hand soap"],
                synonyms: ["Foaming Hand Soap", "Liquid Hand Soap", "Hand Wash", "Foaming Hand Wash"],
                category: "Body Care",
                subcategory: "Hand Care",
                typicalForms: ["liquid", "foam"],
                keywords: ["hand", "soap", "foaming", "wash", "antibacterial"]
            ),
            
            ProductType(
                canonical: "Body Gloss",
                variations: ["body gloss", "shimmer oil", "glow oil"],
                synonyms: ["Shimmer Oil", "Glow Oil", "Body Shimmer"],
                category: "Body Care",
                subcategory: "Oils",
                typicalForms: ["oil", "liquid"],
                keywords: ["gloss", "shimmer", "glow", "body"]
            ),
            
            ProductType(
                canonical: "Liquid Soap",
                variations: ["liquid soap", "hand soap", "body soap"],
                synonyms: ["Hand Soap", "Body Soap", "Castile Soap"],
                category: "Body Care",
                subcategory: "Cleansers",
                typicalForms: ["liquid"],
                keywords: ["liquid", "soap", "hand", "body"]
            ),
            
            // MARK: - Men's Grooming Products
            
            ProductType(
                canonical: "Beard Oil",
                variations: ["beard oil", "facial hair oil", "beard growth oil", "beard moisturizing oil", "beard serum"],
                synonyms: ["Facial Hair Oil", "Beard Serum", "Beard Growth Oil"],
                category: "Men's Care",
                subcategory: "Beard",
                typicalForms: ["oil"],
                keywords: ["beard", "facial", "hair"]
            ),
            
            ProductType(
                canonical: "Beard Balm",
                variations: ["beard balm", "beard butter"],
                synonyms: ["Beard Butter", "Beard Cream"],
                category: "Men's Care",
                subcategory: "Beard",
                typicalForms: ["balm", "cream"],
                keywords: ["beard", "balm", "butter"]
            ),
            
            ProductType(
                canonical: "Beard Conditioner",
                variations: ["beard conditioner", "beard softener"],
                synonyms: ["Beard Softener", "Beard Wash"],
                category: "Men's Care",
                subcategory: "Beard",
                typicalForms: ["liquid", "cream"],
                keywords: ["beard", "conditioner", "softener", "wash"]
            ),
            
            // MARK: - Nail Care Products
            
            ProductType(
                canonical: "Nail Polish",
                variations: ["nail polish", "nail lacquer", "nail color"],
                synonyms: ["Nail Lacquer", "Nail Color", "Nail Varnish"],
                category: "Makeup",
                subcategory: "Nails",
                typicalForms: ["liquid"],
                keywords: ["nail", "polish", "lacquer", "color"]
            ),
            
            ProductType(
                canonical: "Gel Polish",
                variations: ["gel polish", "gel nail polish"],
                synonyms: ["Gel Nail Polish", "UV Gel"],
                category: "Makeup",
                subcategory: "Nails",
                typicalForms: ["gel"],
                keywords: ["gel", "polish", "nail", "uv"]
            ),
            
            // MARK: - Lip Care & Makeup
            
            ProductType(
                canonical: "Lip Scrub",
                variations: ["lip scrub", "lip exfoliant"],
                synonyms: ["Lip Exfoliant", "Lip Polish"],
                category: "Lip Care",
                subcategory: "Treatments",
                typicalForms: ["scrub"],
                keywords: ["lip", "scrub", "exfoliant", "polish"]
            ),
            
            ProductType(
                canonical: "Lip Liner",
                variations: ["lip liner", "lip pencil", "lipliner", "lip line"],
                synonyms: ["Lip Pencil", "Lip Line Pencil"],
                category: "Makeup",
                subcategory: "Lips",
                typicalForms: ["pencil", "stick"],
                keywords: ["lip", "liner", "pencil", "line"]
            ),
            
            ProductType(
                canonical: "Lip Oil",
                variations: ["lip oil", "lip treatment oil", "lip glow oil"],
                synonyms: ["Lip Treatment Oil", "Lip Glow Oil", "Hydrating Lip Oil"],
                category: "Lip Care",
                subcategory: "Treatments",
                typicalForms: ["oil", "liquid"],
                keywords: ["lip", "oil", "glow", "hydrating"]
            ),
            
            ProductType(
                canonical: "Liquid Lipstick",
                variations: ["liquid lipstick", "liquid lip", "lip liquid"],
                synonyms: ["Liquid Lip", "Matte Liquid Lipstick"],
                category: "Makeup",
                subcategory: "Lips",
                typicalForms: ["liquid"],
                keywords: ["liquid", "lipstick", "lip", "matte"]
            ),
            
            // MARK: - Additional Hair Care Products
            
            ProductType(
                canonical: "Deep Conditioner",
                variations: ["deep conditioner", "deep conditioning treatment", "deep conditioning masque", "deep conditioning mask", "deep treatment", "intensive conditioner", "moisture treatment", "hot oil treatment"],
                synonyms: ["Deep Conditioning Treatment", "Intensive Conditioner", "Hair Treatment", "Deep Conditioning Masque", "Hot Oil Treatment"],
                category: "Hair Care",
                subcategory: "Treatments",
                typicalForms: ["cream", "other"],
                keywords: ["deep", "conditioner", "treatment", "intensive", "masque", "moisture"]
            ),
            
            ProductType(
                canonical: "Hair Serum",
                variations: ["hair serum", "hair treatment serum"],
                synonyms: ["Hair Treatment Serum", "Shine Serum"],
                category: "Hair Care",
                subcategory: "Treatments",
                typicalForms: ["liquid", "oil"],
                keywords: ["serum", "hair", "treatment", "shine"]
            ),
            
            ProductType(
                canonical: "Styling Gel",
                variations: ["styling gel", "hair styling gel"],
                synonyms: ["Hair Gel", "Firm Hold Gel"],
                category: "Hair Care",
                subcategory: "Styling",
                typicalForms: ["gel"],
                keywords: ["styling", "gel", "hold", "hair"]
            ),
            
            ProductType(
                canonical: "Hair Balm",
                variations: ["hair balm", "styling balm"],
                synonyms: ["Styling Balm", "Hair Wax"],
                category: "Hair Care",
                subcategory: "Styling",
                typicalForms: ["balm", "cream"],
                keywords: ["balm", "hair", "styling", "wax"]
            ),
            
            ProductType(
                canonical: "Curl Cream",
                variations: ["curl cream", "curling cream", "curl defining cream"],
                synonyms: ["Curling Cream", "Curl Defining Cream", "Curl Enhancer"],
                category: "Hair Care",
                subcategory: "Styling",
                typicalForms: ["cream"],
                keywords: ["curl", "cream", "defining", "curling"]
            ),
            
            ProductType(
                canonical: "Hair Spray",
                variations: ["hair spray", "hairspray", "finishing spray", "hold spray", "flexible hold spray", "volumizing spray"],
                synonyms: ["Hairspray", "Finishing Spray", "Hold Spray", "Volumizing Spray"],
                category: "Hair Care",
                subcategory: "Styling",
                typicalForms: ["spray", "aerosol"],
                keywords: ["hair", "spray", "hairspray", "hold", "finishing", "volumizing"]
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
            
            // MARK: - Clothing & Apparel
            
            ProductType(
                canonical: "Dress",
                variations: ["dress", "maxi dress", "mini dress", "midi dress", "wedding dress", "gown", "evening gown", "kaftan", "kaftan dress", "shirt dress", "wrap dress", "strapless dress", "bandeau dress", "t-shirt dress", "jumpsuit dress", "romper", "playsuit"],
                synonyms: ["Gown", "Frock", "Sundress"],
                category: "Clothing",
                subcategory: "Dresses",
                typicalForms: ["other"],
                keywords: ["dress", "gown", "maxi", "mini", "midi", "wedding", "evening", "kaftan", "romper"]
            ),
            
            ProductType(
                canonical: "T-Shirt",
                variations: ["t-shirt", "tee", "tshirt", "top", "shirt", "tank top", "crop top", "baby tee", "athletic shirt", "blouse", "tunic"],
                synonyms: ["Tee", "Top", "Shirt"],
                category: "Clothing",
                subcategory: "Tops",
                typicalForms: ["other"],
                keywords: ["shirt", "tee", "t-shirt", "top", "blouse", "tank", "crop"]
            ),
            
            ProductType(
                canonical: "Pants",
                variations: ["pants", "trousers", "joggers", "sweatpants", "leggings", "wide-leg pants", "palazzo pants", "track pants"],
                synonyms: ["Trousers", "Slacks", "Bottoms"],
                category: "Clothing",
                subcategory: "Bottoms",
                typicalForms: ["other"],
                keywords: ["pants", "trousers", "joggers", "sweatpants", "leggings"]
            ),
            
            ProductType(
                canonical: "Shorts",
                variations: ["shorts", "biker shorts", "bike shorts", "athletic shorts", "booty shorts", "boxer shorts"],
                synonyms: ["Short Pants", "Bottoms"],
                category: "Clothing",
                subcategory: "Bottoms",
                typicalForms: ["other"],
                keywords: ["shorts", "short", "biker", "athletic"]
            ),
            
            ProductType(
                canonical: "Swimwear",
                variations: ["bikini", "swimsuit", "one-piece swimsuit", "bikini top", "bikini bottom", "bikini set", "monokini", "tankini", "swim trunks", "swim shorts"],
                synonyms: ["Swimsuit", "Bathing Suit", "Bikini"],
                category: "Clothing",
                subcategory: "Swimwear",
                typicalForms: ["other"],
                keywords: ["bikini", "swimsuit", "swim", "bathing", "one-piece", "tankini", "monokini"]
            ),
            
            ProductType(
                canonical: "Jacket",
                variations: ["jacket", "blazer", "hoodie", "sweatshirt", "bomber jacket", "coat", "cardigan", "kimono", "robe"],
                synonyms: ["Coat", "Outerwear", "Blazer"],
                category: "Clothing",
                subcategory: "Outerwear",
                typicalForms: ["other"],
                keywords: ["jacket", "blazer", "hoodie", "sweatshirt", "coat", "bomber", "cardigan"]
            ),
            
            ProductType(
                canonical: "Underwear",
                variations: ["underwear", "panties", "briefs", "thong", "boyshorts", "bikini panty", "bra", "bralette", "lingerie", "lingerie set", "bodysuit"],
                synonyms: ["Lingerie", "Intimates", "Undergarments"],
                category: "Clothing",
                subcategory: "Intimates",
                typicalForms: ["other"],
                keywords: ["underwear", "panties", "bra", "lingerie", "thong", "briefs", "bralette"]
            ),
            
            ProductType(
                canonical: "Activewear",
                variations: ["activewear", "sports bra", "athletic wear", "yoga pants", "gym shorts", "workout top", "leggings"],
                synonyms: ["Athletic Wear", "Sportswear", "Gym Wear"],
                category: "Clothing",
                subcategory: "Activewear",
                typicalForms: ["other"],
                keywords: ["activewear", "sports", "athletic", "yoga", "workout", "gym"]
            ),
            
            // MARK: - Accessories
            
            ProductType(
                canonical: "Handbag",
                variations: ["handbag", "bag", "purse", "tote bag", "shoulder bag", "clutch", "crossbody bag", "satchel", "backpack", "duffle bag", "messenger bag", "belt bag", "fanny pack", "bolo bag"],
                synonyms: ["Purse", "Bag", "Tote"],
                category: "Accessories",
                subcategory: "Bags",
                typicalForms: ["other"],
                keywords: ["bag", "handbag", "purse", "tote", "clutch", "backpack", "crossbody", "shoulder"]
            ),
            
            ProductType(
                canonical: "Jewelry",
                variations: ["necklace", "bracelet", "earrings", "ring", "anklet", "choker", "pendant", "charm", "brooch", "cufflinks"],
                synonyms: ["Jewellery", "Accessory"],
                category: "Accessories",
                subcategory: "Jewelry",
                typicalForms: ["other"],
                keywords: ["necklace", "bracelet", "earrings", "ring", "jewelry", "jewellery", "pendant", "charm"]
            ),
            
            ProductType(
                canonical: "Hat",
                variations: ["hat", "beanie", "cap", "baseball cap", "sun hat", "fedora", "bucket hat", "headwrap", "head wrap", "turban", "bonnet"],
                synonyms: ["Cap", "Headwear", "Head Covering"],
                category: "Accessories",
                subcategory: "Headwear",
                typicalForms: ["other"],
                keywords: ["hat", "cap", "beanie", "headwrap", "bonnet", "turban"]
            ),
            
            ProductType(
                canonical: "Sunglasses",
                variations: ["sunglasses", "shades", "eyewear", "sunnies"],
                synonyms: ["Shades", "Eyewear"],
                category: "Accessories",
                subcategory: "Eyewear",
                typicalForms: ["other"],
                keywords: ["sunglasses", "shades", "eyewear", "glasses"]
            ),
            
            ProductType(
                canonical: "Scarf",
                variations: ["scarf", "shawl", "wrap", "sarong", "pashmina"],
                synonyms: ["Shawl", "Wrap"],
                category: "Accessories",
                subcategory: "Scarves",
                typicalForms: ["other"],
                keywords: ["scarf", "shawl", "wrap", "sarong"]
            ),
            
            // MARK: - Baby & Kids
            
            ProductType(
                canonical: "Baby Clothing",
                variations: ["baby bodysuit", "baby romper", "baby dress", "baby shirt", "baby pants", "baby onesie", "baby bloomers", "baby bib", "baby hat"],
                synonyms: ["Infant Clothing", "Baby Wear"],
                category: "Baby & Kids",
                subcategory: "Clothing",
                typicalForms: ["other"],
                keywords: ["baby", "infant", "bodysuit", "romper", "onesie", "bib"]
            ),
            
            ProductType(
                canonical: "Baby Lotion",
                variations: ["baby lotion", "baby moisturizer", "baby cream", "baby balm", "infant lotion"],
                synonyms: ["Infant Lotion", "Baby Moisturizer", "Baby Cream"],
                category: "Baby & Kids",
                subcategory: "Skincare",
                typicalForms: ["cream", "lotion"],
                keywords: ["baby", "infant", "lotion", "moisturizer", "cream", "balm"]
            ),
            
            ProductType(
                canonical: "Baby Wash",
                variations: ["baby wash", "baby shampoo", "baby soap", "baby body wash", "infant wash", "baby bath"],
                synonyms: ["Infant Wash", "Baby Shampoo", "Baby Soap", "Baby Bath"],
                category: "Baby & Kids",
                subcategory: "Skincare",
                typicalForms: ["liquid", "gel"],
                keywords: ["baby", "infant", "wash", "shampoo", "soap", "bath"]
            ),
            
            ProductType(
                canonical: "Baby Oil",
                variations: ["baby oil", "infant oil", "baby massage oil"],
                synonyms: ["Infant Oil", "Baby Massage Oil"],
                category: "Baby & Kids",
                subcategory: "Skincare",
                typicalForms: ["oil"],
                keywords: ["baby", "infant", "oil", "massage"]
            ),
            
            ProductType(
                canonical: "Baby Skincare",
                variations: ["baby skincare", "baby skin care", "baby sunscreen", "baby diaper cream"],
                synonyms: ["Infant Care", "Baby Care"],
                category: "Baby & Kids",
                subcategory: "Skincare",
                typicalForms: ["cream", "oil", "liquid"],
                keywords: ["baby", "infant", "care", "skincare"]
            ),
            
            // MARK: - Pet Products
            
            ProductType(
                canonical: "Pet Accessories",
                variations: ["dog collar", "pet collar", "dog leash", "pet leash", "dog bow tie", "pet bow tie", "dog bandana", "pet clothing"],
                synonyms: ["Pet Gear", "Dog Accessories"],
                category: "Pet Supplies",
                subcategory: "Accessories",
                typicalForms: ["other"],
                keywords: ["dog", "pet", "collar", "leash", "bow tie", "bandana"]
            ),
            
            ProductType(
                canonical: "Pet Food",
                variations: ["dog food", "pet food", "dog treats", "pet treats", "cat food", "pet snacks"],
                synonyms: ["Dog Food", "Pet Nutrition"],
                category: "Pet Supplies",
                subcategory: "Food",
                typicalForms: ["other"],
                keywords: ["dog", "pet", "food", "treats", "cat"]
            ),
            
            ProductType(
                canonical: "Pet Toys",
                variations: ["dog toy", "pet toy", "chew toy", "tennis ball", "pet chew"],
                synonyms: ["Dog Toys", "Pet Entertainment"],
                category: "Pet Supplies",
                subcategory: "Toys",
                typicalForms: ["other"],
                keywords: ["dog", "pet", "toy", "ball", "chew"]
            ),
            
            // MARK: - Home & Lifestyle
            
            ProductType(
                canonical: "Book",
                variations: ["book", "paperback", "hardcover", "ebook", "novel", "guide", "cookbook", "coloring book", "activity book"],
                synonyms: ["Novel", "Publication", "Literature"],
                category: "Home & Lifestyle",
                subcategory: "Books",
                typicalForms: ["other"],
                keywords: ["book", "paperback", "hardcover", "novel", "guide"]
            ),
            
            ProductType(
                canonical: "Home Decor",
                variations: ["wall art", "print", "poster", "picture frame", "mirror", "vase", "decorative item", "sculpture"],
                synonyms: ["Decoration", "Wall Art"],
                category: "Home & Lifestyle",
                subcategory: "Decor",
                typicalForms: ["other"],
                keywords: ["art", "wall", "decor", "poster", "print", "frame"]
            ),
            
            ProductType(
                canonical: "Puzzle",
                variations: ["jigsaw puzzle", "puzzle", "game"],
                synonyms: ["Jigsaw", "Board Game"],
                category: "Home & Lifestyle",
                subcategory: "Games",
                typicalForms: ["other"],
                keywords: ["puzzle", "jigsaw", "game"]
            ),
            
            ProductType(
                canonical: "Water Bottle",
                variations: ["water bottle", "bottle", "tumbler", "flask", "insulated bottle"],
                synonyms: ["Tumbler", "Drinkware"],
                category: "Home & Lifestyle",
                subcategory: "Drinkware",
                typicalForms: ["other"],
                keywords: ["water", "bottle", "tumbler", "flask"]
            ),
            
            // MARK: - Food & Supplements
            
            ProductType(
                canonical: "Dietary Supplements",
                variations: ["protein powder", "supplement powder", "meal replacement", "collagen powder", "gummy vitamins", "supplement capsules", "dietary supplement"],
                synonyms: ["Supplements", "Nutrition Powder"],
                category: "Health & Wellness",
                subcategory: "Supplements",
                typicalForms: ["powder", "other"],
                keywords: ["protein", "supplement", "powder", "vitamins", "gummy", "collagen", "meal replacement"]
            ),
            
            ProductType(
                canonical: "Tea",
                variations: ["tea", "herbal tea", "black tea", "green tea", "tea blend"],
                synonyms: ["Herbal Tea", "Tea Blend"],
                category: "Food & Beverage",
                subcategory: "Beverages",
                typicalForms: ["other"],
                keywords: ["tea", "herbal", "blend", "beverage"]
            ),
            
            // MARK: - Household & Cleaning
            
            ProductType(
                canonical: "Multi-Purpose Cleaner",
                variations: ["multi-purpose cleaner", "multi purpose cleaner", "all-purpose cleaner", "all purpose cleaner", "multipurpose cleaner", "surface cleaner", "multi-surface cleaner", "household cleaner"],
                synonyms: ["All-Purpose Cleaner", "Surface Cleaner", "Household Cleaner"],
                category: "Home Care",
                subcategory: "Cleaning",
                typicalForms: ["liquid", "spray"],
                keywords: ["multi", "purpose", "surface", "all-purpose", "cleaner", "clean", "household"]
            ),
            
            ProductType(
                canonical: "Glass Cleaner",
                variations: ["glass cleaner", "window cleaner", "mirror cleaner"],
                synonyms: ["Window Cleaner"],
                category: "Home Care",
                subcategory: "Cleaning",
                typicalForms: ["spray", "liquid"],
                keywords: ["glass", "window", "mirror", "streak"]
            ),
            
            ProductType(
                canonical: "Floor Cleaner",
                variations: ["floor cleaner", "floor wash", "mopping solution"],
                synonyms: ["Floor Wash", "Mopping Solution"],
                category: "Home Care",
                subcategory: "Cleaning",
                typicalForms: ["liquid"],
                keywords: ["floor", "mop", "mopping"]
            ),
            
            ProductType(
                canonical: "Dish Soap",
                variations: ["dish soap", "dish detergent", "dish liquid", "dishwashing liquid", "dish wash"],
                synonyms: ["Dish Detergent", "Dishwashing Liquid"],
                category: "Home Care",
                subcategory: "Cleaning",
                typicalForms: ["liquid", "gel"],
                keywords: ["dish", "dishwashing", "dishes"]
            ),
            
            ProductType(
                canonical: "Laundry Detergent",
                variations: ["laundry detergent", "laundry soap", "washing powder", "fabric wash", "laundry pods"],
                synonyms: ["Laundry Soap", "Fabric Wash", "Washing Powder"],
                category: "Home Care",
                subcategory: "Laundry",
                typicalForms: ["liquid", "powder", "other"],
                keywords: ["laundry", "detergent", "fabric", "washing"]
            ),
            
            ProductType(
                canonical: "Fabric Softener",
                variations: ["fabric softener", "fabric conditioner", "dryer sheets"],
                synonyms: ["Fabric Conditioner", "Dryer Sheets"],
                category: "Home Care",
                subcategory: "Laundry",
                typicalForms: ["liquid", "other"],
                keywords: ["fabric", "softener", "dryer", "sheets"]
            ),
            
            ProductType(
                canonical: "Disinfectant",
                variations: ["disinfectant", "disinfecting spray", "disinfecting wipes", "sanitizing spray"],
                synonyms: ["Sanitizing Spray", "Disinfecting Spray"],
                category: "Home Care",
                subcategory: "Cleaning",
                typicalForms: ["spray", "wipe", "liquid"],
                keywords: ["disinfect", "sanitize", "antibacterial", "germ"]
            ),
            
            ProductType(
                canonical: "Batteries",
                variations: ["battery", "batteries", "aa batteries", "aaa batteries", "rechargeable battery", "9v battery"],
                synonyms: ["Power Cells", "Battery Pack"],
                category: "Electronics",
                subcategory: "Batteries",
                typicalForms: ["other"],
                keywords: ["battery", "batteries", "rechargeable", "power"]
            ),
            
            ProductType(
                canonical: "Toilet Paper",
                variations: ["toilet paper", "tissue", "bath tissue"],
                synonyms: ["Bath Tissue", "TP"],
                category: "Home Care",
                subcategory: "Paper Products",
                typicalForms: ["other"],
                keywords: ["toilet", "paper", "tissue", "bath"]
            ),
            
            // MARK: - Electronics & Tech
            
            ProductType(
                canonical: "Phone Accessories",
                variations: ["phone case", "airpods case", "phone mount", "screen protector", "phone charger"],
                synonyms: ["Mobile Accessories", "Phone Case"],
                category: "Electronics",
                subcategory: "Accessories",
                typicalForms: ["other"],
                keywords: ["phone", "case", "airpods", "mobile", "charger", "screen"]
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
