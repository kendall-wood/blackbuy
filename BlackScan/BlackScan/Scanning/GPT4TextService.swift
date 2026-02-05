import Foundation

/// Service for analyzing OCR text using GPT-4 Text API (10x cheaper than Vision)
/// Used when OCR quality is good enough
class GPT4TextService {
    
    static let shared = GPT4TextService()
    
    private init() {}
    
    // MARK: - Models
    
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
    
    /// Analyze OCR text and extract structured product data
    /// Cost: ~$0.001 per call (10x cheaper than Vision API)
    /// - Parameter ocrText: Text extracted from product label via OCR
    /// - Returns: ProductAnalysis with extracted data
    func analyzeOCRText(_ ocrText: String) async throws -> ProductAnalysis {
        if Env.isDebugMode {
            print("💬 GPT-4 Text: Analyzing OCR text (\(ocrText.count) chars)")
        }
        
        // Build request
        let request = try buildTextRequest(ocrText: ocrText)
        
        // Make API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TextError.invalidResponse
        }
        
        if Env.isDebugMode {
            print("💬 GPT-4 Text: Response status \(httpResponse.statusCode)")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ GPT-4 Text Error: \(errorString)")
            }
            throw TextError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw TextError.noContentInResponse
        }
        
        if Env.isDebugMode {
            print("💬 GPT-4 Text: Raw response:\n\(content)")
        }
        
        // Parse JSON from response
        let analysis = try parseAnalysisFromContent(content, originalText: ocrText)
        
        if Env.isDebugMode {
            print("✅ GPT-4 Text: Extracted product type: \(analysis.productType)")
            print("   Brand: \(analysis.brand ?? "unknown")")
            print("   Form: \(analysis.form ?? "unknown")")
            print("   Confidence: \(Int(analysis.confidence * 100))%")
            print("   💰 Cost: ~$0.001 (text API)")
        }
        
        return analysis
    }
    
    // MARK: - Private Helpers
    
    private func buildTextRequest(ocrText: String) throws -> URLRequest {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw TextError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Env.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        let prompt = """
        You are analyzing OCR text from a product label. The text may be incomplete or have spelling errors due to OCR.
        
        OCR Text:
        \(ocrText)
        
        Extract the following information in JSON format:
        
        {
          "brand": "Brand name (e.g., Garnier, Dove, CeraVe, Purell)",
          "product_type": "Main product category (e.g., Hand Sanitizer, Body Lotion, Shampoo)",
          "form": "Dispensing method (e.g., gel, spray, cream, oil, stick, liquid, foam, powder)",
          "size": "Size with unit (e.g., 8.5 fl oz, 250ml, 16 oz)",
          "ingredients": ["Key ingredients mentioned"],
          "confidence": 0.95,
          "raw_text": "Original OCR text (cleaned up)"
        }
        
        IMPORTANT RULES:
        1. OCR may have errors - use context to infer correct words
           Example: "COMANT" → likely "GARNIER" based on context
        
        2. "product_type" should be the MAIN category, not ingredients
           Example: "Hand Sanitizer Gel" → product_type is "Hand Sanitizer"
        
        3. "form" is how the product is dispensed (gel, spray, cream, etc)
        
        4. "confidence" should reflect OCR quality and certainty
           - High quality OCR + clear product info: 0.9-1.0
           - Some OCR errors but clear product: 0.7-0.9
           - Many errors or unclear product: <0.7
        
        5. Common brands to recognize: Dove, Garnier, Purell, CeraVe, Neutrogena, L'Oréal, Revlon, Covergirl, Maybelline
        
        Return ONLY the JSON, no other text.
        """
        
        let payload: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                [
                    "role": "system",
                    "content": "You are an expert at parsing product labels from OCR text. You handle OCR errors intelligently."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 500,
            "temperature": 0.0  // Deterministic output
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        return request
    }
    
    private func parseAnalysisFromContent(_ content: String, originalText: String) throws -> ProductAnalysis {
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
            throw TextError.invalidJSONResponse
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
    
    enum TextError: LocalizedError {
        case invalidURL
        case invalidResponse
        case apiError(statusCode: Int)
        case noContentInResponse
        case invalidJSONResponse
        
        var errorDescription: String? {
            switch self {
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
