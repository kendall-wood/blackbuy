import Foundation

/// Environment configuration for BlackScan app
/// Reads Typesense credentials from Xcode scheme environment variables
struct Env {
    
    // MARK: - Typesense Configuration
    
    /// Typesense host URL (e.g., "https://your-cluster.a1.typesense.net")
    static let typesenseHost: String = {
        guard let host = ProcessInfo.processInfo.environment["TYPESENSE_HOST"] else {
            fatalError("TYPESENSE_HOST environment variable not set. Please configure in Xcode scheme.")
        }
        
        // Ensure host starts with https://
        if host.hasPrefix("http://") || host.hasPrefix("https://") {
            return host
        } else {
            return "https://\(host)"
        }
    }()
    
    /// Typesense API key (search-only key, not admin key)
    static let typesenseApiKey: String = {
        guard let apiKey = ProcessInfo.processInfo.environment["TYPESENSE_API_KEY"] else {
            fatalError("TYPESENSE_API_KEY environment variable not set. Please configure in Xcode scheme.")
        }
        
        guard !apiKey.isEmpty else {
            fatalError("TYPESENSE_API_KEY environment variable is empty. Please provide a valid search API key.")
        }
        
        return apiKey
    }()
    
    /// Typesense collection name (fixed as 'products')
    static let typesenseCollection: String = "products"
    
    // MARK: - Backend Configuration
    
    /// Backend URL for feedback and analytics (required)
    static let backendURL: String = {
        guard let url = ProcessInfo.processInfo.environment["BACKEND_URL"] else {
            fatalError("BACKEND_URL environment variable not set. Please configure in Xcode scheme.")
        }
        
        guard !url.isEmpty else {
            fatalError("BACKEND_URL environment variable is empty. Please provide a valid backend URL.")
        }
        
        // Ensure URL starts with https://
        if url.hasPrefix("http://") || url.hasPrefix("https://") {
            return url
        } else {
            return "https://\(url)"
        }
    }()
    
    // MARK: - API Configuration
    
    /// Default request timeout for network calls
    static let requestTimeout: TimeInterval = 30.0
    
    /// Maximum number of search results per page
    static let maxResultsPerPage: Int = 50
    
    /// Default number of search results per page
    static let defaultResultsPerPage: Int = 20
    
    // MARK: - Search Configuration
    
    /// Fields to search against in Typesense
    static let searchFields: [String] = [
        "name",
        "product_type", 
        "company",
        "tags"
    ]
    
    /// Fields to enable faceting on
    static let facetFields: [String] = [
        "main_category",
        "product_type",
        "form",
        "company",
        "set_bundle"
    ]
    
    /// Default sort field
    static let defaultSortBy: String = "_text_match:desc"
    
    // MARK: - App Configuration
    
    /// Maximum number of search history items to keep
    static let maxSearchHistoryItems: Int = 50
    
    /// Debounce delay for search-as-you-type (in seconds)
    static let searchDebounceDelay: TimeInterval = 0.5
    
    // MARK: - Debug Configuration
    
    /// Whether to enable debug logging
    static let isDebugMode: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    /// Whether to print network requests/responses
    static let shouldLogNetworkRequests: Bool = {
        return isDebugMode && ProcessInfo.processInfo.environment["LOG_NETWORK"] == "1"
    }()
    
    // MARK: - Helper Methods
    
    /// Validates that all required environment variables are present
    static func validateEnvironment() -> Bool {
        do {
            _ = typesenseHost
            _ = typesenseApiKey
            _ = backendURL
            return true
        } catch {
            print("❌ Environment validation failed: \(error)")
            return false
        }
    }
    
    /// Returns full Typesense API URL for the products collection
    static func typesenseCollectionURL() -> String {
        return "\(typesenseHost)/collections/\(typesenseCollection)"
    }
    
    /// Returns full Typesense search URL
    static func typesenseSearchURL() -> String {
        return "\(typesenseCollectionURL())/documents/search"
    }
    
    /// Debug description of current environment
    static var debugDescription: String {
        return """
        BlackScan Environment Configuration:
        - Typesense Host: \(typesenseHost)
        - API Key: \(String(repeating: "*", count: max(0, typesenseApiKey.count - 4)))\(typesenseApiKey.suffix(4))
        - Collection: \(typesenseCollection)
        - Backend URL: \(backendURL)
        - Debug Mode: \(isDebugMode)
        - Network Logging: \(shouldLogNetworkRequests)
        """
    }
}
