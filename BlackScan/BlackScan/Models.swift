import Foundation

// MARK: - Product Models

/// Core product model matching our normalized Typesense schema
struct Product: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let company: String
    let price: Double
    let imageUrl: String
    let productUrl: String
    let mainCategory: String
    let productType: String
    let form: String?
    let setBundle: String?
    let tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, company, price, tags
        case imageUrl = "image_url"
        case productUrl = "product_url"
        case mainCategory = "main_category"
        case productType = "product_type"
        case form
        case setBundle = "set_bundle"
    }
    
    // Memberwise initializer for creating products directly
    init(
        id: String,
        name: String,
        company: String,
        price: Double,
        imageUrl: String,
        productUrl: String,
        mainCategory: String,
        productType: String,
        form: String? = nil,
        setBundle: String? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.company = company
        self.price = price
        self.imageUrl = imageUrl
        self.productUrl = productUrl
        self.mainCategory = mainCategory
        self.productType = productType
        self.form = form
        self.setBundle = setBundle
        self.tags = tags
    }
    
    // Custom decoder to handle price as either String or Double
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        company = try container.decode(String.self, forKey: .company)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        productUrl = try container.decode(String.self, forKey: .productUrl)
        mainCategory = try container.decode(String.self, forKey: .mainCategory)
        productType = try container.decode(String.self, forKey: .productType)
        form = try container.decodeIfPresent(String.self, forKey: .form)
        setBundle = try container.decodeIfPresent(String.self, forKey: .setBundle)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        
        // Handle price as either Double or String
        if let priceDouble = try? container.decode(Double.self, forKey: .price) {
            price = priceDouble
        } else if let priceString = try? container.decode(String.self, forKey: .price),
                  let priceDouble = Double(priceString) {
            price = priceDouble
        } else {
            price = 0.0
        }
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(company, forKey: .company)
        try container.encode(price, forKey: .price)
        try container.encode(imageUrl, forKey: .imageUrl)
        try container.encode(productUrl, forKey: .productUrl)
        try container.encode(mainCategory, forKey: .mainCategory)
        try container.encode(productType, forKey: .productType)
        try container.encodeIfPresent(form, forKey: .form)
        try container.encodeIfPresent(setBundle, forKey: .setBundle)
        try container.encodeIfPresent(tags, forKey: .tags)
    }
    
    /// Computed property for display price
    var formattedPrice: String {
        if price > 0 {
            return String(format: "$%.2f", price)
        } else if price == 0 {
            return "Free"
        } else {
            return "Price varies"
        }
    }
    
    /// Computed property for category display
    var categoryDisplay: String {
        return "\(mainCategory) • \(productType)"
    }
}

// MARK: - Typesense Response Models

/// Typesense search hit containing product and relevance metadata
struct TypesenseHit: Codable {
    let document: Product
    let textMatch: Int?
    
    enum CodingKeys: String, CodingKey {
        case document
        case textMatch = "text_match"
        // Omit highlight - it has inconsistent structure (dict for some fields, array for tags)
    }
}

/// Typesense highlight information for search results
struct TypesenseHighlight: Codable {
    let snippet: String?
    let value: String?
    let matchedTokens: [String]?
    
    enum CodingKeys: String, CodingKey {
        case snippet, value
        case matchedTokens = "matched_tokens"
    }
}

/// Typesense facet count for filtering UI
struct TypesenseFacetCount: Codable {
    let count: Int
    let highlighted: String?
    let value: String
}

/// Typesense facet stats for numerical fields
struct TypesenseFacetStats: Codable {
    let avg: Double?
    let max: Double?
    let min: Double?
    let sum: Double?
    let totalValues: Int?
    
    enum CodingKeys: String, CodingKey {
        case avg, max, min, sum
        case totalValues = "total_values"
    }
}

/// Complete Typesense search response
struct TypesenseSearchResponse: Codable {
    let found: Int
    let foundDocs: Int?
    let hits: [TypesenseHit]
    let outOf: Int
    let page: Int
    let requestParams: TypesenseRequestParams
    let searchCutoff: Bool?
    let searchTimeMs: Int
    
    enum CodingKeys: String, CodingKey {
        case hits, found, page
        case foundDocs = "found_docs"
        case outOf = "out_of"
        case requestParams = "request_params"
        case searchCutoff = "search_cutoff"
        case searchTimeMs = "search_time_ms"
        // Note: facet_counts intentionally omitted - not used and has complex nested structure
    }
    
    /// Extract products from hits
    var products: [Product] {
        return hits.map { $0.document }
    }
}

/// Request parameters echoed back in response
struct TypesenseRequestParams: Codable {
    let collectionName: String?
    let perPage: Int?
    let q: String?
    
    enum CodingKeys: String, CodingKey {
        case collectionName = "collection_name"
        case perPage = "per_page"
        case q
    }
}

// MARK: - Search Parameters

/// Search request parameters for Typesense API
struct SearchParameters {
    let query: String
    let page: Int
    let perPage: Int
    let productType: String?
    let mainCategory: String?
    let company: String?
    let priceMin: Double?
    let priceMax: Double?
    let sortBy: String?
    
    init(
        query: String,
        page: Int = 1,
        perPage: Int = 20,
        productType: String? = nil,
        mainCategory: String? = nil,
        company: String? = nil,
        priceMin: Double? = nil,
        priceMax: Double? = nil,
        sortBy: String? = nil
    ) {
        self.query = query
        self.page = page
        self.perPage = perPage
        self.productType = productType
        self.mainCategory = mainCategory
        self.company = company
        self.priceMin = priceMin
        self.priceMax = priceMax
        self.sortBy = sortBy
    }
}

// MARK: - Search History

/// Search history item for recent searches
struct SearchHistoryItem: Codable, Identifiable {
    let id: UUID
    let query: String
    let timestamp: Date
    let resultCount: Int
    
    init(query: String, resultCount: Int) {
        self.id = UUID()
        self.query = query
        self.timestamp = Date()
        self.resultCount = resultCount
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Scan Results

/// Match details for confidence scoring breakdown
struct MatchDetails {
    let productTypeMatch: Double
    let formMatch: Double
    let brandMatch: Double
    let ingredientMatch: Double
    let sizeMatch: Double
    let visualMatch: Double?
}

/// Product with confidence score from scanning
struct ScoredProduct {
    let product: Product
    let confidenceScore: Double
    let matchDetails: MatchDetails
    
    var confidencePercentage: Int {
        return Int(confidenceScore * 100)
    }
}
