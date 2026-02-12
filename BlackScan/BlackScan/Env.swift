import Foundation

/// Environment configuration for BlackScan app
/// Reads credentials from Info.plist (injected via Secrets.xcconfig at build time).
/// Falls back to Xcode scheme environment variables for development convenience.
struct Env {
    
    // MARK: - Private Helper
    
    /// Whether all required configuration values are present
    static let isConfigured: Bool = {
        let keys = ["TYPESENSE_HOST", "TYPESENSE_API_KEY", "OPENAI_API_KEY", "BACKEND_URL", "SUPABASE_ANON_KEY"]
        return keys.allSatisfy { key in
            if let v = Bundle.main.infoDictionary?[key] as? String, !v.isEmpty, !v.hasPrefix("$(") { return true }
            if let v = ProcessInfo.processInfo.environment[key], !v.isEmpty { return true }
            return false
        }
    }()
    
    /// Reads a required config value. Checks Info.plist first (xcconfig-injected),
    /// then falls back to process environment variables (Xcode scheme).
    private static func requiredValue(for key: String) -> String {
        // 1. Info.plist (populated from Secrets.xcconfig at build time — works in App Store builds)
        if let value = Bundle.main.infoDictionary?[key] as? String, !value.isEmpty, !value.hasPrefix("$(") {
            return value
        }
        
        // 2. Process environment (Xcode scheme env vars — works in debug runs)
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }
        
        // Never crash in release — return empty string and let the app show an error state
        #if DEBUG
        fatalError("\(key) not configured. Set up Configuration/Secrets.xcconfig (see Secrets.xcconfig.template).")
        #else
        Log.error("Missing required config: \(key)", category: .general)
        return ""
        #endif
    }
    
    // MARK: - Typesense Configuration
    
    /// Typesense host URL (e.g., "https://your-cluster.a1.typesense.net")
    static let typesenseHost: String = {
        let host = requiredValue(for: "TYPESENSE_HOST")
        
        // Enforce HTTPS — never allow plain HTTP
        if host.hasPrefix("https://") {
            return host
        } else if host.hasPrefix("http://") {
            return "https://" + String(host.dropFirst(7))
        } else {
            return "https://\(host)"
        }
    }()
    
    /// Typesense API key (search-only key, not admin key)
    static let typesenseApiKey: String = {
        return requiredValue(for: "TYPESENSE_API_KEY")
    }()
    
    /// Typesense collection name (fixed as 'products')
    static let typesenseCollection: String = "products"
    
    // MARK: - Backend Configuration
    
    /// Backend URL for feedback and analytics (required)
    static let backendURL: String = {
        let url = requiredValue(for: "BACKEND_URL")
        
        // Enforce HTTPS — never allow plain HTTP
        if url.hasPrefix("https://") {
            return url
        } else if url.hasPrefix("http://") {
            return "https://" + String(url.dropFirst(7))
        } else {
            return "https://\(url)"
        }
    }()
    
    // MARK: - Supabase Configuration
    
    /// Supabase anon/public key for REST API access
    static let supabaseAnonKey: String = {
        return requiredValue(for: "SUPABASE_ANON_KEY")
    }()
    
    // MARK: - OpenAI Configuration
    
    /// OpenAI API key for GPT-4 Vision
    /// ⚠️ SECURITY: This key is only used for LOCAL DEVELOPMENT.
    /// In production, all OpenAI requests go through the scan-proxy edge function
    /// which holds the key server-side. See `scanProxyEnabled`.
    static let openAIAPIKey: String = {
        return requiredValue(for: "OPENAI_API_KEY")
    }()
    
    /// OpenAI Vision API endpoint (direct — used only when proxy is disabled)
    static let openAIVisionEndpoint = "https://api.openai.com/v1/chat/completions"
    
    /// OpenAI Vision model to use
    static let openAIVisionModel = "gpt-4o" // Latest GPT-4 with vision (cheaper + faster than gpt-4-vision-preview)
    
    // MARK: - Scan Proxy Configuration
    
    /// Whether to route OpenAI requests through the backend proxy.
    /// MUST be true for App Store / production builds to keep the OpenAI key server-side.
    /// Set to false only for local development when the edge function isn't deployed yet.
    static let scanProxyEnabled: Bool = {
        #if DEBUG
        // In debug, allow direct OpenAI calls for convenience unless proxy is deployed
        return ProcessInfo.processInfo.environment["USE_SCAN_PROXY"] == "1"
        #else
        // In release, ALWAYS use the proxy — never ship the OpenAI key in the binary
        return true
        #endif
    }()
    
    /// Backend scan proxy URL (Supabase Edge Function)
    /// Deployed at: {BACKEND_URL}/functions/v1/scan-proxy
    static let scanProxyURL: String = {
        let base = backendURL.hasSuffix("/") ? String(backendURL.dropLast()) : backendURL
        return "\(base)/functions/v1/scan-proxy"
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
            _ = supabaseAnonKey
            _ = openAIAPIKey
            return true
        } catch {
            Log.error("Environment validation failed", category: .general)
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
    
    /// Debug description of current environment (redacted for security)
    static var debugDescription: String {
        #if DEBUG
        return """
        BlackScan Environment Configuration:
        - Typesense Host: [CONFIGURED]
        - Typesense API Key: [SET]
        - Collection: \(typesenseCollection)
        - Backend URL: [CONFIGURED]
        - Supabase Key: [SET]
        - OpenAI Key: [SET]
        - OpenAI Model: \(openAIVisionModel)
        - Debug Mode: \(isDebugMode)
        """
        #else
        return "BlackScan [Release]"
        #endif
    }
}
