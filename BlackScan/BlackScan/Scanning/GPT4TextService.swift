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
    /// Cost: ~$0.0003 per call (gpt-4o-mini, ~20x cheaper than Vision API)
    /// - Parameter ocrText: Text extracted from product label via OCR
    /// - Returns: ProductAnalysis with extracted data
    func analyzeOCRText(_ ocrText: String) async throws -> ProductAnalysis {
        // Sanitize and limit OCR text input
        let sanitizedText = String(ocrText.prefix(5000))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !sanitizedText.isEmpty else {
            throw TextError.noContentInResponse
        }
        
        Log.debug("GPT-4 Text: Analyzing OCR text (\(sanitizedText.count) chars)", category: .scan)
        
        // Build request
        let request = try buildTextRequest(ocrText: sanitizedText)
        
        // Make API call with retry
        let (data, response) = try await NetworkSecurity.withRetry(maxAttempts: 2) {
            try await URLSession.shared.data(for: request)
        }
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TextError.invalidResponse
        }
        
        Log.debug("GPT-4 Text: Response status \(httpResponse.statusCode)", category: .scan)
        
        guard httpResponse.statusCode == 200 else {
            Log.error("GPT-4 Text API returned status \(httpResponse.statusCode)", category: .scan)
            throw TextError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw TextError.noContentInResponse
        }
        
        Log.debug("GPT-4 Text: Received response content", category: .scan)
        
        // Parse JSON from response
        let analysis = try parseAnalysisFromContent(content, originalText: sanitizedText)
        
        Log.debug("GPT-4 Text: Extracted product type: \(analysis.productType), confidence: \(Int(analysis.confidence * 100))%", category: .scan)
        
        return analysis
    }
    
    // MARK: - Private Helpers
    
    private func buildTextRequest(ocrText: String) throws -> URLRequest {
        // Route through backend proxy to keep OpenAI key server-side
        let endpoint = Env.scanProxyEnabled
            ? "\(Env.scanProxyURL)/analyze-text"
            : "https://api.openai.com/v1/chat/completions"
        
        guard let url = URL(string: endpoint) else {
            throw TextError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if Env.scanProxyEnabled {
            // Authenticate with backend using Supabase anon key
            request.setValue(Env.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(Env.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        } else {
            // Direct OpenAI access — only for development
            #if !DEBUG
            Log.error("Direct OpenAI access used in release build — deploy scan-proxy edge function", category: .scan)
            #endif
            request.setValue("Bearer \(Env.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        let prompt = """
        You are analyzing OCR text from a product label. The text may be incomplete or have spelling errors due to OCR.
        
        OCR Text:
        \(ocrText)
        
        Extract the following information in JSON format:
        
        {
          "brand": "Brand name (e.g., Garnier, Dove, CeraVe, Purell)",
          "product_type": "Main product category from the list below",
          "form": "Physical form (e.g., gel, spray, cream, oil, stick, liquid, foam, powder, bar, balm)",
          "size": "Size with unit (e.g., 8.5 fl oz, 250ml, 16 oz)",
          "ingredients": ["Key ingredients mentioned"],
          "confidence": 0.95,
          "raw_text": "Original OCR text (cleaned up)"
        }
        
        VALID PRODUCT TYPES — you MUST pick the closest match from this list:
        • Hair: Shampoo, Conditioner, Leave-In Conditioner, Co-Wash, Deep Conditioner, Protein Treatment, Detangler, Hair Rinse, Hair Oil, Castor Oil, Hair Mask, Hair Cream, Hair Gel, Hair Butter, Edge Control, Hair Serum, Curl Cream, Styling Gel, Hair Balm, Hair Spray
        • Skin: Facial Cleanser, Micellar Water, Makeup Remover, Face Serum, Face Cream, Face Mask, Face Oil, Toner, Eye Cream, Moisturizer, Facial Mist, Facial Scrub, Sunscreen, Cleansing Wipes
        • Body: Hand Sanitizer, Body Butter, Body Oil, Essential Oil, Body Mist, Body Scrub, Body Wash, Intimate Wash, Body Lotion, Bar Soap, Deodorant, Body Balm, Hand Soap, Liquid Soap, Body Gloss, Sugar Scrub, Body Powder
        • Lips: Lip Balm, Lip Gloss, Lipstick, Lip Scrub, Liquid Lipstick, Lip Liner, Lip Oil
        • Makeup: Foundation, Setting Powder, Face Powder, Concealer, Mascara, Eyeshadow, Eyeshadow Palette, Blush, Highlighter, Bronzer, Primer, Setting Spray, Eyeliner, Brow Gel, Brow Pencil, Contour, Lash Serum, Tinted Moisturizer, Nail Polish, Gel Polish, False Eyelashes, Cuticle Oil
        • Fragrance: Perfume, Eau de Parfum, Perfume Oil
        • Men: Beard Oil, Beard Balm, Beard Conditioner
        • Home: Multi-Purpose Cleaner, Glass Cleaner, Floor Cleaner, Dish Soap, Laundry Detergent, Fabric Softener, Disinfectant
        • Other: Scented Candle, Vitamins, Dietary Supplements, Tea
        
        CRITICAL RULES:
        1. "product_type" MUST be a SPECIFIC product type from the list above, never an ingredient or broad category.
           ✓ "Coconut Water Curl Gel" → product_type: "Hair Gel"
           ✓ "Shea Butter Hand Cream" → product_type: "Body Butter"  
           ✓ "Vitamin E Body Lotion" → product_type: "Body Lotion"
           ✓ Foundation powder compact → product_type: "Foundation" or "Face Powder"
           ✓ Multi-purpose spray cleaner → product_type: "Multi-Purpose Cleaner"
           ✗ NEVER return an ingredient (coconut water, shea butter, aloe vera) as product_type
           ✗ NEVER return a broad category like "Makeup", "Skincare", "Hair Care", "Beauty", "Cleaning Products", "Other" — always be specific
        
        2. OIL PRODUCTS — distinguish between oils that ARE the product vs oils used as ingredients:
           ✓ "Jamaican Black Castor Oil" → product_type: "Castor Oil" (the oil itself IS the product)
           ✓ "Pure Tea Tree Oil" → product_type: "Essential Oil" (a standalone essential oil)
           ✓ "Hair Growth Oil with Castor Oil & Argan" → product_type: "Hair Oil" (a blended hair oil; castor/argan are just ingredients)
           ✓ "Rosemary Mint Scalp Oil" → product_type: "Hair Oil" (a formulated scalp treatment oil)
           ✓ "Argan Oil Face Serum" → product_type: "Face Oil" (argan is an ingredient, the product is a face oil)
           Rule: If the product is JUST a single named oil (castor, tea tree, argan, jojoba, etc.) with no other purpose, use "Castor Oil" or "Essential Oil". If it's a formulated product FOR hair/body/face that happens to contain oils, use "Hair Oil", "Body Oil", or "Face Oil".
        
        3. OCR may have errors — use context to infer correct words.
           Example: "COMANT" → likely "GARNIER" based on surrounding text
        
        4. "form" is how the product is physically dispensed (gel, spray, cream, etc.)
           It is SEPARATE from product_type. Example: "Hand Sanitizer Gel" → product_type: "Hand Sanitizer", form: "gel"
        
        5. "confidence" should reflect OCR quality and your certainty:
           - Clear product info, matches a known type: 0.9-1.0
           - Some OCR errors but product is identifiable: 0.7-0.9
           - Many errors or unclear what the product is: <0.7
        
        6. Common brands: Dove, Garnier, Purell, CeraVe, Neutrogena, L'Oréal, Revlon, Covergirl, Maybelline, Pantene, Olay, Aveeno, Nivea
        
        Return ONLY the JSON, no other text.
        """
        
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
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
                return "Unable to connect to analysis service."
            case .invalidResponse:
                return "Received an unexpected response. Please try again."
            case .apiError:
                return "Analysis service is temporarily unavailable. Please try again."
            case .noContentInResponse:
                return "Could not analyze the text. Please try again with a clearer photo."
            case .invalidJSONResponse:
                return "Could not process the analysis result. Please try again."
            }
        }
    }
}
