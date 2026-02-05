import Foundation

/// Database of non-Black-owned brands users will scan
/// Provides brand recognition and category association for better matching
class BrandDatabase {
    
    // MARK: - Singleton
    
    static let shared = BrandDatabase()
    
    // MARK: - Properties
    
    private let brands: [Brand]
    private let brandsByName: [String: Brand]
    
    // MARK: - Initialization
    
    private init() {
        self.brands = Self.buildBrandDatabase()
        
        var byName: [String: Brand] = [:]
        for brand in brands {
            byName[brand.name.lowercased()] = brand
            // Also index by variations
            for variation in brand.variations {
                byName[variation.lowercased()] = brand
            }
        }
        self.brandsByName = byName
    }
    
    // MARK: - Public Methods
    
    /// Detect brand from text
    /// - Parameter text: Text to analyze (OCR output)
    /// - Returns: Detected brand or nil
    func detectBrand(_ text: String) -> Brand? {
        let lowercased = text.lowercased()
        
        // Check each brand
        for brand in brands {
            // Check main name
            if lowercased.contains(brand.name.lowercased()) {
                return brand
            }
            
            // Check variations
            for variation in brand.variations {
                if lowercased.contains(variation.lowercased()) {
                    return brand
                }
            }
        }
        
        return nil
    }
    
    /// Get brand by name
    /// - Parameter name: Brand name
    /// - Returns: Brand if found
    func getBrand(_ name: String) -> Brand? {
        return brandsByName[name.lowercased()]
    }
    
    /// Get brand positioning
    /// - Parameter brandName: Brand name
    /// - Returns: Positioning or nil
    func getBrandPositioning(_ brandName: String) -> BrandPositioning? {
        return getBrand(brandName)?.positioning
    }
    
    /// Check if brand is in database
    /// - Parameter name: Brand name
    /// - Returns: True if known
    func isKnownBrand(_ name: String) -> Bool {
        return getBrand(name) != nil
    }
    
    /// All supported brands
    var allBrands: [Brand] {
        return brands.sorted { $0.name < $1.name }
    }
    
    // MARK: - Brand Data
    
