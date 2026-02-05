# BlackScan - Complete Catalog Analysis & Implementation Plan

**Date**: February 4, 2026  
**Analysis Scope**: 16,707 products from normalized_products.json

---

## 📊 CATALOG STATISTICS

### Overall Numbers
- **Total Products**: 16,707
- **Main Categories**: 11
- **Unique Product Types**: 2,229 (needs normalization)
- **Unique Forms**: 11
- **Unique Subcategory_2**: 1,288
- **Unique Companies**: 293
- **Unique Tags**: 9,136

### Main Category Breakdown
```
Beauty & Personal Care:  3,406 products (20.4%)
Men's Care:              1,792 products (10.7%)
Other:                  10,800 products (64.6%) ⚠️ NEEDS FIXING
Home Care:                 338 products (2.0%)
Baby Care:                 158 products (0.9%)
Gifts/Cards:               99 products (0.6%)
Hair Care:                 45 products (0.3%)
Body Care:                 26 products (0.2%)
Cleaning:                  26 products (0.2%)
Fragrance:                 11 products (0.1%)
Skin Care:                  6 products (0.04%)
```

**⚠️ CRITICAL ISSUE**: 64.6% of products categorized as "Other" - this is a data quality issue, not a scanning issue. Our classifier must work DESPITE this.

---

## 📦 FORM/DISPENSING METHOD ANALYSIS

### Current Forms (11 total)
```
other:  14,391 (86.1%) ⚠️ Too generic
wax:       631 (3.8%)
oil:       509 (3.0%)
cream:     374 (2.2%)
liquid:    247 (1.5%)
gel:       136 (0.8%)
powder:    107 (0.6%)
bar:       103 (0.6%)
spray:      93 (0.6%)
balm:       62 (0.4%)
foam:       54 (0.3%)
```

**Strategy**: "other" is too vague. We'll infer form from:
1. Product type ("Foaming Facial Cleanser" → foam)
2. Product name keywords
3. Tags analysis

---

## 🎯 TOP PRODUCT TYPES

### Most Common (Top 30)
```
Other: 7,108 ⚠️
Dress: 1,080
T-shirt: 513
Handbag: 442
Necklace: 234
Maxi Dress: 226
Lip Gloss: 194
Tote Bag: 178
Bracelet: 161
Hair Oil: 130
Bar Soap: 103
Perfume: 102
Bikini: 91
One-Piece Swimsuit: 89
Scented Candle: 87
Eau de Parfum: 77
Book: 69
Gift Card: 67
Shoulder Bag: 66
Body Butter: 65
Shampoo: 64
Face Serum: 60
Eyeshadow Palette: 57
Body Scrub: 56
Body Oil: 54
Hat: 52
Perfume Oil: 51
Jewelry: 49
Face Mask: 46
Lip Balm: 44
```

### Beauty/Personal Care Specific (31.6% of catalog)
```
Lip Gloss: 194
Bar Soap: 97
Hair Oil: 54
Shampoo: 50
Body Butter: 63
Body Scrub: 54
Body Oil: 50
Face Serum: 48
Perfume: 48
Lip Balm: 40
False Eyelashes: 35
Body Wash: 31
Skincare Set: 30
Hair Care Bundle: 29
Lipstick: 28
Deodorant Stick: 27
Body Lotion: 27
Hair Mask: 26
Leave-In Conditioner: 25
Facial Cleanser: 25
```

---

## 🏢 COMPANY ANALYSIS

### Top Companies in Catalog
```
ANKA Marketplace: 9,032 (54.1%) - Large aggregator
Fenty Beauty: 696
Obioma Fashion: 255
Onyx Skin Care Line: 143
Fenty Skin: 125
DTR 360 BOOKS: 102
Camille Rose Naturals: 87
Pattern Beauty: 69
```

**Insight**: ANKA Marketplace is a major source. Products span all categories.

---

## 🧪 INGREDIENT KEYWORD ANALYSIS

### Common Ingredients Found in Product Names/Tags
```
High Frequency:
- hair (89x), butter (54x), coconut (25x), shea (23x)
- castor (42x), vitamin (17x), aloe vera (12x), tea (28x)

Medium Frequency:
- rose (8x), protein (8x), mint (5x), cocoa (4x)
- collagen (3x), honey (3x), mango (2x)

Present but Rare:
- argan, jojoba, avocado, olive, lavender, rosemary
- hyaluronic, charcoal, clay, biotin
```

