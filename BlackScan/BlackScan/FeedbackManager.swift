import Foundation
import SwiftUI

/// Manages user feedback submissions with Supabase integration
/// Allows users to report issues with scans, products, and general app problems
@MainActor
class FeedbackManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSubmitting = false
    @Published var lastError: String?
    
    // MARK: - Issue Types
    
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
    
    // MARK: - Public Methods
    
    /// Submit feedback to backend/Supabase
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
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data.jsonPayload)
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FeedbackError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                // Try to parse error message
                if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let errorMessage = errorJson["error"] as? String {
                    throw FeedbackError.serverError(errorMessage)
                }
                throw FeedbackError.serverError("Failed with status \(httpResponse.statusCode)")
            }
            
            print("✅ Feedback submitted successfully")
            
        } catch let error as FeedbackError {
            lastError = error.localizedDescription
            throw error
        } catch {
            lastError = error.localizedDescription
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
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid feedback endpoint URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .submissionFailed:
            return "Failed to submit feedback"
        }
    }
}

