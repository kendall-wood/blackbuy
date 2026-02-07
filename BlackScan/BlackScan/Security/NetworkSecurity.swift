import Foundation

/// Network security utilities including retry logic and request hardening
enum NetworkSecurity {
    
    // MARK: - Retry Logic
    
    /// Execute an async operation with exponential backoff retry
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (default: 3)
    ///   - initialDelay: Initial delay in seconds before first retry (default: 1.0)
    ///   - maxDelay: Maximum delay between retries in seconds (default: 10.0)
    ///   - shouldRetry: Closure to determine if the error is retryable (default: retries network errors)
    ///   - operation: The async operation to retry
    /// - Returns: The result of the successful operation
    static func withRetry<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 10.0,
        shouldRetry: ((Error) -> Bool)? = nil,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry
                let retryable = shouldRetry?(error) ?? isRetryableError(error)
                
                if attempt < maxAttempts && retryable {
                    Log.debug("Retry attempt \(attempt)/\(maxAttempts) after \(String(format: "%.1f", delay))s delay", category: .network)
                    
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                    // Exponential backoff with jitter
                    delay = min(delay * 2.0 + Double.random(in: 0...0.5), maxDelay)
                } else {
                    break
                }
            }
        }
        
        throw lastError ?? NetworkSecurityError.maxRetriesExceeded
    }
    
    /// Determine if an error is retryable
    private static func isRetryableError(_ error: Error) -> Bool {
        // URLError codes that are transient / retryable
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        
        // Typesense HTTP errors that are retryable (5xx server errors, 429 rate limit)
        if let typesenseError = error as? TypesenseError {
            switch typesenseError {
            case .httpError(let code):
                return code >= 500 || code == 429
            case .networkError:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    // MARK: - Secure URLSession Configuration
    
    /// Create a hardened URLSession configuration
    static func secureSessionConfiguration(
        timeout: TimeInterval = Env.requestTimeout
    ) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        
        // Timeouts
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        
        // Enforce TLS 1.2 minimum
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        
        // Disable caching for API requests (use app-level caching instead)
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        // Limit concurrent connections
        config.httpMaximumConnectionsPerHost = 4
        
        // Disable cookies for API calls (not needed for Typesense/OpenAI)
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        
        return config
    }
    
    // MARK: - Error Types
    
    enum NetworkSecurityError: LocalizedError {
        case maxRetriesExceeded
        case untrustedURL
        
        var errorDescription: String? {
            switch self {
            case .maxRetriesExceeded:
                return "Request failed after multiple attempts. Please check your connection and try again."
            case .untrustedURL:
                return "The requested resource is not available."
            }
        }
    }
}