**Strategy**: These are DESCRIPTORS, not product types. Must filter out during classification.

Example:
- ❌ "Coconut" ≠ Product Type
- ✅ "Shampoo" = Product Type
- ✅ "Coconut Oil Shampoo" → Type: Shampoo, Ingredient: Coconut

---

## 🚨 CRITICAL CHALLENGES IDENTIFIED

### 1. **Inconsistent Product Type Naming**
Same product, different names:
- "Leave-In Conditioner" vs "Leave-in Conditioner" (capitalization)
- "Hair Conditioner" vs "Conditioner" vs "Leave-In Conditioner"
- "T-shirt" vs "T-Shirt" (513 vs 26 products)
- "Facial Cleanser" vs "Face Cleanser" vs "Face Wash"

**Solution**: Master taxonomy with canonical names + variations

### 2. **Misclassified Main Categories**
Found in "Beauty & Personal Care":
- Bikini: 76
- Dresses: 69
- Tote Bags: 54
- Handbags: 43

**Solution**: Rely on product_type, not main_category

### 3. **7,108 Products Labeled "Other"**
42.5% have no specific type classification.

**Solution**: Our classifier must work with OCR text, not rely on existing categories

### 4. **86% Products Have "other" as Form**
Form field is mostly empty/generic.

**Solution**: Infer form from product type and name

---

## 🎯 6-TIER CUMULATIVE CONFIDENCE SCORING SYSTEM

### Scoring Weights
```swift
Tier 1: Product Type Recognition       40% weight
Tier 2: Form/Dispensing Method         25% weight
Tier 3: Brand Category Association     15% weight
Tier 4: Ingredient Clarity             10% weight
Tier 5: Size/Quantity Compatibility     5% weight
Tier 6: Visual Recognition (Phase 2)    5% weight
```

### How It Works

**Example Scan**: "CeraVe Foaming Facial Cleanser For Normal to Oily Skin 12 oz"

#### Step 1: Extract Classification Data
```
Product Type: "Facial Cleanser" (confidence: 0.95)
Form: "foam" (confidence: 0.90)
Brand: "CeraVe" → Category: "Skincare/Face Care"
Ingredients: None misleading (clarity: 1.0)
Size: "12 oz" → Range: 8-16 oz
```

#### Step 2: Search Broadly
```swift
query = "facial cleanser face wash foaming"
filter = main_category IN ["Beauty & Personal Care", "Skin Care"]
results = 100+ products
```

#### Step 3: Score Each Product
```swift
Product A: "African Black Soap Foaming Facial Cleanser"
- Product Type: "Facial Cleanser" → 40/40 ✅
- Form: "foam" → 25/25 ✅
- Category: "Face Care" → 15/15 ✅
- Ingredient Clarity: Clear → 10/10 ✅
- Size: 8 oz → 5/5 ✅
TOTAL: 95/100 = 95% confidence

Product B: "Shea Butter Face Wash"
- Product Type: "Face Wash" → 35/40 (synonym)
- Form: "liquid" → 15/25 (compatible but not exact)
- Category: "Face Care" → 15/15 ✅
- Ingredient: "Shea Butter" → 7/10 (slight confusion)
- Size: 12 oz → 5/5 ✅
TOTAL: 77/100 = 77% confidence

Product C: "Hair Conditioner"
- Product Type: Wrong → 5/40 ❌
- Form: "liquid" → 10/25
- Category: "Hair Care" → 0/15 ❌
- Ingredient: Clear → 10/10
- Size: 16 oz → 3/5
TOTAL: 28/100 = 28% confidence (filtered out)
```

#### Step 4: Return Top 20
Sort by confidence, show top 20 with explanations.

---

## 🛠️ IMPLEMENTATION PLAN

### Phase 1: Foundation (Days 1-3)

#### Task 1: Build Master Product Taxonomy
**Input**: 2,229 unique product types  
**Output**: Normalized taxonomy with canonical names

