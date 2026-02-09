import Foundation

/// Form/dispensing method taxonomy with normalization and compatibility rules
/// Handles product dispensing forms (liquid, cream, spray, etc.)
class FormTaxonomy {
    
    // MARK: - Singleton
    
    static let shared = FormTaxonomy()
    
    // MARK: - Properties
    
    private let forms: [FormType]
    private let formsByCanonical: [String: FormType]
    
    // MARK: - Initialization
    
    private init() {
        self.forms = Self.buildFormTaxonomy()
        
        var byCanonical: [String: FormType] = [:]
        for form in forms {
            byCanonical[form.canonical.lowercased()] = form
        }
        self.formsByCanonical = byCanonical
    }
    
    // MARK: - Public Methods
    
    /// Normalize form to canonical name
    /// - Parameter input: Raw form string
    /// - Returns: Canonical form name or nil
    func normalize(_ input: String) -> String? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try exact match
        if let form = formsByCanonical[lowercased] {
            return form.canonical
        }
        
        // Try variations
        for form in forms {
            if form.variations.contains(where: { $0.lowercased() == lowercased }) {
                return form.canonical
            }
        }
        
        return nil
    }
    
    /// Check if two forms are compatible
    /// - Parameters:
    ///   - form1: First form
    ///   - form2: Second form
    /// - Returns: True if compatible
    func areCompatible(_ form1: String, _ form2: String) -> Bool {
        guard let canonical1 = normalize(form1),
              let canonical2 = normalize(form2) else {
            return false
        }
        
        // Same form = compatible
        if canonical1 == canonical2 {
            return true
        }
        
        // Check compatibility list
        if let formType = formsByCanonical[canonical1.lowercased()] {
            return formType.compatibleForms.contains(canonical2)
        }
        
        return false
    }
    
    /// Infer form from product type and name
    /// - Parameters:
    ///   - productType: Product type (e.g., "Foaming Facial Cleanser")
    ///   - productName: Product name
    /// - Returns: Inferred form or nil
    func inferForm(productType: String, productName: String) -> String? {
        let combinedText = "\(productType) \(productName)".lowercased()
        
        // Check keywords in order of specificity
        for form in forms {
            for keyword in form.keywords {
                if combinedText.contains(keyword.lowercased()) {
                    return form.canonical
                }
            }
        }
        
        return nil
    }
    
    /// Extract form from text with confidence
    /// - Parameter text: Text to analyze
    /// - Returns: Tuple of (form, confidence) or nil
    func extractForm(_ text: String) -> (form: String, confidence: Double)? {
        let lowercased = text.lowercased()
        var bestMatch: (form: FormType, score: Int)?
        
        for form in forms {
            var score = 0
            
            // Check keywords
            for keyword in form.keywords {
                if lowercased.contains(keyword.lowercased()) {
                    score += 2
                }
            }
            
            // Check canonical name
            if lowercased.contains(form.canonical.lowercased()) {
                score += 3
            }
            
            // Check variations
            for variation in form.variations {
                if lowercased.contains(variation.lowercased()) {
                    score += 2
                }
            }
            
            if bestMatch == nil || score > bestMatch!.score {
                if score > 0 {
                    bestMatch = (form, score)
                }
            }
        }
        
        guard let match = bestMatch else { return nil }
        
        // Calculate confidence
        let confidence = min(Double(match.score) / 4.0, 1.0)
        
        return (match.form.canonical, confidence)
    }
    
    /// Get form type by canonical name
    /// - Parameter canonical: Canonical form name
    /// - Returns: FormType if found
    func getForm(_ canonical: String) -> FormType? {
        return formsByCanonical[canonical.lowercased()]
    }
    
    /// All supported canonical forms
    var allCanonicalForms: [String] {
        return forms.map { $0.canonical }.sorted()
    }
    
    // MARK: - Form Data
    
    private static func buildFormTaxonomy() -> [FormType] {
        return [
            // MARK: - Liquid Forms
            
            FormType(
                canonical: "liquid",
                variations: ["liquid", "fluid", "lotion"],
                compatibleForms: ["cream", "gel", "foam"],
                incompatibleForms: ["bar", "stick", "powder"],
                keywords: ["liquid", "fluid", "lotion", "serum"]
            ),
            
            FormType(
                canonical: "cream",
                variations: ["cream", "creme", "créme"],
                compatibleForms: ["liquid", "gel", "butter"],
                incompatibleForms: ["spray", "powder", "bar"],
                keywords: ["cream", "creme", "créme", "moisturizer"]
            ),
            
            FormType(
                canonical: "oil",
                variations: ["oil", "serum oil"],
                compatibleForms: ["liquid"],
                incompatibleForms: ["powder", "bar", "stick"],
                keywords: ["oil", "serum"]
            ),
            
            FormType(
                canonical: "gel",
                variations: ["gel", "gelly", "jelly"],
                compatibleForms: ["liquid", "cream"],
                incompatibleForms: ["powder", "bar"],
                keywords: ["gel", "gelly", "jelly"]
            ),
            
            // MARK: - Foam/Mousse Forms
            
            FormType(
                canonical: "foam",
                variations: ["foam", "foaming", "mousse", "lather"],
                compatibleForms: ["liquid", "gel"],
                incompatibleForms: ["bar", "stick", "powder"],
                keywords: ["foam", "foaming", "mousse", "lather", "whipped"]
            ),
            
            // MARK: - Solid Forms
            
            FormType(
                canonical: "bar",
                variations: ["bar", "soap bar", "bar soap"],
                compatibleForms: [],
                incompatibleForms: ["liquid", "cream", "oil", "gel", "spray"],
                keywords: ["bar", "soap bar"]
            ),
            
            FormType(
                canonical: "stick",
                variations: ["stick", "roll-on", "rollon"],
                compatibleForms: ["balm"],
                incompatibleForms: ["liquid", "spray", "powder"],
                keywords: ["stick", "roll-on", "rollon", "roll on"]
            ),
            
            FormType(
                canonical: "powder",
                variations: ["powder", "loose powder", "pressed powder"],
                compatibleForms: [],
                incompatibleForms: ["liquid", "oil", "cream", "gel"],
                keywords: ["powder", "loose", "pressed"]
            ),
            
            FormType(
                canonical: "balm",
                variations: ["balm", "salve"],
                compatibleForms: ["cream", "stick", "butter"],
                incompatibleForms: ["liquid", "spray", "powder"],
                keywords: ["balm", "salve"]
            ),
            
            // MARK: - Spray Forms
            
            FormType(
                canonical: "spray",
                variations: ["spray", "spritz", "pump spray"],
                compatibleForms: ["liquid", "mist"],
                incompatibleForms: ["cream", "bar", "powder", "stick"],
                keywords: ["spray", "spritz", "pump"]
            ),
            
            FormType(
                canonical: "mist",
                variations: ["mist", "face mist", "facial mist", "hydrating mist", "toning mist"],
                compatibleForms: ["spray", "liquid"],
                incompatibleForms: ["cream", "bar", "powder", "stick"],
                keywords: ["mist", "facial mist", "hydrating"]
            ),
            
            FormType(
                canonical: "aerosol",
                variations: ["aerosol", "aerosol spray"],
                compatibleForms: ["spray"],
                incompatibleForms: ["liquid", "cream", "bar"],
                keywords: ["aerosol"]
            ),
            
            // MARK: - Special Forms
            
            FormType(
                canonical: "wax",
                variations: ["wax", "pomade wax"],
                compatibleForms: ["cream", "balm"],
                incompatibleForms: ["liquid", "spray", "powder"],
                keywords: ["wax", "pomade"]
            ),
            
            FormType(
                canonical: "butter",
                variations: ["butter", "body butter"],
                compatibleForms: ["cream", "balm"],
                incompatibleForms: ["liquid", "spray", "powder"],
                keywords: ["butter"]
            ),
            
            FormType(
                canonical: "roll-on",
                variations: ["roll-on", "rollon", "roll on"],
                compatibleForms: ["stick"],
                incompatibleForms: ["spray", "powder", "bar"],
                keywords: ["roll-on", "rollon", "roll on", "roller"]
            ),
            
            // MARK: - Catch-All
            
            FormType(
                canonical: "other",
                variations: ["other", "unknown"],
                compatibleForms: ["liquid", "cream", "gel", "oil"],
                incompatibleForms: [],
                keywords: []
            ),
        ]
    }
}

// MARK: - FormType Model

/// Represents a single form/dispensing method
struct FormType {
    let canonical: String           // Canonical form name
    let variations: [String]        // Common variations
    let compatibleForms: [String]   // Forms considered compatible
    let incompatibleForms: [String] // Forms that are NOT compatible
    let keywords: [String]          // Keywords for detection
}
