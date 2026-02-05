import Foundation

/// Cumulative confidence scoring engine
/// Scores products against classification using weighted 6-tier system
class ConfidenceScorer {
    
    // MARK: - Tier Weights
    
    private let tierWeights = TierWeights(
        productType: 0.40,    // 40%
        form: 0.25,           // 25%
        brandCategory: 0.15,  // 15%
        ingredients: 0.10,    // 10%
        size: 0.05,           // 5%
        visual: 0.05          // 5% (Phase 2)
    )
    
    // MARK: - Dependencies
    
    private let productTaxonomy: ProductTaxonomy
    private let formTaxonomy: FormTaxonomy
    private let sizeExtractor: SizeExtractor
    
    // MARK: - Initialization
    
    init() {
        self.productTaxonomy = .shared
        self.formTaxonomy = .shared
        self.sizeExtractor = .shared
    }
    
    // MARK: - Main Scoring Method
    
    /// Score a product against scan classification
    /// - Parameters:
    ///   - product: Product to score
    ///   - classification: Scan classification
    /// - Returns: Scored product with confidence and breakdown
    func score(
        product: Product,
        against classification: ScanClassification
    ) -> ScoredProduct {
        // TIER 1: Product Type (40%)
        let productTypeScore = scoreProductType(
            product.productType,
            against: classification.productType
        )
        
        // TIER 2: Form (25%)
        let formScore = scoreForm(
            product.form,
            against: classification.form
        )
        
        // TIER 3: Brand Category (15%)
        let brandScore = scoreBrandCategory(
            product,
            against: classification.brand
        )
        
        // TIER 4: Ingredient Clarity (10%)
        let ingredientScore = classification.ingredientClarity
        
        // TIER 5: Size (5%)
        let sizeScore = scoreSize(
            product,
            against: classification.size
        )
        
        // TIER 6: Visual (5%) - Phase 2
        let visualScore = 0.5  // Neutral for now
        
        // CUMULATIVE WEIGHTED SCORE
        let finalScore = (
            (productTypeScore * tierWeights.productType) +
            (formScore * tierWeights.form) +
            (brandScore * tierWeights.brandCategory) +
            (ingredientScore * tierWeights.ingredients) +
            (sizeScore * tierWeights.size) +
            (visualScore * tierWeights.visual)
        )
        
        let breakdown = ScoreBreakdown(
            productTypeScore: productTypeScore,
            formScore: formScore,
            brandScore: brandScore,
            ingredientScore: ingredientScore,
            sizeScore: sizeScore,
            visualScore: visualScore
        )
        
        let explanation = buildExplanation(breakdown, classification, product)
        
        return ScoredProduct(
            id: product.id,
            product: product,
            confidenceScore: finalScore,
            breakdown: breakdown,
            explanation: explanation
        )
    }
    
    // MARK: - Individual Tier Scoring
    
    /// TIER 1: Score product type match
    /// - Parameters:
    ///   - productType: Product's type
    ///   - target: Target classification
    /// - Returns: Score 0.0-1.0
    private func scoreProductType(
        _ productType: String,
        against target: ProductTypeResult
    ) -> Double {
        let normalizedProduct = productTaxonomy.normalize(productType) ?? productType
        let normalizedTarget = productTaxonomy.normalize(target.type) ?? target.type
        
        // Exact match
        if normalizedProduct.lowercased() == normalizedTarget.lowercased() {
            return 1.0
        }
        
        // Synonym match
        if productTaxonomy.areSynonyms(normalizedProduct, normalizedTarget) {
            return 0.9
        }
        
        // Same category
        if let productCat = productTaxonomy.getCategory(productType),
           let targetCat = productTaxonomy.getCategory(target.type),
           productCat.lowercased() == targetCat.lowercased() {
            return 0.6
        }
        
        // Partial keyword match
        let productKeywords = Set(productType.lowercased().split(separator: " ").map(String.init))
        let targetKeywords = Set(target.type.lowercased().split(separator: " ").map(String.init))
        let overlap = productKeywords.intersection(targetKeywords)
        
        if !overlap.isEmpty {
            let matchRatio = Double(overlap.count) / Double(max(productKeywords.count, targetKeywords.count))
            return 0.3 + (matchRatio * 0.3)  // 0.3-0.6 range
        }
        
        return 0.0
    }
    
    /// TIER 2: Score form match
    /// - Parameters:
    ///   - form: Product's form
    ///   - target: Target form result
    /// - Returns: Score 0.0-1.0
    private func scoreForm(
        _ form: String?,
        against target: FormResult?
    ) -> Double {
        guard let form = form, let target = target else {
            return 0.5  // Unknown form = neutral score
        }
        
        let normalizedForm = formTaxonomy.normalize(form) ?? form
        let normalizedTarget = formTaxonomy.normalize(target.form) ?? target.form
        
        // Exact match
        if normalizedForm.lowercased() == normalizedTarget.lowercased() {
            return 1.0
        }
        
        // Compatible forms
        if formTaxonomy.areCompatible(normalizedForm, normalizedTarget) {
            return 0.7
        }
        
        // Generic/other
        if normalizedForm == "other" || normalizedTarget == "other" {
            return 0.5
        }
        
        // Incompatible
        return 0.3
    }
    
