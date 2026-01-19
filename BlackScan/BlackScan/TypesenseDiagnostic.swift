import SwiftUI

/// Diagnostic view to test Typesense connection
/// Use this to verify your environment variables and API connectivity
struct TypesenseDiagnosticView: View {
    @StateObject private var client = TypesenseClient()
    @State private var status: ConnectionStatus = .notTested
    @State private var errorMessage: String = ""
    @State private var productCount: Int = 0
    @State private var responseTime: Int = 0
    
    enum ConnectionStatus {
        case notTested
        case testing
        case success
        case failed
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 60))
                            .foregroundColor(statusColor)
                        
                        Text(statusText)
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Configuration Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Configuration")
                            .font(.system(size: 20, weight: .semibold))
                        
                        ConfigRow(label: "Host", value: Env.typesenseHost)
                        ConfigRow(label: "Collection", value: Env.typesenseCollection)
                        ConfigRow(label: "API Key Length", value: "\(Env.typesenseApiKey.count) characters")
                        ConfigRow(label: "API Key Prefix", value: String(Env.typesenseApiKey.prefix(10)) + "...")
                        ConfigRow(label: "Backend URL", value: Env.backendURL)
                        ConfigRow(label: "Search URL", value: Env.typesenseSearchURL())
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Results
                    if status == .success {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Test Results")
                                .font(.system(size: 20, weight: .semibold))
                            
                            ConfigRow(label: "Products Found", value: "\(productCount)")
                            ConfigRow(label: "Response Time", value: "\(responseTime)ms")
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                    
                    // Error Message
                    if status == .failed && !errorMessage.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error Details")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.red)
                            
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                    
                    // Test Button
                    Button(action: testConnection) {
                        HStack {
                            if status == .testing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            
                            Text(status == .testing ? "Testing..." : "Test Connection")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.26, green: 0.63, blue: 0.95))
                        )
                    }
                    .disabled(status == .testing)
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Instructions")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("1. Verify that your TYPESENSE_HOST is correct")
                        Text("2. Ensure your TYPESENSE_API_KEY is valid")
                        Text("3. Check that products are uploaded to Typesense")
                        Text("4. Make sure you have network connectivity")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                .padding(20)
            }
            .navigationTitle("Typesense Diagnostic")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .notTested:
            return "questionmark.circle"
        case .testing:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .notTested:
            return .gray
        case .testing:
            return .blue
        case .success:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .notTested:
            return "Ready to Test"
        case .testing:
            return "Testing Connection..."
        case .success:
            return "Connection Successful!"
        case .failed:
            return "Connection Failed"
        }
    }
    
    private func testConnection() {
        status = .testing
        errorMessage = ""
        productCount = 0
        responseTime = 0
        
        print("\n🧪 === TYPESENSE DIAGNOSTIC TEST ===")
        print("📡 Host: \(Env.typesenseHost)")
        print("🔑 API Key: \(Env.typesenseApiKey.prefix(10))...")
        print("🔗 Search URL: \(Env.typesenseSearchURL())")
        
        Task {
            do {
                let startTime = Date()
                let response = try await client.search(parameters: SearchParameters(
                    query: "*",
                    page: 1,
                    perPage: 1
                ))
                let endTime = Date()
                let elapsed = Int((endTime.timeIntervalSince(startTime)) * 1000)
                
                await MainActor.run {
                    status = .success
                    productCount = response.found
                    responseTime = response.searchTimeMs
                    
                    print("✅ Test PASSED")
                    print("📊 Products found: \(productCount)")
                    print("⏱️ Response time: \(responseTime)ms")
                    print("🌐 Network time: \(elapsed)ms")
                }
            } catch {
                await MainActor.run {
                    status = .failed
                    errorMessage = error.localizedDescription
                    
                    print("❌ Test FAILED")
                    print("❌ Error: \(error)")
                    print("❌ Error type: \(type(of: error))")
                    
                    if let localizedError = error as? LocalizedError {
                        print("❌ Description: \(localizedError.errorDescription ?? "N/A")")
                        print("❌ Reason: \(localizedError.failureReason ?? "N/A")")
                        print("❌ Suggestion: \(localizedError.recoverySuggestion ?? "N/A")")
                    }
                }
            }
            
            print("=================================\n")
        }
    }
}

struct ConfigRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    TypesenseDiagnosticView()
}
