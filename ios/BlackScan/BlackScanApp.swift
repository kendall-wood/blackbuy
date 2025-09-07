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
                
                Spacer()
            }
            .padding()
            .navigationTitle("BlackScan")
        }
    }
}