    /// TIER 3: Score brand category association
    /// - Parameters:
    ///   - product: Product to score
    ///   - brand: Detected brand (scanned)
    /// - Returns: Score 0.0-1.0
    private func scoreBrandCategory(
        _ product: Product,
        against brand: BrandResult?
    ) -> Double {
        guard let brand = brand else {
            return 0.5  // No brand detected = neutral
        }
        
        let productCategory = product.mainCategory.lowercased()
        
        // Check if product's category matches scanned brand's categories
        let brandCategories = brand.categories.map { $0.lowercased() }
        
        if brandCategories.contains(productCategory) {
            return 1.0  // Exact category match
        }
        
        // Check related categories
        let relatedPairs: [(String, String)] = [
            ("face care", "skincare"),
            ("skin care", "skincare"),
            ("beauty & personal care", "skincare"),
            ("body care", "beauty & personal care"),
            ("hair care", "beauty & personal care"),
        ]
        
        for (cat1, cat2) in relatedPairs {
            if (productCategory.contains(cat1) && brandCategories.contains(where: { $0.contains(cat2) })) ||
               (productCategory.contains(cat2) && brandCategories.contains(where: { $0.contains(cat1) })) {
                return 0.7  // Related category
            }
        }
        
        return 0.5  // Different category but acceptable
    }
    
    /// TIER 5: Score size compatibility
    /// - Parameters:
    ///   - product: Product to score
    ///   - size: Scanned size
    /// - Returns: Score 0.0-1.0
    private func scoreSize(
        _ product: Product,
        against size: ProductSize?
    ) -> Double {
        guard let scannedSize = size else {
            return 0.5  // No size detected = neutral
        }
        
        // Try to extract size from product name
        let productSize = sizeExtractor.extractSize(product.name)
        
        guard let productSize = productSize else {
            return 0.5  // Product has no size info
        }
        
        return sizeExtractor.scoreCompatibility(scannedSize, productSize)
    }
    
    // MARK: - Explanation Builder
    
    /// Build human-readable explanation of the score
    /// - Parameters:
    ///   - breakdown: Score breakdown
    ///   - classification: Scan classification
    ///   - product: Scored product
    /// - Returns: Explanation string
    private func buildExplanation(
        _ breakdown: ScoreBreakdown,
        _ classification: ScanClassification,
        _ product: Product
    ) -> String {
        var parts: [String] = []
        
        // Product type
        if breakdown.productTypeScore >= 0.9 {
            parts.append("Exact product type match")
        } else if breakdown.productTypeScore >= 0.7 {
            parts.append("Similar product type")
        }
        
        // Form
        if breakdown.formScore >= 0.9 {
            parts.append("Same dispensing method")
        } else if breakdown.formScore >= 0.7 {
            parts.append("Compatible form")
        }
        
        // Brand category
        if breakdown.brandScore >= 0.9 {
            parts.append("Same product category")
        }
        
        // Size
        if breakdown.sizeScore >= 0.9 {
            parts.append("Similar size")
        }
        
        if parts.isEmpty {
            return "Compatible alternative"
        }
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - Scored Product Model

/// Product with confidence score and breakdown
struct ScoredProduct: Identifiable {
    let id: String
    let product: Product
    let confidenceScore: Double        // 0.0-1.0
    let breakdown: ScoreBreakdown
    let explanation: String
    
    /// Confidence as percentage (0-100)
    var confidencePercentage: Int {
        Int(confidenceScore * 100)
    }
    
    /// Confidence level category
    var confidenceLevel: ConfidenceLevel {
        switch confidenceScore {
        case 0.9...1.0:
            return .excellent
        case 0.75..<0.9:
            return .good
        case 0.5..<0.75:
            return .fair
        default:
            return .low
        }
    }
}

// MARK: - Score Breakdown Model

/// Detailed breakdown of confidence score by tier
struct ScoreBreakdown {
    let productTypeScore: Double      // 0.0-1.0
    let formScore: Double             // 0.0-1.0
    let brandScore: Double            // 0.0-1.0
    let ingredientScore: Double       // 0.0-1.0
    let sizeScore: Double             // 0.0-1.0
    let visualScore: Double?          // 0.0-1.0 (Phase 2)
    
    /// Human-readable details
    var details: [String: Double] {
        [
            "Product Type": productTypeScore,
            "Form/Dispensing": formScore,
            "Brand Category": brandScore,
            "Ingredient Clarity": ingredientScore,
            "Size": sizeScore
        ]
    }
    
    /// Number of criteria matched (score >= 0.7)
    var criteriaMatched: Int {
        var count = 0
        if productTypeScore >= 0.7 { count += 1 }
        if formScore >= 0.7 { count += 1 }
        if brandScore >= 0.7 { count += 1 }
        if ingredientScore >= 0.7 { count += 1 }
        if sizeScore >= 0.7 { count += 1 }
        return count
    }
}

// MARK: - Supporting Models

/// Tier weights for cumulative scoring
private struct TierWeights {
    let productType: Double       // 40%
    let form: Double              // 25%
    let brandCategory: Double     // 15%
    let ingredients: Double       // 10%
    let size: Double              // 5%
    let visual: Double            // 5%
}

/// Confidence level categories
enum ConfidenceLevel {
    case excellent    // 90%+
    case good         // 75-89%
    case fair         // 50-74%
    case low          // <50%
    
    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "lightGreen"
        case .fair:
            return "orange"
        case .low:
            return "red"
        }
    }
    
    var description: String {
        switch self {
        case .excellent:
            return "Excellent Match"
        case .good:
            return "Good Match"
        case .fair:
            return "Fair Match"
        case .low:
            return "Weak Match"
        }
    }
}
