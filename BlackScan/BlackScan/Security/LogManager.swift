import Foundation
import os.log

/// Production-safe logging utility
/// All log output is stripped in Release builds to prevent information leakage
enum Log {
    
    private static let subsystem = "com.blackscan"
    
    // OS Log categories
    private static let networkLogger = Logger(subsystem: subsystem, category: "network")
    private static let authLogger = Logger(subsystem: subsystem, category: "auth")
    private static let scanLogger = Logger(subsystem: subsystem, category: "scan")
    private static let storageLogger = Logger(subsystem: subsystem, category: "storage")
    private static let generalLogger = Logger(subsystem: subsystem, category: "general")
    
    // MARK: - Public Logging Methods
    
    /// Log debug information (DEBUG builds only)
    static func debug(_ message: String, category: Category = .general) {
        #if DEBUG
        logger(for: category).debug("\(message, privacy: .private)")
        #endif
    }
    
    /// Log informational messages (DEBUG builds only)
    static func info(_ message: String, category: Category = .general) {
        #if DEBUG
        logger(for: category).info("\(message, privacy: .private)")
        #endif
    }
    
    /// Log warnings (DEBUG builds only, no sensitive data)
    static func warning(_ message: String, category: Category = .general) {
        #if DEBUG
        logger(for: category).warning("\(message, privacy: .private)")
        #endif
    }
    
    /// Log errors (always logged but with redacted details in Release)
    static func error(_ message: String, category: Category = .general) {
        #if DEBUG
        logger(for: category).error("\(message, privacy: .private)")
        #else
        // In Release, log only the category and a generic message
        logger(for: category).error("Error in \(category.rawValue, privacy: .public)")
        #endif
    }
    
    // MARK: - Categories
    
    enum Category: String {
        case network
        case auth
        case scan
        case storage
        case general
    }
    
    // MARK: - Private
    
    private static func logger(for category: Category) -> Logger {
        switch category {
        case .network: return networkLogger
        case .auth: return authLogger
        case .scan: return scanLogger
        case .storage: return storageLogger
        case .general: return generalLogger
        }
    }
}