    private static func buildBrandDatabase() -> [Brand] {
        return [
            // MARK: - Clinical/Dermatologist Brands
            
            Brand(
                name: "CeraVe",
                variations: ["cerave", "cera ve"],
                categories: ["Skincare", "Face Care", "Body Care"],
                positioning: .clinical,
                commonProducts: ["Facial Cleanser", "Moisturizer", "Body Wash", "Face Cream"],
                confidence: 0.95
            ),
            
            Brand(
                name: "Cetaphil",
                variations: ["cetaphil"],
                categories: ["Skincare", "Face Care"],
                positioning: .clinical,
                commonProducts: ["Facial Cleanser", "Moisturizer", "Body Wash"],
                confidence: 0.95
            ),
            
            Brand(
                name: "Neutrogena",
                variations: ["neutrogena"],
                categories: ["Skincare", "Face Care", "Body Care"],
                positioning: .clinical,
                commonProducts: ["Facial Cleanser", "Sunscreen", "Moisturizer", "Body Wash"],
                confidence: 0.95
            ),
            
            Brand(
                name: "La Roche-Posay",
                variations: ["la roche-posay", "la roche posay", "laroche posay"],
                categories: ["Skincare", "Face Care"],
                positioning: .clinical,
                commonProducts: ["Facial Cleanser", "Sunscreen", "Face Serum"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Vanicream",
                variations: ["vanicream", "vani cream"],
                categories: ["Skincare", "Body Care"],
                positioning: .clinical,
                commonProducts: ["Moisturizer", "Facial Cleanser"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Eucerin",
                variations: ["eucerin"],
                categories: ["Skincare", "Body Care"],
                positioning: .clinical,
                commonProducts: ["Body Lotion", "Face Cream", "Body Wash"],
                confidence: 0.90
            ),
            
            // MARK: - Mass Market Body Care
            
            Brand(
                name: "Dove",
                variations: ["dove"],
                categories: ["Body Care", "Hair Care"],
                positioning: .massMarket,
                commonProducts: ["Bar Soap", "Body Wash", "Shampoo", "Conditioner", "Deodorant"],
                confidence: 0.95
            ),
            
            Brand(
                name: "Olay",
                variations: ["olay", "oil of olay"],
                categories: ["Skincare", "Body Care"],
                positioning: .massMarket,
                commonProducts: ["Moisturizer", "Body Wash", "Face Cream"],
                confidence: 0.95
            ),
            
            Brand(
                name: "Nivea",
                variations: ["nivea"],
                categories: ["Body Care", "Skincare"],
                positioning: .massMarket,
                commonProducts: ["Body Lotion", "Face Cream", "Lip Balm"],
                confidence: 0.95
            ),
            
            Brand(
                name: "Aveeno",
                variations: ["aveeno"],
                categories: ["Body Care", "Skincare"],
                positioning: .massMarket,
                commonProducts: ["Body Lotion", "Body Wash", "Face Moisturizer"],
                confidence: 0.95
            ),
            
            Brand(
                name: "St. Ives",
                variations: ["st. ives", "st ives", "saint ives"],
                categories: ["Body Care", "Skincare"],
                positioning: .massMarket,
                commonProducts: ["Body Scrub", "Face Scrub", "Body Lotion"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Jergens",
                variations: ["jergens"],
                categories: ["Body Care"],
                positioning: .massMarket,
                commonProducts: ["Body Lotion", "Hand Lotion"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Vaseline",
                variations: ["vaseline"],
                categories: ["Body Care"],
                positioning: .massMarket,
                commonProducts: ["Petroleum Jelly", "Body Lotion", "Lip Balm"],
                confidence: 0.95
            ),
            
            Brand(
                name: "Irish Spring",
                variations: ["irish spring"],
                categories: ["Body Care"],
                positioning: .massMarket,
                commonProducts: ["Bar Soap", "Body Wash"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Dial",
                variations: ["dial"],
                categories: ["Body Care"],
                positioning: .massMarket,
                commonProducts: ["Bar Soap", "Body Wash", "Hand Soap"],
                confidence: 0.90
            ),
            
            // MARK: - Mass Market Hair Care
            
            Brand(
                name: "Pantene",
                variations: ["pantene", "pantene pro-v", "pantene pro v"],
                categories: ["Hair Care"],
                positioning: .massMarket,
                commonProducts: ["Shampoo", "Conditioner", "Hair Mask"],
                confidence: 0.95
            ),
            
            Brand(
                name: "Head & Shoulders",
                variations: ["head & shoulders", "head and shoulders", "head&shoulders"],
                categories: ["Hair Care"],
                positioning: .massMarket,
                commonProducts: ["Shampoo", "Conditioner"],
                confidence: 0.95
            ),
            
            Brand(
                name: "TRESemmé",
                variations: ["tresemme", "tresemmé", "tres emme"],
                categories: ["Hair Care"],
                positioning: .massMarket,
                commonProducts: ["Shampoo", "Conditioner", "Hair Spray"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Herbal Essences",
                variations: ["herbal essences", "herbal essence"],
                categories: ["Hair Care"],
                positioning: .massMarket,
                commonProducts: ["Shampoo", "Conditioner"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Garnier",
                variations: ["garnier", "garnier fructis"],
                categories: ["Hair Care", "Skincare"],
                positioning: .massMarket,
                commonProducts: ["Shampoo", "Conditioner", "Face Cream"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Suave",
                variations: ["suave"],
                categories: ["Hair Care", "Body Care"],
                positioning: .massMarket,
                commonProducts: ["Shampoo", "Conditioner", "Body Wash"],
                confidence: 0.90
            ),
            
            Brand(
                name: "OGX",
                variations: ["ogx", "organix"],
                categories: ["Hair Care"],
                positioning: .massMarket,
                commonProducts: ["Shampoo", "Conditioner", "Hair Oil"],
                confidence: 0.90
            ),
            
            Brand(
                name: "L'Oréal",
                variations: ["loreal", "l'oreal", "l oreal"],
                categories: ["Hair Care", "Makeup", "Skincare"],
                positioning: .massMarket,
                commonProducts: ["Shampoo", "Conditioner", "Foundation", "Lipstick"],
                confidence: 0.95
            ),
            
            // MARK: - Natural/Clean Beauty
            
            Brand(
                name: "Burt's Bees",
                variations: ["burts bees", "burt's bees"],
                categories: ["Lip Care", "Skincare", "Body Care"],
                positioning: .natural,
                commonProducts: ["Lip Balm", "Face Cream", "Body Lotion"],
                confidence: 0.95
            ),
            
            Brand(
                name: "Yes To",
                variations: ["yes to"],
                categories: ["Skincare", "Body Care"],
                positioning: .natural,
                commonProducts: ["Face Mask", "Body Wash", "Facial Cleanser"],
                confidence: 0.85
            ),
            
            Brand(
                name: "Acure",
                variations: ["acure"],
                categories: ["Skincare", "Hair Care"],
                positioning: .natural,
                commonProducts: ["Face Serum", "Shampoo", "Body Lotion"],
                confidence: 0.85
            ),
            
            // MARK: - Premium/Prestige Skincare
            
            Brand(
                name: "Drunk Elephant",
                variations: ["drunk elephant"],
                categories: ["Skincare"],
                positioning: .premium,
                commonProducts: ["Face Serum", "Moisturizer", "Facial Cleanser"],
                confidence: 0.90
            ),
            
            Brand(
                name: "The Ordinary",
                variations: ["the ordinary", "ordinary"],
                categories: ["Skincare"],
                positioning: .premium,
                commonProducts: ["Face Serum", "Face Oil", "Moisturizer"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Tatcha",
                variations: ["tatcha"],
                categories: ["Skincare"],
                positioning: .premium,
                commonProducts: ["Facial Cleanser", "Face Cream", "Face Serum"],
                confidence: 0.85
            ),
            
            Brand(
                name: "Kiehl's",
                variations: ["kiehls", "kiehl's"],
                categories: ["Skincare", "Hair Care"],
                positioning: .premium,
                commonProducts: ["Face Cream", "Face Serum", "Body Lotion"],
                confidence: 0.90
            ),
            
            // MARK: - Luxury
            
            Brand(
                name: "SK-II",
                variations: ["sk-ii", "sk2", "skii"],
                categories: ["Skincare"],
                positioning: .luxury,
                commonProducts: ["Face Serum", "Face Cream", "Toner"],
                confidence: 0.85
            ),
            
            Brand(
                name: "La Mer",
                variations: ["la mer", "lamer"],
                categories: ["Skincare"],
                positioning: .luxury,
                commonProducts: ["Face Cream", "Face Serum", "Eye Cream"],
                confidence: 0.90
            ),
            
            // MARK: - Makeup
            
            Brand(
                name: "Maybelline",
                variations: ["maybelline"],
                categories: ["Makeup"],
                positioning: .massMarket,
                commonProducts: ["Foundation", "Mascara", "Lipstick"],
                confidence: 0.95
            ),
            
            Brand(
                name: "Revlon",
                variations: ["revlon"],
                categories: ["Makeup"],
                positioning: .massMarket,
                commonProducts: ["Lipstick", "Foundation", "Mascara"],
                confidence: 0.95
            ),
            
            Brand(
                name: "CoverGirl",
                variations: ["covergirl", "cover girl"],
                categories: ["Makeup"],
                positioning: .massMarket,
                commonProducts: ["Foundation", "Mascara", "Lipstick"],
                confidence: 0.90
            ),
            
            Brand(
                name: "NYX",
                variations: ["nyx", "nyx cosmetics"],
                categories: ["Makeup"],
                positioning: .massMarket,
                commonProducts: ["Lipstick", "Eyeshadow", "Foundation"],
                confidence: 0.90
            ),
            
            Brand(
                name: "e.l.f.",
                variations: ["elf", "e.l.f", "e.l.f."],
                categories: ["Makeup"],
                positioning: .massMarket,
                commonProducts: ["Foundation", "Lipstick", "Eyeshadow"],
                confidence: 0.85
            ),
            
            Brand(
                name: "MAC",
                variations: ["mac", "mac cosmetics"],
                categories: ["Makeup"],
                positioning: .premium,
                commonProducts: ["Lipstick", "Foundation", "Eyeshadow"],
                confidence: 0.95
            ),
            
            // MARK: - Acne/Treatment
            
            Brand(
                name: "Clean & Clear",
                variations: ["clean & clear", "clean and clear"],
                categories: ["Skincare", "Face Care"],
                positioning: .massMarket,
                commonProducts: ["Facial Cleanser", "Face Scrub", "Toner"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Clearasil",
                variations: ["clearasil"],
                categories: ["Skincare"],
                positioning: .massMarket,
                commonProducts: ["Facial Cleanser", "Face Cream", "Face Scrub"],
                confidence: 0.85
            ),
            
            // MARK: - Men's Grooming
            
            Brand(
                name: "Axe",
                variations: ["axe"],
                categories: ["Men's Care", "Body Care"],
                positioning: .massMarket,
                commonProducts: ["Body Wash", "Deodorant", "Body Spray"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Old Spice",
                variations: ["old spice"],
                categories: ["Men's Care", "Body Care"],
                positioning: .massMarket,
                commonProducts: ["Deodorant", "Body Wash", "Body Spray"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Gillette",
                variations: ["gillette"],
                categories: ["Men's Care"],
                positioning: .massMarket,
                commonProducts: ["Shaving Cream", "Aftershave", "Deodorant"],
                confidence: 0.90
            ),
            
            // MARK: - Sunscreen
            
            Brand(
                name: "Coppertone",
                variations: ["coppertone"],
                categories: ["Skincare", "Sun Care"],
                positioning: .massMarket,
                commonProducts: ["Sunscreen", "Sun Lotion"],
                confidence: 0.90
            ),
            
            Brand(
                name: "Banana Boat",
                variations: ["banana boat"],
                categories: ["Skincare", "Sun Care"],
                positioning: .massMarket,
                commonProducts: ["Sunscreen", "Sun Lotion"],
                confidence: 0.90
            ),
            
            // MARK: - Baby Care
            
            Brand(
                name: "Johnson's",
                variations: ["johnson's", "johnsons", "johnson & johnson"],
                categories: ["Baby Care", "Body Care"],
                positioning: .massMarket,
                commonProducts: ["Baby Shampoo", "Baby Lotion", "Baby Wash"],
                confidence: 0.95
            ),
            
            Brand(
                name: "Aveeno Baby",
                variations: ["aveeno baby"],
                categories: ["Baby Care"],
                positioning: .massMarket,
                commonProducts: ["Baby Lotion", "Baby Wash"],
                confidence: 0.90
            ),
        ]
    }
}

// MARK: - Brand Model

/// Represents a single brand with its metadata
struct Brand {
    let name: String                    // Brand name
    let variations: [String]            // Name variations (lowercase, spacing)
    let categories: [String]            // Product categories
    let positioning: BrandPositioning   // Market positioning
    let commonProducts: [String]        // Common products from this brand
    let confidence: Double              // Detection confidence
}

// MARK: - Brand Positioning

/// Brand market positioning categories
enum BrandPositioning: String {
    case clinical          // Dermatologist-recommended (CeraVe, Neutrogena)
    case massMarket        // Mass market (Dove, Pantene)
    case natural           // Natural/clean beauty (Burt's Bees)
    case luxury            // Luxury (La Mer, SK-II)
    case premium           // Premium (Drunk Elephant, Tatcha)
}
