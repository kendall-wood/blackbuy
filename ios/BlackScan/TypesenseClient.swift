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
        
        do {
            let url = try buildSearchURL(parameters: parameters)
            let request = try buildSearchRequest(url: url)
            
            if Env.shouldLogNetworkRequests {
                print("🔍 Typesense Request: \(url.absoluteString)")
            }
            
            let (data, response) = try await session.data(for: request)
            
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
            
        } catch {
            lastError = error
            
            if Env.shouldLogNetworkRequests {
                print("❌ Typesense Error: \(error)")
            }
            
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
