import Foundation

/// Quick test to verify environment variables are loaded
/// This will crash if variables are not set, showing exactly which one is missing
struct TestEnv {
    static func validateOnStartup() {
        #if DEBUG
        Log.debug("========================================", category: .general)
        Log.debug("ENVIRONMENT VARIABLE CHECK", category: .general)
        Log.debug("========================================", category: .general)
        
        // Test Typesense Host
        do {
            let host = Env.typesenseHost
            Log.debug("TYPESENSE_HOST: [SET]", category: .general)
        } catch {
            Log.error("TYPESENSE_HOST: NOT SET", category: .general)
        }
        
        // Test Typesense API Key (NEVER log the actual key)
        do {
            let key = Env.typesenseApiKey
            Log.debug("TYPESENSE_API_KEY: [SET] (\(key.count) chars)", category: .general)
        } catch {
            Log.error("TYPESENSE_API_KEY: NOT SET", category: .general)
        }
        
        // Test Backend URL
        do {
            let url = Env.backendURL
            Log.debug("BACKEND_URL: [SET]", category: .general)
        } catch {
            Log.error("BACKEND_URL: NOT SET", category: .general)
        }
        
        // Test OpenAI API Key (NEVER log the actual key)
        do {
            let key = Env.openAIAPIKey
            Log.debug("OPENAI_API_KEY: [SET] (\(key.count) chars)", category: .general)
        } catch {
            Log.error("OPENAI_API_KEY: NOT SET", category: .general)
        }
        
        Log.debug("Collection: \(Env.typesenseCollection)", category: .general)
        Log.debug("Debug Mode: \(Env.isDebugMode)", category: .general)
        Log.debug("========================================", category: .general)
        #endif
    }
}
