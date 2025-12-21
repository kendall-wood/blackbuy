import Foundation

print("🧪 Testing BlackScan Classifier")

// Test the classifier with various inputs
let testCases = [
    "SheaMoisture Coconut & Hibiscus Curl & Shine Shampoo",
    "Cantu Natural Hair Leave-In Conditioning Repair Cream", 
    "Pattern Curl Gel Strong Hold",
    "Edge Control for Natural Hair",
    "Deep Conditioning Hair Mask",
    "Gift Card $50",
    "Co-wash Cleansing Conditioner",
    "Heat Protection Spray",
    "Mielle Organics Hair Oil",
    "Mousse for Curly Hair"
]

print("Testing classifier rules:")
for testCase in testCases {
    let result = Classifier.classify(testCase)
    print("Input: '\(testCase)'")
    print("→ Product Type: \(result.productType)")
    print("→ Query String: \(result.queryString)")
    print("→ Confidence: \(String(format: "%.2f", result.confidence))")
    print("→ Matched Keywords: \(result.matchedKeywords)")
    print("")
}

print("✅ Classifier compilation and testing complete!")
print("Supported product types: \(Classifier.supportedProductTypes.count)")