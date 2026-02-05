import Foundation

// MARK: - Safe Decoding Utilities

/// A coding key type that can handle any string key, useful for ignoring unknown fields
struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

/// Extensions to KeyedDecodingContainer for safe decoding that won't crash
extension KeyedDecodingContainer {
    
    /// Safely decode a value, returning a default if decoding fails
    func safelyDecode<T: Codable>(_ type: T.Type, forKey key: Key, defaultValue: T) -> T {
        return (try? decode(type, forKey: key)) ?? defaultValue
    }
    
    /// Safely decode an optional value
    func safelyDecodeIfPresent<T: Codable>(_ type: T.Type, forKey key: Key) -> T? {
        return try? decodeIfPresent(type, forKey: key)
    }
    
    /// Safely decode a string, with fallback handling
    func safelyDecodeString(forKey key: Key, defaultValue: String = "") -> String {
        // Try as String first
        if let stringValue = try? decode(String.self, forKey: key) {
            return stringValue
        }
        // Try as Int and convert to String
        if let intValue = try? decode(Int.self, forKey: key) {
            return "\(intValue)"
        }
        // Try as Double and convert to String
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return "\(doubleValue)"
        }
        return defaultValue
    }
    
    /// Safely decode a double, with fallback handling
    func safelyDecodeDouble(forKey key: Key, defaultValue: Double = 0.0) -> Double {
        // Try as Double first
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return doubleValue
        }
        // Try as String and convert to Double
        if let stringValue = try? decode(String.self, forKey: key),
           let doubleValue = Double(stringValue) {
            return doubleValue
        }
        // Try as Int and convert to Double
        if let intValue = try? decode(Int.self, forKey: key) {
            return Double(intValue)
        }
        return defaultValue
    }
}

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
    let subcategory2: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, company, price, tags
        case imageUrl = "image_url"
        case productUrl = "product_url"
        case mainCategory = "main_category"
        case productType = "product_type"
        case form
        case setBundle = "set_bundle"
        case subcategory2 = "subcategory_2"
        // Ignore _raw field and any other extra fields
    }
    
    // Memberwise initializer for creating products manually
    init(
        id: String,
        name: String,
        company: String,
        price: Double,
        imageUrl: String,
        productUrl: String,
        mainCategory: String,
        productType: String,
        form: String,
        setBundle: String,
        tags: [String],
        subcategory2: String? = nil
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
        self.subcategory2 = subcategory2
    }
    
    // Custom decoder for JSON/API responses - NEVER fails
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Use safe decoding with reasonable defaults
        id = container.safelyDecodeString(forKey: .id, defaultValue: "unknown-\(UUID().uuidString)")
        name = container.safelyDecodeString(forKey: .name, defaultValue: "Unknown Product")
        company = container.safelyDecodeString(forKey: .company, defaultValue: "Unknown Company")
        price = container.safelyDecodeDouble(forKey: .price, defaultValue: 0.0)
        imageUrl = container.safelyDecodeString(forKey: .imageUrl, defaultValue: "")
        productUrl = container.safelyDecodeString(forKey: .productUrl, defaultValue: "")
        mainCategory = container.safelyDecodeString(forKey: .mainCategory, defaultValue: "Other")
        productType = container.safelyDecodeString(forKey: .productType, defaultValue: "Other")
        form = container.safelyDecodeString(forKey: .form, defaultValue: "other")
        setBundle = container.safelyDecodeString(forKey: .setBundle, defaultValue: "single")
        tags = container.safelyDecode([String].self, forKey: .tags, defaultValue: [])
        subcategory2 = try? container.decodeIfPresent(String.self, forKey: .subcategory2)
        
        // All additional fields are automatically ignored - no need to handle them
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
    let highlight: [String: TypesenseHighlightValue]?
    let textMatch: Int?
    
    enum CodingKeys: String, CodingKey {
        case document, highlight
        case textMatch = "text_match"
        // All other fields are automatically ignored
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Product document is required - use safe decoding with fallback
        if let productDocument = container.safelyDecodeIfPresent(Product.self, forKey: .document) {
            document = productDocument
        } else {
            // Create a fallback product if document parsing fails
            document = Product(
                id: "fallback-\(UUID().uuidString)",
                name: "Product information unavailable",
                company: "Unknown",
                price: 0.0,
                imageUrl: "",
                productUrl: "",
                mainCategory: "Other",
                productType: "Other",
                form: "other",
                setBundle: "single",
                tags: []
            )
        }
        
        // Optional fields - ignore if they fail to parse
        highlight = container.safelyDecodeIfPresent([String: TypesenseHighlightValue].self, forKey: .highlight)
        textMatch = container.safelyDecodeIfPresent(Int.self, forKey: .textMatch)
        
        // All other fields (highlights, text_match_info, etc.) are automatically ignored
    }
}

