import Foundation

/// Database of common ingredient keywords for recognition and filtering
/// Helps distinguish ingredients from product types in OCR text
class IngredientDatabase {
    
    // MARK: - Singleton
    
    static let shared = IngredientDatabase()
    
    // MARK: - Properties
    
    private let ingredients: [IngredientKeyword]
    private let ingredientsByName: [String: IngredientKeyword]
    
    // MARK: - Initialization
    
    private init() {
        self.ingredients = Self.buildIngredientDatabase()
        
        var byName: [String: IngredientKeyword] = [:]
        for ingredient in ingredients {
            byName[ingredient.name.lowercased()] = ingredient
            for variation in ingredient.variations {
                byName[variation.lowercased()] = ingredient
            }
        }
        self.ingredientsByName = byName
    }
    
    // MARK: - Public Methods
    
    /// Detect ingredients in text
    /// - Parameter text: Text to analyze
    /// - Returns: Array of detected ingredient names
    func detectIngredients(_ text: String) -> [String] {
        let lowercased = text.lowercased()
        var detected: [String] = []
        
        for ingredient in ingredients {
            // Check main name
            if lowercased.contains(ingredient.name.lowercased()) {
                detected.append(ingredient.name)
                continue
            }
            
            // Check variations
            for variation in ingredient.variations {
                if lowercased.contains(variation.lowercased()) {
                    detected.append(ingredient.name)
                    break
                }
            }
        }
        
        return Array(Set(detected))  // Remove duplicates
    }
    
    /// Check if a word is an ingredient
    /// - Parameter word: Word to check
    /// - Returns: True if ingredient
    func isIngredient(_ word: String) -> Bool {
        return ingredientsByName[word.lowercased()] != nil
    }
    
    /// Calculate ingredient clarity score
    /// Determines if product type is clear despite ingredient mentions
    /// - Parameters:
    ///   - text: Full text
    ///   - productType: Detected product type
    /// - Returns: Clarity score (0.0-1.0)
    func calculateClarityScore(text: String, productType: String) -> Double {
        let detectedIngredients = detectIngredients(text)
        
        // No ingredients mentioned = perfect clarity
        if detectedIngredients.isEmpty {
            return 1.0
        }
        
        // Product type is clear and specific (not "Other")
        if productType != "Other" && !productType.isEmpty {
            // Check if ingredients appear BEFORE product type in text
            let lowercased = text.lowercased()
            let productTypeIndex = lowercased.range(of: productType.lowercased())?.lowerBound
            
            var ingredientsAfterType = 0
            var ingredientsBeforeType = 0
            
            for ingredient in detectedIngredients {
                if let ingredientIndex = lowercased.range(of: ingredient.lowercased())?.lowerBound {
                    if let typeIndex = productTypeIndex {
                        if ingredientIndex < typeIndex {
                            ingredientsBeforeType += 1
                        } else {
                            ingredientsAfterType += 1
                        }
                    }
                }
            }
            
            // If product type appears after ingredients, it's clear
            // Example: "Coconut Oil Shampoo" - coconut is ingredient, shampoo is type
            if ingredientsBeforeType > 0 && productTypeIndex != nil {
                return 0.9
            }
            
            // Product type is specific = good clarity
            return 0.7
        }
        
        // Heavy ingredient focus (3+ ingredients)
        if detectedIngredients.count >= 3 {
            return 0.5
        }
        
        // Moderate ingredient mention (1-2 ingredients)
        if detectedIngredients.count >= 1 {
            return 0.7
        }
        
        return 0.5  // Default
    }
    
    /// Get ingredient by name
    /// - Parameter name: Ingredient name
    /// - Returns: IngredientKeyword if found
    func getIngredient(_ name: String) -> IngredientKeyword? {
        return ingredientsByName[name.lowercased()]
    }
    
    /// All supported ingredients
    var allIngredients: [String] {
        return ingredients.map { $0.name }.sorted()
    }
    
    // MARK: - Ingredient Data
    
