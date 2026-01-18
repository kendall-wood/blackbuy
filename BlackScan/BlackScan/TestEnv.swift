import Foundation

/// Quick test to verify environment variables are loaded
/// This will crash if variables are not set, showing exactly which one is missing
struct TestEnv {
    static func validateOnStartup() {
        print("\n========================================")
        print("🔍 ENVIRONMENT VARIABLE CHECK")
        print("========================================\n")
        
        // Test Typesense Host
        do {
            let host = Env.typesenseHost
            print("✅ TYPESENSE_HOST: \(host)")
        } catch {
            print("❌ TYPESENSE_HOST: NOT SET OR ERROR")
            print("   Error: \(error)")
        }
        
        // Test Typesense API Key
        do {
            let key = Env.typesenseApiKey
            print("✅ TYPESENSE_API_KEY: \(key.prefix(15))... (\(key.count) chars)")
        } catch {
            print("❌ TYPESENSE_API_KEY: NOT SET OR ERROR")
            print("   Error: \(error)")
        }
        
        // Test Backend URL
        do {
            let url = Env.backendURL
            print("✅ BACKEND_URL: \(url)")
        } catch {
            print("❌ BACKEND_URL: NOT SET OR ERROR")
            print("   Error: \(error)")
        }
        
        print("\n========================================")
        print("Collection: \(Env.typesenseCollection)")
        print("Debug Mode: \(Env.isDebugMode)")
        print("========================================\n")
    }
}
