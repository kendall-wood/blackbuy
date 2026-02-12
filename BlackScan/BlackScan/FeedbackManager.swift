import Foundation
import SwiftUI
import UIKit

/// Manages user feedback and report submissions with Supabase integration.
/// Supports both legacy scan feedback and the new hierarchical shake-to-report system.
@MainActor
class FeedbackManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSubmitting = false
    @Published var lastError: String?
    
    // MARK: - Legacy Issue Types (kept for backward compatibility with scan feedback)
    
    enum IssueType: String, CaseIterable, Identifiable {
        case noDetection = "Couldn't detect product"
        case slowScan = "Scan took too long"
        case cameraFocus = "Camera won't focus"
        case wrongProduct = "Wrong product detected"
        case noAlternatives = "No alternatives found"
        case wrongPrice = "Wrong price shown"
        case missingImage = "Wrong/missing image"
        case brokenLink = "Store link broken"
        case appCrash = "App crashed/froze"
        case featureRequest = "Feature request"
        case other = "Other issue"
        
        var id: String { rawValue }
        
        var emoji: String {
            switch self {
            case .noDetection: return "❌"
            case .slowScan: return "🔄"
            case .cameraFocus: return "📷"
            case .wrongProduct: return "🎯"
            case .noAlternatives: return "🔍"
            case .wrongPrice: return "💰"
            case .missingImage: return "🖼️"
            case .brokenLink: return "🏪"
            case .appCrash: return "🐛"
            case .featureRequest: return "💡"
            case .other: return "❓"
            }
        }
        
        var category: String {
            switch self {
            case .noDetection, .slowScan, .cameraFocus, .wrongProduct:
                return "Scanning"
            case .noAlternatives, .wrongPrice, .missingImage, .brokenLink:
                return "Search/Results"
            case .appCrash, .featureRequest, .other:
                return "General"
            }
        }
    }
    
    // MARK: - Report Page (shake-to-report hierarchy)
    
    /// Top-level pages the user can report issues for.
    enum ReportPage: String, CaseIterable, Identifiable {
        case scan = "Scan"
        case shop = "Shop"
        case checkoutManager = "Checkout Manager"
        case saved = "Saved"
        case recentScans = "Recent Scans"
        case profile = "Profile"
        case companyView = "Brand View"
        
        var id: String { rawValue }
        
        /// SF Symbol icon name matching the app's existing navigation icons.
        /// Note: Checkout uses a custom asset "cart_icon", represented here as nil.
        var sfSymbol: String? {
            switch self {
            case .scan: return "camera"
            case .shop: return "storefront"
            case .checkoutManager: return nil // uses custom "cart_icon" asset
            case .saved: return "heart"
            case .recentScans: return "clock.arrow.circlepath"
            case .profile: return "person.crop.circle"
            case .companyView: return "tag"
            }
        }
        
        /// Whether this page uses a custom image asset instead of an SF Symbol.
        var customImageAsset: String? {
            switch self {
            case .checkoutManager: return "cart_icon"
            default: return nil
            }
        }
        
        /// Categories available for this page.
        var categories: [ReportCategory] {
            switch self {
            case .scan:
                return [.wrongScanResults, .buttonIssue, .animationIssue, .cameraNotWorking]
            case .shop:
                return [.pageIssue, .brandIssue, .productIssue, .searchIssue, .categoriesIssue]
            case .checkoutManager:
                return [.pageIssue, .brandIssue, .productIssue]
            case .saved:
                return [.pageIssue, .brandIssue, .productIssue]
            case .recentScans:
                return [.wrongScanResults]
            case .profile:
                return [.appleIDIssue, .dataIssue, .privacyPolicyIssue]
            case .companyView:
                return [.brandNameIssue, .pageIssue, .productIssue]
            }
        }
        
        /// Map from AppTab to ReportPage for auto-detection.
        static func from(tab: AppTab) -> ReportPage {
            switch tab {
            case .scan: return .scan
            case .shop: return .shop
            case .checkout: return .checkoutManager
            case .saved: return .saved
            case .profile: return .profile
            }
        }
    }
    
    /// Mid-level report categories.
    enum ReportCategory: String, CaseIterable, Identifiable {
        case wrongScanResults = "Wrong scan results"
        case buttonIssue = "Button issue"
        case animationIssue = "Animation issue"
        case pageIssue = "Page issue"
        case brandIssue = "Brand issue"
        case productIssue = "Product issue"
        case searchIssue = "Search issue"
        case appleIDIssue = "Apple ID issue"
        case dataIssue = "Data issue"
        case privacyPolicyIssue = "Privacy policy issue"
        case brandNameIssue = "Brand name issue"
        case categoriesIssue = "Categories issue"
        case cameraNotWorking = "Camera not working"
        
        var id: String { rawValue }
        
        /// Sub-categories if this category has a deeper drill-down.
        var subCategories: [ReportSubCategory]? {
            switch self {
            case .productIssue:
                return [
                    .productImageIssue, .productNameIssue, .productPriceIssue,
                    .productLinkIssue, .productCategoriesIssue, .similarProductsIssue
                ]
            default:
                return nil
            }
        }
    }
    
    /// Deepest sub-categories (e.g. under Product Issue).
    enum ReportSubCategory: String, CaseIterable, Identifiable {
        case productImageIssue = "Product image issue"
        case productNameIssue = "Product name issue"
        case productPriceIssue = "Product price issue"
        case productLinkIssue = "Product link issue"
        case productCategoriesIssue = "Product categories issue"
        case similarProductsIssue = "Similar products issue"
        
        var id: String { rawValue }
        
        /// Detail options if this sub-category has a deeper level.
        var details: [ReportDetail]? {
            switch self {
            case .productLinkIssue:
                return [.productNotAvailable, .wrongProduct]
            default:
                return nil
            }
        }
    }
    
    /// Deepest detail level (e.g. under Product Link Issue).
    enum ReportDetail: String, CaseIterable, Identifiable {
        case productNotAvailable = "This product is not available"
        case wrongProduct = "Wrong product"
        
        var id: String { rawValue }
    }
    
    // MARK: - Data Models
    
    struct FeedbackData {
        let userId: String
        let timestamp: Date
        let issueType: IssueType
        let context: FeedbackContext?
        let userNotes: String?
        
        var jsonPayload: [String: Any] {
            var payload: [String: Any] = [
                "user_id": userId,
                "timestamp": ISO8601DateFormatter().string(from: timestamp),
                "issue_type": issueType.rawValue,
                "issue_category": issueType.category,
                "user_notes": userNotes ?? ""
            ]
            
            if let context = context {
                payload["scan_context"] = [
                    "scan_text": context.scanText ?? "",
                    "detected_product": context.detectedProduct ?? "",
                    "search_query": context.searchQuery ?? "",
                    "results_count": context.resultsCount ?? 0,
                    "confidence": context.confidence ?? 0.0
                ]
            }
            
            return payload
        }
    }
    
    struct FeedbackContext {
        let scanText: String?
        let detectedProduct: String?
        let searchQuery: String?
        let resultsCount: Int?
        let confidence: Float?
    }
    
    /// Data model for the hierarchical shake-to-report system.
    struct ReportData {
        let userId: String
        let timestamp: Date
        let page: ReportPage
        let category: ReportCategory
        let subCategory: ReportSubCategory?
        let detail: ReportDetail?
        let userNotes: String?
        let productName: String?
        let productCompany: String?
        let productId: String?
        let reportedCategory: String?
        
        var jsonPayload: [String: Any] {
            var payload: [String: Any] = [
                "user_id": userId,
                "timestamp": ISO8601DateFormatter().string(from: timestamp),
                "page": page.rawValue,
                "category": category.rawValue,
                "user_notes": userNotes ?? "",
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "device_info": "\(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"
            ]
            
            if let subCategory = subCategory {
                payload["sub_category"] = subCategory.rawValue
            }
            
            if let detail = detail {
                payload["detail"] = detail.rawValue
            }
            
            if let productName = productName {
                payload["product_name"] = productName
            }
            if let productCompany = productCompany {
                payload["product_company"] = productCompany
            }
            if let productId = productId {
                payload["product_id"] = productId
            }
            if let reportedCategory = reportedCategory {
                payload["reported_category"] = reportedCategory
            }
            
            return payload
        }
    }
    
    // MARK: - Public Methods
    
    /// Submit legacy feedback to backend/Supabase (used by scan results "Not what you were looking for?")
    func submitFeedback(_ data: FeedbackData) async throws {
        isSubmitting = true
        lastError = nil
        
        defer {
            isSubmitting = false
        }
        
        // Backend endpoint
        guard let url = URL(string: "\(Env.backendURL)/api/feedback") else {
            throw FeedbackError.invalidURL
        }
        
        // Sanitize feedback payload
        var sanitizedPayload = data.jsonPayload
        if let notes = sanitizedPayload["user_notes"] as? String {
            sanitizedPayload["user_notes"] = InputValidator.sanitizeFeedbackText(notes)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Env.requestTimeout
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: sanitizedPayload)
            
            let (_, response) = try await NetworkSecurity.withRetry(maxAttempts: 2) {
                try await URLSession.shared.data(for: request)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FeedbackError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                Log.error("Feedback submission failed with status \(httpResponse.statusCode)", category: .network)
                throw FeedbackError.submissionFailed
            }
            
            Log.info("Feedback submitted successfully", category: .general)
            
        } catch let error as FeedbackError {
            lastError = error.localizedDescription
            throw error
        } catch {
            lastError = FeedbackError.submissionFailed.localizedDescription
            throw FeedbackError.networkError(error)
        }
    }
    
    /// Submit a hierarchical report from the shake-to-report system.
    func submitReport(_ data: ReportData) async throws {
        isSubmitting = true
        lastError = nil
        
        defer {
            isSubmitting = false
        }
        
        guard let url = URL(string: "\(Env.backendURL)/api/reports") else {
            throw FeedbackError.invalidURL
        }
        
        var sanitizedPayload = data.jsonPayload
        if let notes = sanitizedPayload["user_notes"] as? String {
            sanitizedPayload["user_notes"] = InputValidator.sanitizeFeedbackText(notes)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Env.requestTimeout
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: sanitizedPayload)
            
            let (_, response) = try await NetworkSecurity.withRetry(maxAttempts: 2) {
                try await URLSession.shared.data(for: request)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FeedbackError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                Log.error("Report submission failed with status \(httpResponse.statusCode)", category: .network)
                throw FeedbackError.submissionFailed
            }
            
            Log.info("Report submitted successfully: \(data.page.rawValue) > \(data.category.rawValue)", category: .general)
            
        } catch let error as FeedbackError {
            lastError = error.localizedDescription
            throw error
        } catch {
            lastError = FeedbackError.submissionFailed.localizedDescription
            throw FeedbackError.networkError(error)
        }
    }
}

// MARK: - Errors

enum FeedbackError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case networkError(Error)
    case submissionFailed
    
    /// User-facing error descriptions (no internal details)
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Unable to submit feedback at this time. Please try again later."
        case .invalidResponse:
            return "Received an unexpected response. Please try again."
        case .serverError:
            return "Unable to submit feedback. Please try again later."
        case .networkError:
            return "Network connection error. Please check your connection and try again."
        case .submissionFailed:
            return "Failed to submit feedback. Please try again."
        }
    }
}

