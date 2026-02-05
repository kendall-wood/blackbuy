import Foundation
import UIKit

/// Service for analyzing product images using OpenAI GPT-4 Vision
/// Replaces VisionKit OCR with AI-powered product recognition
class OpenAIVisionService {
    
    static let shared = OpenAIVisionService()
    
    private init() {}
    
    // MARK: - Models
    
    /// Structured product data extracted from image
    struct ProductAnalysis: Codable {
        let brand: String?
        let productType: String
        let form: String?
        let size: String?
        let ingredients: [String]
        let confidence: Double
        let rawText: String
        
        enum CodingKeys: String, CodingKey {
            case brand
            case productType = "product_type"
            case form
            case size
            case ingredients
            case confidence
            case rawText = "raw_text"
        }
    }
    
    // MARK: - Public API
    
    /// Analyze a product image and extract structured data
    /// - Parameter image: UIImage of the product label
    /// - Returns: ProductAnalysis with extracted data
    func analyzeProduct(image: UIImage) async throws -> ProductAnalysis {
        // Compress image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw VisionError.imageCompressionFailed
        }
        
        let base64Image = imageData.base64EncodedString()
        
        if Env.isDebugMode {
            print("🤖 OpenAI Vision: Analyzing image (\(imageData.count / 1024)KB)")
        }
        
        // Build request
        let request = try buildVisionRequest(base64Image: base64Image)
        
        // Make API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VisionError.invalidResponse
        }
        
        if Env.isDebugMode {
            print("🤖 OpenAI Vision: Response status \(httpResponse.statusCode)")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ OpenAI Vision Error: \(errorString)")
            }
            throw VisionError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw VisionError.noContentInResponse
        }
        
        if Env.isDebugMode {
            print("🤖 OpenAI Vision: Raw response:\n\(content)")
        }
        
        // Parse JSON from response
        let analysis = try parseAnalysisFromContent(content)
        
        if Env.isDebugMode {
            print("✅ OpenAI Vision: Extracted product type: \(analysis.productType)")
            print("   Brand: \(analysis.brand ?? "unknown")")
            print("   Form: \(analysis.form ?? "unknown")")
            print("   Confidence: \(Int(analysis.confidence * 100))%")
        }
        
        return analysis
    }
    
    // MARK: - Private Helpers
    
    private func buildVisionRequest(base64Image: String) throws -> URLRequest {
        guard let url = URL(string: Env.openAIVisionEndpoint) else {
            throw VisionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Env.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        let prompt = """
        Analyze this product label and extract the following information in JSON format:
        
        {
          "brand": "Brand name (e.g., Garnier, Dove, CeraVe)",
          "product_type": "Main product category (e.g., Curl Defining Gel, Hand Sanitizer, Body Lotion, Shampoo, Deodorant)",
          "form": "Dispensing method (e.g., spray, gel, cream, oil, stick, bar, liquid, foam, powder)",
          "size": "Size with unit (e.g., 8.5 fl oz, 250ml, 16 oz)",
          "ingredients": ["Key ingredients mentioned on the label"],
          "confidence": 0.95,
          "raw_text": "All visible text on the label"
        }
        
        IMPORTANT RULES:
        1. "product_type" should be the MAIN product category, not an ingredient
           - Example: If it says "Curl Gel with Coconut Water", product_type is "Curl Defining Gel", NOT "Coconut Water"
           - Example: If it says "Hand Sanitizer Gel", product_type is "Hand Sanitizer", form is "gel"
        
        2. "form" is how the product is dispensed (spray, gel, cream, oil, stick, bar, etc)
        
        3. "ingredients" are KEY ingredients listed (like "coconut water", "shea butter", "vitamin E")
        
        4. "confidence" should be 0.0-1.0 based on how clear the label is
        
        5. Extract ALL visible text into "raw_text"
        
        Return ONLY the JSON, no other text.
        """
        
        let payload: [String: Any] = [
            "model": Env.openAIVisionModel,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 500,
            "temperature": 0.0 // Deterministic output
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        return request
    }
    
    private func parseAnalysisFromContent(_ content: String) throws -> ProductAnalysis {
        // Remove markdown code blocks if present
        var jsonString = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to extract JSON if there's extra text
        if let jsonStart = jsonString.firstIndex(of: "{"),
           let jsonEnd = jsonString.lastIndex(of: "}") {
            jsonString = String(jsonString[jsonStart...jsonEnd])
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            throw VisionError.invalidJSONResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ProductAnalysis.self, from: data)
    }
    
    // MARK: - Supporting Types
    
    private struct OpenAIResponse: Codable {
        let choices: [Choice]
        
        struct Choice: Codable {
            let message: Message
            
            struct Message: Codable {
                let content: String
            }
        }
    }
    
    enum VisionError: LocalizedError {
        case imageCompressionFailed
        case invalidURL
        case invalidResponse
        case apiError(statusCode: Int)
        case noContentInResponse
        case invalidJSONResponse
        
        var errorDescription: String? {
            switch self {
            case .imageCompressionFailed:
                return "Failed to compress image"
            case .invalidURL:
                return "Invalid OpenAI API URL"
            case .invalidResponse:
                return "Invalid response from OpenAI"
            case .apiError(let statusCode):
                return "OpenAI API error: \(statusCode)"
            case .noContentInResponse:
                return "No content in OpenAI response"
            case .invalidJSONResponse:
                return "Could not parse JSON from OpenAI response"
            }
        }
    }
}