    private static func buildIngredientDatabase() -> [IngredientKeyword] {
        return [
            // MARK: - Oils
            
            IngredientKeyword(
                name: "Coconut Oil",
                variations: ["coconut oil", "coconut", "cocos nucifera"],
                commonInProducts: ["Hair Oil", "Body Oil", "Lip Balm", "Hair Cream"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Argan Oil",
                variations: ["argan oil", "argan", "argania spinosa"],
                commonInProducts: ["Hair Oil", "Face Oil", "Hair Serum"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Jojoba Oil",
                variations: ["jojoba oil", "jojoba", "simmondsia chinensis"],
                commonInProducts: ["Hair Oil", "Face Oil", "Body Oil"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Castor Oil",
                variations: ["castor oil", "castor", "ricinus communis", "jamaican black castor oil"],
                commonInProducts: ["Hair Oil", "Growth Oil"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Olive Oil",
                variations: ["olive oil", "olive", "olea europaea"],
                commonInProducts: ["Hair Oil", "Body Oil"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Avocado Oil",
                variations: ["avocado oil", "avocado", "persea gratissima"],
                commonInProducts: ["Hair Oil", "Body Oil", "Face Oil"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Sweet Almond Oil",
                variations: ["sweet almond oil", "almond oil", "almond"],
                commonInProducts: ["Body Oil", "Hair Oil"],
                isDescriptor: true
            ),
            
            // MARK: - Butters
            
            IngredientKeyword(
                name: "Shea Butter",
                variations: ["shea butter", "shea", "butyrospermum parkii"],
                commonInProducts: ["Body Butter", "Hair Butter", "Lip Balm"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Cocoa Butter",
                variations: ["cocoa butter", "cocoa", "theobroma cacao"],
                commonInProducts: ["Body Butter", "Lip Balm", "Body Lotion"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Mango Butter",
                variations: ["mango butter", "mango", "mangifera indica"],
                commonInProducts: ["Body Butter", "Hair Butter"],
                isDescriptor: true
            ),
            
            // MARK: - Botanicals/Herbs
            
            IngredientKeyword(
                name: "Aloe Vera",
                variations: ["aloe vera", "aloe", "aloe barbadensis"],
                commonInProducts: ["Face Gel", "Body Lotion", "Hair Gel"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Tea Tree",
                variations: ["tea tree", "tea tree oil", "melaleuca"],
                commonInProducts: ["Shampoo", "Face Wash", "Body Wash"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Rose",
                variations: ["rose", "rosa", "rose water", "rosewater"],
                commonInProducts: ["Toner", "Face Mist", "Body Spray"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Lavender",
                variations: ["lavender", "lavandula"],
                commonInProducts: ["Body Lotion", "Body Oil", "Body Wash"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Chamomile",
                variations: ["chamomile", "chamomilla"],
                commonInProducts: ["Face Cream", "Body Lotion", "Shampoo"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Rosemary",
                variations: ["rosemary", "rosmarinus"],
                commonInProducts: ["Shampoo", "Hair Oil", "Scalp Treatment"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Peppermint",
                variations: ["peppermint", "mentha piperita", "mint"],
                commonInProducts: ["Shampoo", "Body Wash", "Lip Balm"],
                isDescriptor: true
            ),
            
            // MARK: - Actives/Vitamins
            
            IngredientKeyword(
                name: "Vitamin C",
                variations: ["vitamin c", "ascorbic acid", "l-ascorbic acid"],
                commonInProducts: ["Face Serum", "Face Cream"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Vitamin E",
                variations: ["vitamin e", "tocopherol"],
                commonInProducts: ["Face Cream", "Body Lotion", "Lip Balm"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Vitamin A",
                variations: ["vitamin a", "retinol", "retinyl"],
                commonInProducts: ["Face Serum", "Face Cream"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Hyaluronic Acid",
                variations: ["hyaluronic acid", "hyaluronic", "sodium hyaluronate"],
                commonInProducts: ["Face Serum", "Face Cream", "Eye Cream"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Salicylic Acid",
                variations: ["salicylic acid", "salicylic", "bha"],
                commonInProducts: ["Face Cleanser", "Toner", "Face Serum"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Glycolic Acid",
                variations: ["glycolic acid", "glycolic", "aha"],
                commonInProducts: ["Face Serum", "Toner", "Face Peel"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Niacinamide",
                variations: ["niacinamide", "vitamin b3"],
                commonInProducts: ["Face Serum", "Face Cream"],
                isDescriptor: true
            ),
            
            // MARK: - Proteins
            
            IngredientKeyword(
                name: "Keratin",
                variations: ["keratin"],
                commonInProducts: ["Hair Mask", "Shampoo", "Conditioner"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Collagen",
                variations: ["collagen"],
                commonInProducts: ["Face Cream", "Face Serum", "Eye Cream"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Biotin",
                variations: ["biotin", "vitamin h"],
                commonInProducts: ["Shampoo", "Conditioner", "Hair Vitamins"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Protein",
                variations: ["protein", "hydrolyzed protein"],
                commonInProducts: ["Hair Mask", "Conditioner"],
                isDescriptor: true
            ),
            
            // MARK: - Other Common Ingredients
            
            IngredientKeyword(
                name: "Honey",
                variations: ["honey", "mel"],
                commonInProducts: ["Face Mask", "Hair Mask", "Lip Balm"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Charcoal",
                variations: ["charcoal", "activated charcoal"],
                commonInProducts: ["Face Mask", "Face Wash", "Bar Soap"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Clay",
                variations: ["clay", "kaolin", "bentonite"],
                commonInProducts: ["Face Mask", "Hair Mask"],
                isDescriptor: true
            ),
            
            IngredientKeyword(
                name: "Oatmeal",
                variations: ["oatmeal", "oat", "avena sativa"],
                commonInProducts: ["Body Lotion", "Face Cream", "Body Wash"],
                isDescriptor: true
            ),
        ]
    }
}

// MARK: - IngredientKeyword Model

/// Represents an ingredient keyword with its metadata
struct IngredientKeyword {
    let name: String                    // Ingredient name
    let variations: [String]            // Name variations
    let commonInProducts: [String]      // Products that commonly contain this
    let isDescriptor: Bool              // True if just a descriptor, not a product type itself
}
