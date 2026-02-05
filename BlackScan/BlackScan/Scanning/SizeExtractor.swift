import Foundation

/// Extracts size and quantity information from product text
/// Handles various units: oz, ml, g, lbs, etc.
class SizeExtractor {
    
    // MARK: - Singleton
    
    static let shared = SizeExtractor()
    
    // MARK: - Regex Patterns
    
    private let patterns: [NSRegularExpression]
    
    // MARK: - Initialization
    
    private init() {
        self.patterns = Self.buildPatterns()
    }
    
    // MARK: - Public Methods
    
    /// Extract size from text
    /// - Parameter text: Text to analyze
    /// - Returns: ProductSize if found
    func extractSize(_ text: String) -> ProductSize? {
        for pattern in patterns {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, range: range) {
                // Extract matched groups
                if let size = parseMatch(match, in: text) {
                    return size
                }
            }
        }
        return nil
    }
    
    /// Check if two sizes are compatible
    /// - Parameters:
    ///   - size1: First size
    ///   - size2: Second size
    /// - Returns: True if compatible
    func areCompatible(_ size1: ProductSize, _ size2: ProductSize) -> Bool {
        // Convert to common unit
        let ml1 = convertToMilliliters(size1)
        let ml2 = convertToMilliliters(size2)
        
        // Calculate ratio
        let ratio = max(ml1, ml2) / min(ml1, ml2)
        
        // Compatible if within 2x
        return ratio <= 2.0
    }
    
    /// Calculate size compatibility score
    /// - Parameters:
    ///   - scanned: Scanned product size
    ///   - product: Catalog product size
    /// - Returns: Compatibility score (0.0-1.0)
    func scoreCompatibility(_ scanned: ProductSize?, _ product: ProductSize?) -> Double {
        guard let scanned = scanned, let product = product else {
            return 0.5  // Unknown size = neutral
        }
        
        // Convert to common unit (ml for liquids, g for solids)
        let scannedMl = convertToMilliliters(scanned)
        let productMl = convertToMilliliters(product)
        
        guard scannedMl > 0, productMl > 0 else {
            return 0.5
        }
        
        let ratio = max(scannedMl, productMl) / min(scannedMl, productMl)
        
        // Calculate score based on ratio
        if ratio <= 1.1 {         // Within 10%
            return 1.0
        } else if ratio <= 1.25 { // Within 25%
            return 0.9
        } else if ratio <= 1.5 {  // Within 50%
            return 0.7
        } else if ratio <= 2.0 {  // Within 2x
            return 0.5
        } else if ratio <= 3.0 {  // Within 3x
            return 0.3
        } else {
            return 0.2            // Very different
        }
    }
    
    // MARK: - Private Methods
    
    private static func buildPatterns() -> [NSRegularExpression] {
        let patternStrings = [
            // Fluid ounces
            #"(\d+(?:\.\d+)?)\s*(?:fl\s*)?oz"#,              // "12 fl oz", "8 oz"
            #"(\d+(?:\.\d+)?)\s*fluid\s*ounces?"#,           // "12 fluid ounces"
            
            // Milliliters
            #"(\d+(?:\.\d+)?)\s*ml"#,                        // "350ml", "350 ML"
            #"(\d+(?:\.\d+)?)\s*milliliters?"#,              // "350 milliliters"
            
            // Grams
            #"(\d+(?:\.\d+)?)\s*g(?:\s|$|\.|,)"#,            // "100g", "100 g"
            #"(\d+(?:\.\d+)?)\s*grams?"#,                    // "100 grams"
            
            // Pounds
            #"(\d+(?:\.\d+)?)\s*lbs?"#,                      // "2 lb", "2 lbs"
            #"(\d+(?:\.\d+)?)\s*pounds?"#,                   // "2 pounds"
            
            // Liters
            #"(\d+(?:\.\d+)?)\s*l(?:iter)?s?"#,              // "1L", "1 liter"
            
            // Ounces (weight)
            #"(\d+(?:\.\d+)?)\s*oz(?:\s|$|\.|,)"#,           // "8 oz" (weight)
            
            // Count
            #"(\d+)\s*(?:count|ct|pieces?|pack)"#,           // "24 count", "3 pack"
        ]
        
        return patternStrings.compactMap { pattern in
            try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }
    }
    
    private func parseMatch(_ match: NSTextCheckingResult, in text: String) -> ProductSize? {
        guard match.numberOfRanges >= 2 else { return nil }
        
        // Extract value
        let valueRange = match.range(at: 1)
        guard let valueSwiftRange = Range(valueRange, in: text) else { return nil }
        let valueString = String(text[valueSwiftRange])
        guard let value = Double(valueString) else { return nil }
        
        // Extract full matched text to determine unit
        let fullRange = match.range(at: 0)
        guard let fullSwiftRange = Range(fullRange, in: text) else { return nil }
        let fullMatch = String(text[fullSwiftRange]).lowercased()
        
        // Determine unit
        let unit: SizeUnit
        if fullMatch.contains("fl") || fullMatch.contains("fluid") {
            unit = .fluidOunces
        } else if fullMatch.contains("ml") || fullMatch.contains("milliliter") {
            unit = .milliliters
        } else if fullMatch.contains("g") || fullMatch.contains("gram") {
            unit = .grams
        } else if fullMatch.contains("lb") || fullMatch.contains("pound") {
            unit = .pounds
        } else if fullMatch.contains("l") || fullMatch.contains("liter") {
            unit = .liters
        } else if fullMatch.contains("count") || fullMatch.contains("ct") || 
                  fullMatch.contains("piece") || fullMatch.contains("pack") {
            unit = .count
        } else if fullMatch.contains("oz") {
            // Ambiguous - could be weight or volume
            // Default to fluid ounces for liquids
            unit = .fluidOunces
        } else {
            return nil
        }
        
        return ProductSize(
            value: value,
            unit: unit,
            rawText: fullMatch,
            confidence: 0.9
        )
    }
    
    /// Convert size to milliliters for comparison
    /// - Parameter size: ProductSize to convert
    /// - Returns: Size in milliliters
    private func convertToMilliliters(_ size: ProductSize) -> Double {
        switch size.unit {
        case .fluidOunces:
            return size.value * 29.5735  // 1 fl oz = 29.5735 ml
        case .milliliters:
            return size.value
        case .liters:
            return size.value * 1000
        case .grams:
            // Approximate (assumes density similar to water)
            return size.value
        case .pounds:
            // Convert to grams then treat as ml
            return size.value * 453.592
        case .ounces:
            // Weight ounce to grams
            return size.value * 28.3495
        case .count:
            // Can't convert count to volume
            return size.value * 100  // Arbitrary for comparison
        }
    }
}

// MARK: - ProductSize Model

/// Represents a product size/quantity
struct ProductSize {
    let value: Double           // Numeric value
    let unit: SizeUnit          // Unit of measurement
    let rawText: String         // Original matched text
    let confidence: Double      // Extraction confidence
    
    /// Human-readable description
    var description: String {
        let formattedValue = value.truncatingRemainder(dividingBy: 1) == 0 
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(formattedValue) \(unit.rawValue)"
    }
}

// MARK: - SizeUnit Enum

/// Units of measurement for product sizes
enum SizeUnit: String {
    case fluidOunces = "fl oz"
    case milliliters = "ml"
    case grams = "g"
    case pounds = "lb"
    case liters = "L"
    case ounces = "oz"
    case count = "count"
}