```swift
// Example structure
let taxonomy = ProductTaxonomy(
    canonicalName: "Leave-In Conditioner",
    variations: ["Leave-in Conditioner", "leave in conditioner", "Leave In"],
    synonyms: ["Leave-In Treatment", "Daily Leave-In"],
    category: "Hair Care",
    subcategory: "Conditioners",
    typicalForms: ["liquid", "cream", "spray"]
)
```

**Deliverable**: `ProductTaxonomy.swift` with ~500 normalized types

#### Task 2: Standardize Form/Dispensing Methods
**Input**: 11 current forms  
**Output**: Enhanced form taxonomy with inference rules

```swift
let formTaxonomy = FormTaxonomy(
    canonical: [
        "liquid", "cream", "oil", "gel", "foam", "spray", "powder",
        "bar", "stick", "balm", "wax", "aerosol", "roll-on", "pump"
    ],
    inferenceRules: [
        "foaming" → "foam",
        "pump bottle" → "pump",
        "roll-on" → "roll-on",
        "stick" → "stick",
        "bar" → "bar"
    ]
)
```

**Deliverable**: `FormTaxonomy.swift`

#### Task 3: Non-Black Brand Intelligence Database
**Goal**: Recognize brands users will scan

```swift
let brandDatabase = [
    Brand(
        name: "CeraVe",
        variations: ["cerave", "cera ve"],
        categories: ["Skincare", "Face Care", "Body Care"],
        commonProducts: ["Facial Cleanser", "Moisturizer", "Body Wash"],
        confidence: 0.95
    ),
    Brand(
        name: "Dove",
        variations: ["dove"],
        categories: ["Body Care", "Hair Care"],
        commonProducts: ["Bar Soap", "Body Wash", "Shampoo", "Conditioner"],
        confidence: 0.95
    ),
    Brand(
        name: "Neutrogena",
        variations: ["neutrogena"],
        categories: ["Skincare", "Face Care"],
        commonProducts: ["Facial Cleanser", "Sunscreen", "Moisturizer"],
        confidence: 0.95
    ),
    // ... 50+ major brands
]
```

**Deliverable**: `BrandDatabase.swift` with 50+ brands

#### Task 4: Ingredient Recognition System
**Goal**: Identify & filter ingredient keywords

```swift
let ingredientKeywords = IngredientDatabase(
    commonIngredients: [
        "shea", "butter", "coconut", "argan", "jojoba", "castor",
        "tea tree", "aloe vera", "cocoa", "mango", "avocado",
        "vitamin", "hyaluronic", "collagen", "keratin", "biotin"
    ],
    compoundIngredients: [
        "shea butter", "cocoa butter", "tea tree oil",
        "aloe vera", "coconut oil", "castor oil"
    ]
)
```

**Deliverable**: `IngredientDatabase.swift`

#### Task 5: Size/Quantity Extraction
**Goal**: Recognize and extract size patterns

```swift
// Regex patterns for size extraction
let sizePatterns = [
    #"(\d+(?:\.\d+)?)\s*(?:fl\s*)?oz"#,  // 12 oz, 8 fl oz
    #"(\d+(?:\.\d+)?)\s*ml"#,             // 350ml
    #"(\d+(?:\.\d+)?)\s*g"#,              // 100g
    #"(\d+(?:\.\d+)?)\s*lbs?"#,           // 2 lb
    #"(\d+(?:\.\d+)?)\s*l(?:iter)?"#      // 1 liter
]
```

**Deliverable**: `SizeExtractor.swift`

---

### Phase 2: Core Classifier (Days 4-6)

#### Task 6: Rewrite Classifier.swift
**New structure**:

```swift
struct ScanClassification {
    let productType: ClassificationResult
    let form: FormResult?
    let brandAssociation: BrandResult?
    let ingredients: [DetectedIngredient]
    let size: SizeResult?
    let rawText: String
    
    struct ClassificationResult {
        let type: String
        let confidence: Double
        let matchedKeywords: [String]
        let reasoning: String
    }
}

class AdvancedClassifier {
    // Tier 1: Product Type
    func classifyProductType(_ text: String) -> ClassificationResult
    
    // Tier 2: Form/Dispensing
    func classifyForm(_ text: String, productType: String?) -> FormResult?
    
    // Tier 3: Brand Association
    func detectBrand(_ text: String) -> BrandResult?
    
    // Tier 4: Ingredient Detection
    func detectIngredients(_ text: String) -> [DetectedIngredient]
    
    // Tier 5: Size Extraction
    func extractSize(_ text: String) -> SizeResult?
    
    // Master classification
    func classify(_ ocrText: String) -> ScanClassification
}
```