/// Flexible highlight value that can be either a TypesenseHighlight object or an array
/// Uses completely safe parsing that never fails
enum TypesenseHighlightValue: Codable {
    case highlight(TypesenseHighlight)
    case array([TypesenseHighlight])
    case empty
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as array first (more common case)
        if let highlightArray = try? container.decode([TypesenseHighlight].self) {
            self = .array(highlightArray)
            return
        }
        
        // Try to decode as single TypesenseHighlight
        if let highlight = try? container.decode(TypesenseHighlight.self) {
            self = .highlight(highlight)
            return
        }
        
        // Try to decode as basic dictionary and create a simple highlight
        if let dict = try? container.decode([String: AnyCodable].self) {
            if let snippet = dict["snippet"]?.stringValue ?? dict["value"]?.stringValue {
                let simpleHighlight = TypesenseHighlight(
                    snippet: snippet,
                    value: snippet,
                    matchedTokens: dict["matched_tokens"]?.arrayValue?.compactMap { $0.stringValue } ?? []
                )
                self = .highlight(simpleHighlight)
                return
            }
        }
        
        // Complete fallback - never fail
        self = .empty
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .highlight(let highlight):
            try container.encode(highlight)
        case .array(let highlightArray):
            try container.encode(highlightArray)
        case .empty:
            try container.encodeNil()
        }
    }
}

/// Helper for decoding any JSON value
struct AnyCodable: Codable {
    let value: Any
    
    var stringValue: String? {
        return value as? String
    }
    
    var arrayValue: [AnyCodable]? {
        return value as? [AnyCodable]
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
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
    
    // Manual initializer for creating highlights
    init(snippet: String?, value: String?, matchedTokens: [String]?) {
        self.snippet = snippet
        self.value = value
        self.matchedTokens = matchedTokens
    }
    
    // Safe decoder that never fails
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        snippet = container.safelyDecodeIfPresent(String.self, forKey: .snippet)
        value = container.safelyDecodeIfPresent(String.self, forKey: .value)
        matchedTokens = container.safelyDecodeIfPresent([String].self, forKey: .matchedTokens)
    }
}

/// Typesense facet count for filtering UI
struct TypesenseFacetCount: Codable {
    let count: Int?
    let highlighted: String?
    let value: String?
    
