import SwiftUI

@main
struct BlackScanApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var typesenseClient = TypesenseClient()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("BlackScan MVP")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Discover Black-owned products")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if Env.validateEnvironment() {
                    Text("✅ Environment configured")
                        .foregroundColor(.green)
                } else {
                    Text("❌ Environment not configured")
                        .foregroundColor(.red)
                }
                
                if typesenseClient.isLoading {
                    ProgressView("Loading...")
                }
                
                Button("Test Search") {
                    Task {
                        do {
                            let products = try await typesenseClient.searchProducts(query: "shampoo")
                            print("Found \(products.count) products")
                        } catch {
                            print("Search error: \(error)")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Test Classifier") {
                    // Test classification with sample OCR text
                    let sampleTexts = [
                        "SheaMoisture Coconut Curl Shampoo",
                        "Leave-in Conditioner for Natural Hair",
                        "Edge Control Gel",
                        "$25 Gift Card"
                    ]
                    
                    print("🧪 Testing Classifier:")
                    for text in sampleTexts {
                        let result = Classifier.classify(text)
                        print("'\(text)' → \(result.productType) (confidence: \(result.confidence))")
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding()
            .navigationTitle("BlackScan")
        }
    }
}