**Deliverable**: New `AdvancedClassifier.swift`

#### Task 7: Confidence Scoring Engine
**New structure**:

```swift
struct ScoredProduct {
    let product: Product
    let confidenceScore: Double  // 0.0-1.0
    let breakdown: ScoreBreakdown
    let explanation: String
}

struct ScoreBreakdown {
    let productTypeScore: Double  // 0.0-1.0
    let formScore: Double
    let brandScore: Double
    let ingredientScore: Double
    let sizeScore: Double
    let visualScore: Double?
    
    var details: [String: Double] {
        [
            "Product Type": productTypeScore,
            "Form": formScore,
            "Brand Category": brandScore,
            "Ingredient Clarity": ingredientScore,
            "Size": sizeScore
        ]
    }
}

class ConfidenceScorer {
    func score(
        product: Product,
        against classification: ScanClassification
    ) -> ScoredProduct
}
```

**Deliverable**: `ConfidenceScorer.swift`

---

### Phase 3: Search Integration (Days 7-8)

#### Task 8: Update TypesenseClient
**Add weighted multi-pass search**:

```swift
extension TypesenseClient {
    /// Cumulative confidence-based search
    func searchWithConfidenceRanking(
        classification: ScanClassification,
        maxResults: Int = 20
    ) async throws -> [ScoredProduct] {
        
        // Step 1: Broad search (100+ candidates)
        let query = buildOptimizedQuery(classification)
        let candidates = try await search(
            query: query,
            perPage: 100,
            queryBy: "product_type^3,form^2,name^1,tags^1"
        )
        
        // Step 2: Score each candidate
        let scorer = ConfidenceScorer()
        let scoredProducts = candidates.products.map { product in
            scorer.score(product: product, against: classification)
        }
        
        // Step 3: Filter low confidence (< 30%)
        let filtered = scoredProducts.filter { $0.confidenceScore >= 0.3 }
        
        // Step 4: Sort by confidence
        let sorted = filtered.sorted { $0.confidenceScore > $1.confidenceScore }
        
        // Step 5: Return top N
        return Array(sorted.prefix(maxResults))
    }
}
```

**Deliverable**: Updated `TypesenseClient.swift`

---

### Phase 4: UI & Logging (Days 9-10)

#### Task 9: Update ScanView UI
**Add confidence display**:

```swift
// Results card header
VStack(alignment: .leading, spacing: 4) {
    Text("Found: \(classification.productType.type)")
        .font(.system(size: 24, weight: .bold))
    
    HStack {
        Text("Confidence:")
            .font(.system(size: 18, weight: .medium))
        Text("\(Int(topProduct.confidenceScore * 100))%")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(confidenceColor)
    }
    
    Text("Black-owned alternatives to \(scannedBrand ?? "this product")")
        .font(.system(size: 15))
        .foregroundColor(.secondary)
}

// Optional: Show why it matched
if showDebug {
    VStack(alignment: .leading, spacing: 4) {
        Text("Match Breakdown:")
            .font(.caption)
            .foregroundColor(.secondary)
        
        ForEach(topProduct.breakdown.details.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
            HStack {
                Image(systemName: value > 0.7 ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundColor(value > 0.7 ? .green : .orange)
                Text("\(key): \(Int(value * 100))%")
                    .font(.caption2)
            }
        }
    }
}
```

**Deliverable**: Updated `ScanView.swift` and `CameraScanView.swift`

#### Task 10: Implement Local Logging
**CoreData model**:

```swift
@objc(ScanLog)
class ScanLog: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var timestamp: Date
    @NSManaged var ocrText: String
    @NSManaged var detectedProductType: String?
    @NSManaged var detectedBrand: String?
    @NSManaged var topResultConfidence: Double
    @NSManaged var resultsReturned: Int
    @NSManaged var userSelectedProduct: Bool
    @NSManaged var selectedProductId: String?
}

class ScanLogger {
    func logScan(
        ocrText: String,
        classification: ScanClassification,
        results: [ScoredProduct],
        userAction: ScanUserAction
    )
    
    func getFailedScans() -> [ScanLog]  // confidence < 50%
    func getSuccessRate() -> Double
}
```

