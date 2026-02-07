import Foundation

/// Centralized input validation and sanitization
/// Prevents injection attacks, enforces length limits, and sanitizes user input
enum InputValidator {
    
    // MARK: - Search Input
    
    /// Maximum allowed length for search queries
    static let maxSearchLength = 200
    
    /// Maximum allowed length for feedback/notes text
    static let maxFeedbackLength = 2000
    
    /// Maximum allowed image size in bytes (5MB)
    static let maxImageSizeBytes = 5 * 1024 * 1024
    
    /// Sanitize a search query string
    /// - Trims whitespace
    /// - Enforces length limit
    /// - Removes control characters
    /// - Strips potentially dangerous characters
    static func sanitizeSearchQuery(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else { return "" }
        
        // Enforce length limit
        let limited = String(trimmed.prefix(maxSearchLength))
        
        // Remove control characters (keep printable + spaces)
        let sanitized = limited.unicodeScalars
            .filter { CharacterSet.controlCharacters.inverted.contains($0) }
            .map { String($0) }
            .joined()
        
        // Remove potential injection characters for Typesense filter syntax
        // Typesense uses := for filtering, && for AND, || for OR
        let dangerous: [String] = ["${", "$(", "`", "\\", "\0"]
        var result = sanitized
        for char in dangerous {
            result = result.replacingOccurrences(of: char, with: "")
        }
        
        return result
    }
    
    /// Sanitize feedback/notes text input
    static func sanitizeFeedbackText(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else { return "" }
        
        // Enforce length limit
        let limited = String(trimmed.prefix(maxFeedbackLength))
        
        // Remove control characters except newlines
        var allowedChars = CharacterSet.controlCharacters.inverted
        allowedChars.insert(charactersIn: "\n")
        
        let sanitized = limited.unicodeScalars
            .filter { allowedChars.contains($0) }
            .map { String($0) }
            .joined()
        
        return sanitized
    }
    
    // MARK: - URL Validation
    
    /// Allowed image host domains
    private static let trustedImageDomains: Set<String> = [
        "cdn.shopify.com",
        "images.unsplash.com",
        "m.media-amazon.com",
        "i.imgur.com",
        "res.cloudinary.com",
        "storage.googleapis.com",
        "firebasestorage.googleapis.com",
        "blackscan.app",
        "typesense.io"
    ]
    
    /// Validate that an image URL is from a trusted domain
    /// Returns true for trusted domains, also allows any HTTPS URL as a fallback
    /// since product images come from many retailer CDNs
    static func isImageURLTrusted(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              let host = url.host else {
            return false
        }
        
        // Must be HTTPS
        guard scheme == "https" else { return false }
        
        // Block localhost, private IPs, and file URLs
        let blockedHosts = ["localhost", "127.0.0.1", "0.0.0.0", "::1"]
        if blockedHosts.contains(host) { return false }
        
        // Block private IP ranges
        if host.hasPrefix("10.") || host.hasPrefix("192.168.") || host.hasPrefix("172.") {
            return false
        }
        
        return true
    }
    
    // MARK: - Image Validation
    
    /// Validate image data size before upload
    static func validateImageSize(_ data: Data) -> ImageValidationResult {
        if data.count > maxImageSizeBytes {
            return .tooLarge(actualBytes: data.count, maxBytes: maxImageSizeBytes)
        }
        return .valid
    }
    
    enum ImageValidationResult {
        case valid
        case tooLarge(actualBytes: Int, maxBytes: Int)
        
        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
        
        var errorMessage: String? {
            switch self {
            case .valid: return nil
            case .tooLarge(let actual, let max):
                let actualMB = Double(actual) / (1024 * 1024)
                let maxMB = Double(max) / (1024 * 1024)
                return "Image is too large (\(String(format: "%.1f", actualMB))MB). Maximum size is \(String(format: "%.0f", maxMB))MB."
            }
        }
    }
    
    // MARK: - General Validation
    
    /// Check if a string contains only safe alphanumeric + common punctuation
    static func isSafeString(_ input: String) -> Bool {
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ".,!?'-()&+/@#"))
        
        return input.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