    // Handle flexible structure from Typesense
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode count, but make it optional since it might not exist
        count = try container.decodeIfPresent(Int.self, forKey: .count)
        highlighted = try container.decodeIfPresent(String.self, forKey: .highlighted)  
        value = try container.decodeIfPresent(String.self, forKey: .value)
    }
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
    let facetCounts: [String: [TypesenseFacetCount]]?
    let found: Int
    let foundDocs: Int?
    let hits: [TypesenseHit]
    let outOf: Int
    let page: Int
    let requestParams: TypesenseRequestParams
    let searchCutoff: Bool?
    let searchTimeMs: Int
    
    // Super safe decoder that handles any response format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Use safe decoding with sensible defaults
        found = container.safelyDecode(Int.self, forKey: .found, defaultValue: 0)
        foundDocs = container.safelyDecodeIfPresent(Int.self, forKey: .foundDocs)
        
        // Hits array with fallback - this is critical
        hits = container.safelyDecode([TypesenseHit].self, forKey: .hits, defaultValue: [])
        
        outOf = container.safelyDecode(Int.self, forKey: .outOf, defaultValue: 0)
        page = container.safelyDecode(Int.self, forKey: .page, defaultValue: 1)
        searchTimeMs = container.safelyDecode(Int.self, forKey: .searchTimeMs, defaultValue: 0)
        
        // Optional fields
        searchCutoff = container.safelyDecodeIfPresent(Bool.self, forKey: .searchCutoff)
        facetCounts = container.safelyDecodeIfPresent([String: [TypesenseFacetCount]].self, forKey: .facetCounts)
        
        // Request params with fallback
        if let params = container.safelyDecodeIfPresent(TypesenseRequestParams.self, forKey: .requestParams) {
            requestParams = params
        } else {
            // Create a fallback request params
            requestParams = TypesenseRequestParams(
                collectionName: "products",
                perPage: 20,
                q: ""
            )
        }
    }
    
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
    
    // Manual initializer
    init(collectionName: String?, perPage: Int?, q: String?) {
        self.collectionName = collectionName
        self.perPage = perPage
        self.q = q
    }
    
    // Safe decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        collectionName = container.safelyDecodeIfPresent(String.self, forKey: .collectionName)
        perPage = container.safelyDecodeIfPresent(Int.self, forKey: .perPage)
        q = container.safelyDecodeIfPresent(String.self, forKey: .q)
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
    let filterBy: String?
    
    init(
        query: String,
        page: Int = 1,
        perPage: Int = 20,
        productType: String? = nil,
        mainCategory: String? = nil,
        company: String? = nil,
        priceMin: Double? = nil,
        priceMax: Double? = nil,
        sortBy: String? = nil,
        filterBy: String? = nil
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
        self.filterBy = filterBy
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

// MARK: - Sample Data for Previews

extension Product {
    static let sampleProducts: [Product] = [
        Product(
            id: "sample-1",
            name: "Moisturizing Curl Shampoo",
            company: "CurlCare Co.",
            price: 24.99,
            imageUrl: "https://via.placeholder.com/200x200/FF6B9D/FFFFFF?text=Shampoo",
            productUrl: "https://example.com/shampoo",
            mainCategory: "Hair Care",
            productType: "Shampoo",
            form: "liquid",
            setBundle: "single",
            tags: ["shampoo"]
        ),
        Product(
            id: "sample-2",
            name: "Deep Conditioning Hair Mask",
            company: "NaturalRoots",
            price: 32.00,
            imageUrl: "https://via.placeholder.com/200x200/9B7EDE/FFFFFF?text=Mask",
            productUrl: "https://example.com/mask",
            mainCategory: "Hair Care",
            productType: "Mask/Deep Conditioner",
            form: "cream",
            setBundle: "single",
            tags: ["mask", "deep conditioner"]
        ),
        Product(
            id: "sample-3",
            name: "Curl Defining Gel Strong Hold",
            company: "CoilCare",
            price: 18.50,
            imageUrl: "https://via.placeholder.com/200x200/4ECDC4/FFFFFF?text=Gel",
            productUrl: "https://example.com/gel",
            mainCategory: "Hair Care",
            productType: "Gel/Gelly",
            form: "gel",
            setBundle: "single",
            tags: ["gel", "curl"]
        ),
        Product(
            id: "sample-4",
            name: "Leave-In Conditioner Spray",
            company: "MelaninHair",
            price: 22.00,
            imageUrl: "https://via.placeholder.com/200x200/45B7D1/FFFFFF?text=Spray",
            productUrl: "https://example.com/spray",
            mainCategory: "Hair Care",
            productType: "Leave-In Conditioner",
            form: "spray",
            setBundle: "single",
            tags: ["leave-in", "spray"]
        ),
        Product(
            id: "sample-5",
            name: "Edge Control Styling Cream",
            company: "EdgeMasters",
            price: 12.99,
            imageUrl: "https://via.placeholder.com/200x200/F7DC6F/000000?text=Edge",
            productUrl: "https://example.com/edge",
            mainCategory: "Hair Care",
            productType: "Edge Control",
            form: "cream",
            setBundle: "single",
            tags: ["edge control"]
        ),
        Product(
            id: "sample-6",
            name: "Gift Card",
            company: "BeautyStore",
            price: 50.00,
            imageUrl: "https://via.placeholder.com/200x200/E74C3C/FFFFFF?text=Gift",
            productUrl: "https://example.com/gift",
            mainCategory: "Gifts/Cards",
            productType: "Gift Card",
            form: "other",
            setBundle: "single",
            tags: ["gift card"]
        )
    ]
}