**Deliverable**: `ScanLogger.swift` + CoreData model

---

### Phase 5: Testing & Validation (Days 11-14)

#### Task 11: Create Test Suite
**Test with real-world examples**:

```swift
let testCases = [
    // Beauty products
    ("CeraVe Foaming Facial Cleanser 12 oz", "Facial Cleanser"),
    ("Dove Bar Soap Sensitive Skin", "Bar Soap"),
    ("Neutrogena Hydro Boost Water Gel", "Face Moisturizer"),
    ("Pantene Pro-V Shampoo", "Shampoo"),
    
    // Complex cases
    ("Shea Moisture Coconut & Hibiscus Curl Cream", "Hair Cream"),
    ("Fenty Beauty Pro Filt'r Foundation", "Foundation"),
    
    // Edge cases
    ("Lip Balm SPF 30", "Lip Balm"),
    ("2-in-1 Shampoo and Conditioner", "Shampoo"),
]

func testClassificationAccuracy() {
    var correct = 0
    for (input, expected) in testCases {
        let result = classifier.classify(input)
        if result.productType.type == expected {
            correct += 1
        }
    }
    let accuracy = Double(correct) / Double(testCases.count)
    print("Accuracy: \(accuracy * 100)%")
}
```

#### Task 12: Iterate Until 95%+
- Test with 100+ real product scans
- Identify failure patterns
- Update taxonomy/rules
- Repeat until accuracy ≥ 95%

---

## 📁 FILE STRUCTURE

```
BlackScan/
├── BlackScan/
│   ├── Scanning/
│   │   ├── AdvancedClassifier.swift        [NEW]
│   │   ├── ProductTaxonomy.swift           [NEW]
│   │   ├── FormTaxonomy.swift              [NEW]
│   │   ├── BrandDatabase.swift             [NEW]
│   │   ├── IngredientDatabase.swift        [NEW]
│   │   ├── SizeExtractor.swift             [NEW]
│   │   ├── ConfidenceScorer.swift          [NEW]
│   │   ├── ScanLogger.swift                [NEW]
│   │   ├── ScanView.swift                  [UPDATED]
│   │   ├── CameraScanView.swift            [UPDATED]
│   │   └── LiveScannerView.swift           [EXISTING]
│   ├── Search/
│   │   ├── TypesenseClient.swift           [UPDATED]
│   │   └── Models.swift                    [UPDATED]
│   └── Data/
│       └── BlackScan.xcdatamodeld          [NEW - CoreData]
└── SCAN_SYSTEM_ANALYSIS.md                 [THIS FILE]
```

---

## 🎯 SUCCESS CRITERIA

### Phase 1 Complete When:
✅ All 5 foundational files created  
✅ Master taxonomy covers all 2,229+ product types  
✅ 50+ brands in database  
✅ 30+ ingredient keywords identified  

### Phase 2 Complete When:
✅ AdvancedClassifier returns full 6-tier classification  
✅ ConfidenceScorer produces weighted scores  
✅ Unit tests pass for common cases  

### Phase 3 Complete When:
✅ TypesenseClient integrates confidence ranking  
✅ Search returns top 20 by cumulative score  
✅ Performance: < 1 second for classification + search  

### Phase 4 Complete When:
✅ UI displays confidence percentage  
✅ Logging system captures all scans  
✅ Can retrieve failed scans for analysis  

### Phase 5 Complete When:
✅ **95%+ accuracy on test set of 100+ real scans**  
✅ Common products (soap, shampoo, cleanser) at 98%+  
✅ Complex products (multi-word, ingredients) at 90%+  

---

## 🚀 NEXT STEPS

1. **User confirms approach** ✅
2. **Start Phase 1, Task 1**: Build master product taxonomy
3. Progress through tasks sequentially
4. Update TODO list as tasks complete
5. Test continuously
6. Iterate until 95%+ accuracy achieved

---

**END OF ANALYSIS**
