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
        // Compress image to base64 (0.5 = good balance of quality vs speed)
        // Lower quality = faster upload, cheaper API costs, still accurate for text
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            throw VisionError.imageCompressionFailed
        }
        
        // Validate image size before upload
        let validation = InputValidator.validateImageSize(imageData)
        guard validation.isValid else {
            Log.warning("Image too large for Vision API: \(imageData.count) bytes", category: .scan)
            // Re-compress at lower quality if too large
            guard let smallerData = image.jpegData(compressionQuality: 0.2) else {
                throw VisionError.imageCompressionFailed
            }
            let revalidation = InputValidator.validateImageSize(smallerData)
            guard revalidation.isValid else {
                throw VisionError.imageTooLarge
            }
            return try await analyzeImageData(smallerData)
        }
        
        return try await analyzeImageData(imageData)
    }
    
    private func analyzeImageData(_ imageData: Data) async throws -> ProductAnalysis {
        let base64Image = imageData.base64EncodedString()
        
        Log.debug("Vision API: Analyzing image (\(imageData.count / 1024)KB)", category: .scan)
        
        // Build request
        let request = try buildVisionRequest(base64Image: base64Image)
        
        // Make API call with retry
        let (data, response) = try await NetworkSecurity.withRetry(maxAttempts: 2) {
            try await URLSession.shared.data(for: request)
        }
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VisionError.invalidResponse
        }
        
        Log.debug("Vision API: Response status \(httpResponse.statusCode)", category: .scan)
        
        guard httpResponse.statusCode == 200 else {
            Log.error("Vision API returned status \(httpResponse.statusCode)", category: .scan)
            throw VisionError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw VisionError.noContentInResponse
        }
        
        Log.debug("Vision API: Received response content", category: .scan)
        
        // Parse JSON from response
        let analysis = try parseAnalysisFromContent(content)
        
        Log.debug("Vision API: Extracted product type: \(analysis.productType), confidence: \(Int(analysis.confidence * 100))%", category: .scan)
        
        return analysis
    }
    
    // MARK: - Private Helpers
    
    private func buildVisionRequest(base64Image: String) throws -> URLRequest {
        // Route through backend proxy to keep OpenAI key server-side
        let endpoint = Env.scanProxyEnabled
            ? "\(Env.scanProxyURL)/analyze-image"
            : Env.openAIVisionEndpoint
        
        guard let url = URL(string: endpoint) else {
            throw VisionError.invalidURL
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
        Analyze this product label and extract the following information in JSON format:
        
        {
          "brand": "Brand name (e.g., Garnier, Dove, CeraVe)",
          "product_type": "Main product category from the list below",
          "form": "Physical form (e.g., spray, gel, cream, oil, stick, bar, liquid, foam, powder, balm)",
          "size": "Size with unit (e.g., 8.5 fl oz, 250ml, 16 oz)",
          "ingredients": ["Key ingredients mentioned on the label"],
          "confidence": 0.95,
          "raw_text": "All visible text on the label"
        }
        
        VALID PRODUCT TYPES — you MUST pick the closest match from this list:
        • Hair: Shampoo, Conditioner, Leave-In Conditioner, Co-Wash, Deep Conditioner, Protein Treatment, Detangler, Hair Rinse, Hair Oil, Castor Oil, Hair Mask, Hair Cream, Hair Gel, Hair Butter, Edge Control, Hair Serum, Curl Cream, Styling Gel, Hair Balm, Hair Spray
        • Skin: Facial Cleanser, Micellar Water, Makeup Remover, Face Serum, Face Cream, Face Mask, Face Oil, Toner, Eye Cream, Moisturizer, Facial Mist, Facial Scrub, Sunscreen, Cleansing Wipes
        • Body: Hand Sanitizer, Body Butter, Body Oil, Essential Oil, Body Mist, Body Scrub, Body Wash, Intimate Wash, Body Lotion, Hand Lotion, Hand Cream, Bar Soap, Deodorant, Body Balm, Hand Soap, Liquid Soap, Body Gloss, Sugar Scrub, Body Powder
        • Lips: Lip Balm, Lip Gloss, Lipstick, Lip Scrub, Liquid Lipstick, Lip Liner, Lip Oil
        • Makeup: Foundation, Setting Powder, Face Powder, Concealer, Mascara, Eyeshadow, Eyeshadow Palette, Blush, Highlighter, Bronzer, Primer, Setting Spray, Eyeliner, Brow Gel, Brow Pencil, Contour, Lash Serum, Tinted Moisturizer, Nail Polish, Gel Polish, False Eyelashes, Cuticle Oil
        • Fragrance: Perfume, Eau de Parfum, Perfume Oil
        • Men: Beard Oil, Beard Balm, Beard Conditioner
        • Home: Multi-Purpose Cleaner, Glass Cleaner, Floor Cleaner, Dish Soap, Laundry Detergent, Fabric Softener, Disinfectant
        • Other: Scented Candle, Vitamins, Dietary Supplements, Tea
        
        CRITICAL RULES:
        1. "product_type" MUST be a SPECIFIC product type from the list above, never an ingredient or broad category.
           ✓ "Curl Gel with Coconut Water" → product_type: "Hair Gel"
           ✓ "Shea Butter Body Cream" → product_type: "Body Butter"
           ✓ "Vitamin E Body Lotion" → product_type: "Body Lotion"
           ✓ "Hand Sanitizer Gel" → product_type: "Hand Sanitizer", form: "gel"
           ✓ Foundation powder compact → product_type: "Foundation" or "Face Powder"
           ✓ Multi-purpose spray cleaner → product_type: "Multi-Purpose Cleaner"
           ✗ NEVER return an ingredient (coconut water, shea butter, aloe vera) as product_type
           ✗ NEVER return a broad category like "Makeup", "Skincare", "Hair Care", "Beauty", "Cleaning Products", "Other" — always be specific
        
        2. HAND vs BODY PRODUCTS — pay close attention to whether the label says "hand" or "body":
           ✓ "Hand Lotion" or "Hand Cream" → product_type: "Hand Lotion" (specifically for hands)
           ✓ "Body Lotion" or "Moisturizing Lotion" → product_type: "Body Lotion" (for full body)
           ✓ "Hand Soap" or "Foaming Hand Soap" → product_type: "Hand Soap" (specifically for hands)
           ✓ "Body Wash" or "Shower Gel" → product_type: "Body Wash" (for full body)
           ✓ "Hand & Body Lotion" → product_type: "Hand Lotion" (hand is primary use)
           Rule: If the label says "hand" anywhere, prefer the Hand-specific type. "Body" products are for full-body use. These are DIFFERENT product types and must NOT be confused.
        
        3. OIL PRODUCTS — distinguish between oils that ARE the product vs oils used as ingredients:
           ✓ "Jamaican Black Castor Oil" → product_type: "Castor Oil" (the oil itself IS the product)
           ✓ "Pure Tea Tree Oil" → product_type: "Essential Oil" (a standalone essential oil)
           ✓ "Hair Growth Oil with Castor Oil & Argan" → product_type: "Hair Oil" (a blended hair oil; castor/argan are just ingredients)
           ✓ "Rosemary Mint Scalp Oil" → product_type: "Hair Oil" (a formulated scalp treatment oil)
           ✓ "Argan Oil Face Serum" → product_type: "Face Oil" (argan is an ingredient, the product is a face oil)
           Rule: If the product is JUST a single named oil (castor, tea tree, argan, jojoba, etc.) with no other purpose, use "Castor Oil" or "Essential Oil". If it's a formulated product FOR hair/body/face that happens to contain oils, use "Hair Oil", "Body Oil", or "Face Oil".
        
        4. "form" is how the product is physically dispensed — SEPARATE from product_type.
        
        5. "ingredients" are KEY ingredients listed (like "coconut water", "shea butter", "vitamin E")
        
        6. "confidence" should be 0.0-1.0 based on label clarity and your certainty
        
        7. Extract ALL visible text into "raw_text"
        
        Return ONLY the JSON, no other text.
        """
        
        let payload: [String: Any] = [
            "model": Env.openAIVisionModel,
            "messages": [
                [
                    "role": "system",
                    "content": "You are an expert product label analyzer. You identify product categories accurately from images. You never confuse ingredients or marketing claims with the actual product type."
                ],
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
        case imageTooLarge
        case invalidURL
        case invalidResponse
        case apiError(statusCode: Int)
        case noContentInResponse
        case invalidJSONResponse
        
        var errorDescription: String? {
            switch self {
            case .imageCompressionFailed:
                return "Failed to process image. Please try again."
            case .imageTooLarge:
                return "Image is too large to analyze. Please try a closer photo."
            case .invalidURL:
                return "Unable to connect to analysis service."
            case .invalidResponse:
                return "Received an unexpected response. Please try again."
            case .apiError:
                return "Analysis service is temporarily unavailable. Please try again."
            case .noContentInResponse:
                return "Could not analyze this image. Please try again with a clearer photo."
            case .invalidJSONResponse:
                return "Could not process the analysis result. Please try again."
            }
        }
    }
}
