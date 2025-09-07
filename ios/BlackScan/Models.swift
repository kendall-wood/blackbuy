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
    let form: String
    let setBundle: String
    let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, name, company, price, tags
        case imageUrl = "image_url"
        case productUrl = "product_url"
        case mainCategory = "main_category"
        case productType = "product_type"
        case form
        case setBundle = "set_bundle"
    }
    
    /// Computed property for display price
    var formattedPrice: String {
        if price > 0 {
            return String(format: "$%.2f", price)
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
    let highlight: [String: TypesenseHighlight]?
    let textMatch: Int?
    
    enum CodingKeys: String, CodingKey {
        case document, highlight
        case textMatch = "text_match"
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
    let facetCounts: [TypesenseFacetCount]?
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
        case facetCounts = "facet_counts"
        case foundDocs = "found_docs"
        case outOf = "out_of"
        case requestParams = "request_params"
        case searchCutoff = "search_cutoff"
        case searchTimeMs = "search_time_ms"
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
