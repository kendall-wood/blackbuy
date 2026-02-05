import Foundation

/// Client for interacting with Typesense search API
/// Provides product search functionality for BlackScan app
@MainActor
class TypesenseClient: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var lastError: Error?
    
    // MARK: - Private Properties
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    init() {
        // Configure URLSession with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Env.requestTimeout
        config.timeoutIntervalForResource = Env.requestTimeout * 2
        self.session = URLSession(configuration: config)
        
        // Configure JSON decoder
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Public Search Methods
    
    /// Searches for products using the given parameters
    /// - Parameter parameters: Search parameters including query, filters, pagination
    /// - Returns: TypesenseSearchResponse containing products and metadata
    func search(parameters: SearchParameters) async throws -> TypesenseSearchResponse {
        isLoading = true
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        // Declare data outside do block so it's accessible in catch blocks
        var responseData: Data?
        
        do {
            let url = try buildSearchURL(parameters: parameters)
            let request = try buildSearchRequest(url: url)
            
            if Env.shouldLogNetworkRequests {
                print("🔍 Typesense Request: \(url.absoluteString)")
            }
            
            let (data, response) = try await session.data(for: request)
            responseData = data // Store for error handling
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TypesenseError.invalidResponse
            }
            
            if Env.shouldLogNetworkRequests {
                print("📡 Typesense Response: \(httpResponse.statusCode)")
            }
            
            // Handle HTTP errors
            guard 200...299 ~= httpResponse.statusCode else {
                if let errorData = try? decoder.decode(TypesenseErrorResponse.self, from: data) {
                    throw TypesenseError.apiError(errorData.message)
                } else {
                    throw TypesenseError.httpError(httpResponse.statusCode)
                }
            }
            
            // Decode successful response
            let searchResponse = try decoder.decode(TypesenseSearchResponse.self, from: data)
            
            if Env.shouldLogNetworkRequests {
                print("✅ Found \(searchResponse.found) products in \(searchResponse.searchTimeMs)ms")
            }
            
            return searchResponse
            
        } catch let error as DecodingError {
            lastError = error
            
            // Enhanced decoding error logging
            print("❌ Typesense Decoding Error: \(error)")
            
            // Print specific decoding error details
            switch error {
            case .keyNotFound(let key, let context):
                print("❌ Missing key: '\(key.stringValue)'")
                print("❌ Context: \(context.debugDescription)")
                print("❌ Coding path: \(context.codingPath)")
            case .typeMismatch(let type, let context):
                print("❌ Type mismatch for type: \(type)")
                print("❌ Context: \(context.debugDescription)")
                print("❌ Coding path: \(context.codingPath)")
            case .valueNotFound(let type, let context):
                print("❌ Value not found for type: \(type)")
                print("❌ Context: \(context.debugDescription)")
                print("❌ Coding path: \(context.codingPath)")
            case .dataCorrupted(let context):
                print("❌ Data corrupted")
                print("❌ Context: \(context.debugDescription)")
                print("❌ Coding path: \(context.codingPath)")
            @unknown default:
                print("❌ Unknown decoding error")
            }
            
            // Try to print the raw response for debugging
            if let data = responseData {
                if let response = try? JSONSerialization.jsonObject(with: data, options: []) {
                    print("📄 Raw Response Structure:")
                    if let dict = response as? [String: Any] {
                        print("   Top-level keys: \(dict.keys.sorted())")
                        if let hits = dict["hits"] as? [[String: Any]], let firstHit = hits.first {
                            print("   First hit keys: \(firstHit.keys.sorted())")
                            if let document = firstHit["document"] as? [String: Any] {
                                print("   Document keys: \(document.keys.sorted())")
                            }
                        }
                    }
                } else if let rawString = String(data: data, encoding: .utf8) {
                    print("📄 Raw Response String (first 500 chars): \(rawString.prefix(500))")
                }
            }
            
            throw TypesenseError.decodingError(error)
            
        } catch {
            lastError = error
            
            print("❌ Typesense Error: \(error)")
            print("🔍 Error type: \(type(of: error))")
            
            throw error
        }
    }
    
    /// Convenience method for simple text search
    /// - Parameters:
    ///   - query: Search query string
    ///   - page: Page number (1-based)
    ///   - perPage: Number of results per page
    /// - Returns: Array of Product objects
    func searchProducts(
        query: String,
        page: Int = 1,
        perPage: Int = Env.defaultResultsPerPage
    ) async throws -> [Product] {
        let parameters = SearchParameters(
            query: query,
            page: page,
            perPage: perPage
        )
        
        let response = try await search(parameters: parameters)
        return response.products
    }
    
    /// Search products with category filter
    /// - Parameters:
    ///   - query: Search query string
    ///   - mainCategory: Category to filter by (e.g., "Hair Care")
    ///   - page: Page number (1-based)
    /// - Returns: Array of filtered Product objects
    func searchProducts(
        query: String,
        mainCategory: String,
        page: Int = 1
    ) async throws -> [Product] {
        let parameters = SearchParameters(
            query: query,
            page: page,
            perPage: Env.defaultResultsPerPage,
            mainCategory: mainCategory
        )
        
        let response = try await search(parameters: parameters)
        return response.products
    }
    
    /// Search products with product type filter
    /// - Parameters:
    ///   - query: Search query string
    ///   - productType: Product type to filter by (e.g., "Shampoo")
    ///   - page: Page number (1-based)
    /// - Returns: Array of filtered Product objects
    func searchProducts(
        query: String,
        productType: String,
        page: Int = 1
    ) async throws -> [Product] {
        let parameters = SearchParameters(
            query: query,
            page: page,
            perPage: Env.defaultResultsPerPage,
            productType: productType
        )
        
        let response = try await search(parameters: parameters)
        return response.products
    }
    
    // MARK: - Advanced Scan Search
    
    /// Advanced search optimized for scanning use case
    /// Uses weighted fields and broader results for local confidence scoring
    /// - Parameters:
    ///   - classification: Scan classification from AdvancedClassifier
    ///   - candidateCount: Number of candidates to retrieve (default: 100)
    /// - Returns: Array of candidate Product objects for local scoring
    func searchForScanMatches(
        classification: ScanClassification,
        candidateCount: Int = 100
    ) async throws -> [Product] {
        
        // STRATEGY: Multi-pass search with weighted fields
        // Pass 1: Specific search (product type + form)
        // Pass 2: Broader search (category-based) if Pass 1 yields < 20 results
        // Pass 3: Fallback (very broad) if Pass 2 yields < 10 results
        
        var allCandidates: [Product] = []
        
        // --- PASS 1: Specific Search ---
        let productTypeString = classification.productType.type
        let pass1Results = try await performWeightedSearch(
            productType: productTypeString,
            form: classification.form?.form,
            brand: classification.brand,
            candidateCount: min(candidateCount, 50)
        )
            
        allCandidates.append(contentsOf: pass1Results)
        
        if Env.shouldLogNetworkRequests {
            print("🔍 PASS 1 (Specific): Found \(pass1Results.count) candidates for '\(productTypeString)'")
        }
        
        // --- PASS 2: Broader Search (if needed) ---
        if allCandidates.count < 20 {
            // Get category from taxonomy
            let category = ProductTaxonomy.shared.getCategory(productTypeString) ?? "Beauty & Personal Care"
            
            let pass2Results = try await performCategorySearch(
                category: category,
                form: classification.form?.form,
                candidateCount: 30
            )
            
            // Merge and deduplicate
            let existingIds = Set(allCandidates.map { $0.id })
            let newResults = pass2Results.filter { !existingIds.contains($0.id) }
            allCandidates.append(contentsOf: newResults)
            
            if Env.shouldLogNetworkRequests {
                print("🔍 PASS 2 (Broader): Found \(newResults.count) additional candidates in '\(category)'")
            }
        }
        
        // --- PASS 3: Fallback (if still needed) ---
        if allCandidates.count < 10 {
            let pass3Results = try await performFallbackSearch(
                classification: classification,
                candidateCount: 20
            )
            
            // Merge and deduplicate
            let existingIds = Set(allCandidates.map { $0.id })
            let newResults = pass3Results.filter { !existingIds.contains($0.id) }
            allCandidates.append(contentsOf: newResults)
            
            if Env.shouldLogNetworkRequests {
                print("🔍 PASS 3 (Fallback): Found \(newResults.count) additional candidates")
            }
        }
        
        if Env.shouldLogNetworkRequests {
            print("✅ Total scan candidates: \(allCandidates.count)")
        }
        
        return allCandidates
    }
    
    // MARK: - Private Search Strategies
    
    /// Pass 1: Weighted search with product type + form
    private func performWeightedSearch(
        productType: String,
        form: String?,
        brand: BrandResult?,
        candidateCount: Int
    ) async throws -> [Product] {
        
        // Build search query
        var queryParts: [String] = [productType]
        if let form = form {
            queryParts.append(form)
        }
        
        let query = queryParts.joined(separator: " ")
        
        let url = try buildWeightedSearchURL(
            query: query,
            productType: productType,
            form: form,
            candidateCount: candidateCount
        )
        
        let request = try buildSearchRequest(url: url)
        
        let (data, _) = try await session.data(for: request)
        
        // Debug: Log raw response if decoding fails
        do {
            let response = try decoder.decode(TypesenseSearchResponse.self, from: data)
            return response.products
        } catch {
            if Env.isDebugMode {
                print("❌ Typesense decode error: \(error)")
                if let rawString = String(data: data, encoding: .utf8) {
                    print("📄 Raw Typesense response: \(rawString.prefix(500))")
                }
            }
            throw error
        }
    }
    
    /// Pass 2: Category-based search
    private func performCategorySearch(
        category: String,
        form: String?,
        candidateCount: Int
    ) async throws -> [Product] {
        
        let parameters = SearchParameters(
            query: form ?? "*",  // Use form if available, else wildcard
            page: 1,
            perPage: candidateCount,
            mainCategory: category
        )
        
        let response = try await search(parameters: parameters)
        return response.products
    }
    
    /// Pass 3: Fallback broad search
    private func performFallbackSearch(
        classification: ScanClassification,
        candidateCount: Int
    ) async throws -> [Product] {
        
        // Use ingredients or form as fallback
        var query = "*"
        if let form = classification.form?.form {
            query = form
        } else if let firstIngredient = classification.ingredients.first {
            query = firstIngredient
        }
        
        let parameters = SearchParameters(
            query: query,
            page: 1,
            perPage: candidateCount
        )
        
        let response = try await search(parameters: parameters)
        return response.products
    }
    
    /// Build weighted search URL with field boosting
    /// Query format: product_type^3, form^2, name^1, tags^1
    private func buildWeightedSearchURL(
        query: String,
        productType: String,
        form: String?,
        candidateCount: Int
    ) throws -> URL {
        
        guard var components = URLComponents(string: Env.typesenseSearchURL()) else {
            throw TypesenseError.invalidURL
        }
        
        // Use product_type as the PRIMARY search field
        let queryBy = "product_type,name,tags,form"
        
        var queryItems: [URLQueryItem] = [
            // Search ONLY for product type (not form) to avoid gel/spray confusion
            URLQueryItem(name: "q", value: productType),
            URLQueryItem(name: "query_by", value: queryBy),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "per_page", value: String(candidateCount)),
            // Sort by relevance (Typesense default text match score)
            URLQueryItem(name: "sort_by", value: "_text_match:desc"),
            // Enable prefix matching for partial product type matches
            URLQueryItem(name: "prefix", value: "true,false,false,false"),
            // Prioritize product_type field matches
            URLQueryItem(name: "query_by_weights", value: "10,3,2,1")
        ]
        
        // NO STRICT FILTER - but query focuses on product type
        // This way "Hand Sanitizer" matches "Hand Sanitizer Gel", "Hand Sanitizer Spray", etc.
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw TypesenseError.invalidURL
        }
        
        if Env.isDebugMode {
            print("🔗 Typesense URL: \(url.absoluteString)")
        }
        
        return url
    }
    
    // MARK: - Private Helper Methods
    
    /// Builds the complete search URL with query parameters
    private func buildSearchURL(parameters: SearchParameters) throws -> URL {
        guard var components = URLComponents(string: Env.typesenseSearchURL()) else {
            throw TypesenseError.invalidURL
        }
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: parameters.query),
            URLQueryItem(name: "query_by", value: Env.searchFields.joined(separator: ",")),
            URLQueryItem(name: "page", value: String(parameters.page)),
            URLQueryItem(name: "per_page", value: String(parameters.perPage)),
            URLQueryItem(name: "facet_by", value: Env.facetFields.joined(separator: ","))
        ]
        
        // Add filters
        var filters: [String] = []
        
        if let productType = parameters.productType {
            filters.append("product_type:=\(productType)")
        }
        
        if let mainCategory = parameters.mainCategory {
            filters.append("main_category:=\(mainCategory)")
        }
        
        if let company = parameters.company {
            filters.append("company:=\(company)")
        }
        
        // Add price range filter
        if let priceMin = parameters.priceMin, let priceMax = parameters.priceMax {
            filters.append("price:[\(priceMin)..\(priceMax)]")
        } else if let priceMin = parameters.priceMin {
            filters.append("price:>=\(priceMin)")
        } else if let priceMax = parameters.priceMax {
            filters.append("price:<=\(priceMax)")
        }
        
        if !filters.isEmpty {
            queryItems.append(URLQueryItem(name: "filter_by", value: filters.joined(separator: " && ")))
        }
        
        // Add sorting
        let sortBy = parameters.sortBy ?? Env.defaultSortBy
        queryItems.append(URLQueryItem(name: "sort_by", value: sortBy))
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw TypesenseError.invalidURL
        }
        
        return url
    }
    
    /// Builds the HTTP request with authentication headers
    private func buildSearchRequest(url: URL) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(Env.typesenseApiKey, forHTTPHeaderField: "X-TYPESENSE-API-KEY")
        
        return request
    }
}

// MARK: - Error Types

enum TypesenseError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Typesense URL configuration"
        case .invalidResponse:
            return "Invalid response from Typesense server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .apiError(let message):
            return "Typesense API error: \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Typesense API error response format
struct TypesenseErrorResponse: Codable {
    let message: String
    let code: Int?
}
