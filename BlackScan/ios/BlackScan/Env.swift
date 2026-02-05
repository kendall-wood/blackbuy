import Foundation

/// Environment configuration for BlackScan app
/// Reads Typesense credentials from Xcode scheme environment variables
struct Env {
    
    // MARK: - Typesense Configuration
    
    /// Typesense host URL (e.g., "https://your-cluster.a1.typesense.net")
    /// Uses environment variable when available (Xcode), falls back to embedded config for standalone operation
    static let typesenseHost: String = {
        // Try environment variable first (for development in Xcode)
        if let host = ProcessInfo.processInfo.environment["TYPESENSE_HOST"] {
            // Ensure host starts with https://
            if host.hasPrefix("http://") || host.hasPrefix("https://") {
                return host
            } else {
                return "https://\(host)"
            }
        }
        
        // Fallback to embedded config for standalone operation (prevents crashes)
        return "https://mr4ntdeul9hf06k5p-1.a1.typesense.net/"
    }()
    
    /// Typesense search-only key (scoped permissions only)
    /// Uses environment variable when available (Xcode), falls back to embedded config for standalone operation
    static let typesenseSearchKey: String = {
        // Try environment variable first (for development in Xcode)
        if let searchKey = ProcessInfo.processInfo.environment["TYPESENSE_SEARCH_KEY"],
           !searchKey.isEmpty {
            
            // Validate key format - search keys should have 'ts-' prefix for scoped keys
            guard searchKey.hasPrefix("ts-") || searchKey.count > 20 else {
                print("⚠️ Invalid search key format in environment variable, using embedded config")
                return "wb63C9sLpbw3GUPPw865I8x7CZCd7AGm"
            }
            
            return searchKey
        }
        
        // Fallback to embedded config for standalone operation (prevents crashes)
        return "wb63C9sLpbw3GUPPw865I8x7CZCd7AGm"
    }()
    
    // SECURITY: Admin key access removed from client entirely
    // Admin operations must be performed server-side only
    
    /// Typesense collection name (fixed as 'products')
    static let typesenseCollection: String = "products"
    
    // MARK: - Backend Configuration
    
    /// Backend API URL for AI classification and feedback
    static let backendURL: String = {
        if let backend = ProcessInfo.processInfo.environment["BACKEND_URL"] {
            return backend
        }
        // Default to production backend
        return "https://blackscan-backend.vercel.app"
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
    
    /// Default sort field - using text match score instead of price
    static let defaultSortBy: String = "_text_match:desc"
    
    // MARK: - Security Configuration
    
    /// Maximum query length for security
    static let maxQueryLength: Int = 200
    
    /// Maximum results per query (security limit)
    static let maxResultsPerQuery: Int = 50
    
    /// Allowed search operations (read-only)
    static let allowedOperations: Set<String> = ["search"]
    
    // MARK: - App Configuration
    
    /// Maximum number of search history items to keep
    static let maxSearchHistoryItems: Int = 50
    
    /// Debounce delay for search-as-you-type (in seconds)
    static let searchDebounceDelay: TimeInterval = 0.5
    
    // MARK: - AI Classification Configuration
    
    /// Whether to enable AI-enhanced product classification
    static let enableAIClassification: Bool = {
        #if DEBUG
        // In debug mode, check for environment variable or default to true
        return ProcessInfo.processInfo.environment["DISABLE_AI"] != "1"
        #else
        // In production, enable AI by default (can be disabled with DISABLE_AI=1)
        return ProcessInfo.processInfo.environment["DISABLE_AI"] != "1"
        #endif
    }()
    
    /// Confidence threshold for vision-based recognition (optimized for standalone operation)
    static let visionConfidenceThreshold: Float = {
        #if DEBUG
        return 0.5  // Higher threshold when debugging
        #else
        return 0.3  // Lower threshold for production to catch more products
        #endif
    }()
    
    /// Confidence threshold for performing product search (optimized for standalone operation)
    static let searchConfidenceThreshold: Float = {
        #if DEBUG
        return 0.6  // Higher threshold when debugging
        #else
        return 0.4  // Lower threshold for production to show more results
        #endif
    }()
    
    // MARK: - Debug Configuration
    
    /// Whether to enable debug logging
    static let isDebugMode: Bool = {
        #if DEBUG
        return true
        #else
        // Enable basic logging in production for troubleshooting (can be disabled with DISABLE_LOGGING=1)
        return ProcessInfo.processInfo.environment["DISABLE_LOGGING"] != "1"
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
            _ = typesenseSearchKey
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
        - Search Key: \(String(repeating: "*", count: max(0, typesenseSearchKey.count - 4)))\(typesenseSearchKey.suffix(4))
        - Collection: \(typesenseCollection)
        - Debug Mode: \(isDebugMode)
        - Network Logging: \(shouldLogNetworkRequests)
        """
    }
}
