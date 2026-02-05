# BlackScan - Complete Scanning System Reference

**Master Technical Documentation**  
**Version**: 2.2 (Enhanced Filtering & Specificity)  
**Date**: February 5, 2026  
**Last Updated**: February 5, 2026 - Added accessory filtering, use-case validation, and form mismatch detection  
**Purpose**: Complete reference for AI-powered product scanning with OpenAI GPT-4 Vision + Hybrid OCR

---

## 📚 TABLE OF CONTENTS

1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [The 6-Tier Scoring System](#the-6-tier-scoring-system)
4. [Implementation Components](#implementation-components)
5. [Complete Logic Flow](#complete-logic-flow)
6. [Algorithms & Scoring Functions](#algorithms--scoring-functions)
7. [Data Structures](#data-structures)
8. [Search Strategy](#search-strategy)
9. [UI/UX Design](#uiux-design)
10. [Testing & Validation](#testing--validation)
11. [Future Enhancements](#future-enhancements)
12. [Technical Decisions Log](#technical-decisions-log)

---

## 1. SYSTEM OVERVIEW

### Purpose
BlackScan's scanning system allows users to scan **any product from non-Black-owned brands** and receive **highly accurate Black-owned alternatives** from our 16,707+ product catalog.

### Core Challenge
Product labels contain complex, multi-layered information:
- Product type ("Facial Cleanser")
- Dispensing method ("Foaming")
- Brand name ("CeraVe")
- Ingredients ("with Hyaluronic Acid")
- Size/quantity ("12 fl oz")
- Marketing text ("For Normal to Oily Skin")

**Our system must**:
- Extract meaningful classification data from OCR text
- Score products cumulatively across 6 criteria
- Return top 20 matches sorted by confidence
- Achieve **95%+ accuracy**

### Design Philosophy
- **AI-Powered**: OpenAI GPT-4 Vision for 95%+ accuracy
- **Cumulative scoring**: All criteria contribute to confidence, not pass/fail
- **Transparent**: Users see why products matched
- **Fast**: ~2-3 seconds from scan to results
- **Cost-effective**: ~$0.01 per scan

---

## 2. ARCHITECTURE

### High-Level Flow (OpenAI Vision)

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER SCANS PRODUCT                      │
│                   (Garnier Fructis Curl Gel)                    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CAMERA PREVIEW VIEW                          │
│                 (CameraPreviewView.swift)                       │
│  - AVCaptureSession                                             │
│  - Single photo capture on button tap                           │
│  - Flashlight control                                           │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                  OPENAI GPT-4 VISION API                        │
│              (OpenAIVisionService.swift)                        │
│                                                                 │
│  AI extracts structured data:                                   │
│  ├─ Brand: "Garnier Fructis"                                   │
│  ├─ Product Type: "Curl Defining Gel"                          │
│  ├─ Form: "spray gel"                                          │
│  ├─ Size: "8.5 fl oz"                                          │
│  ├─ Ingredients: ["coconut water"]                             │
│  ├─ Confidence: 0.95                                           │
│  └─ Raw Text: "GARNIER FRUCTIS CURL SHAPE..."                  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   TYPESENSE SEARCH                              │
│              (TypesenseClient.swift)                            │
│  - Search by product type                                       │
│  - Retrieve 20 candidate products                               │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   CONFIDENCE SCORER                             │
│              (ConfidenceScorer.swift)                           │
│  - Score each product against classification                    │
│  - Cumulative weighted scoring:                                 │
│    • Product Type:    40%                                       │
│    • Form:            25%                                       │
│    • Brand Category:  15%                                       │
│    • Ingredients:     10%                                       │
│    • Size:             5%                                       │
│    • Visual:           5% (Phase 2)                             │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    RANKING & FILTERING                          │
│  - Filter products below 30% confidence                         │
│  - Sort by cumulative confidence score                          │
│  - Select top 20 products                                       │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    RESULTS DISPLAY                              │
│              (ScanView.swift / CameraScanView.swift)            │
│  - Show product type found                                      │
│  - Display confidence percentage                                │
│  - Grid of top 20 products                                      │
│  - "Suggested" sort (by confidence)                             │
│  - Tap for product details                                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SCAN LOGGING                                 │
│              (ScanLogger.swift + CoreData)                      │
│  - Log scan text, classification, results                       │
│  - Track user selections                                        │
│  - Identify low-confidence scans for improvement                │
└─────────────────────────────────────────────────────────────────┘
```

### Component Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    DATA LAYER                                │
├──────────────────────────────────────────────────────────────┤
│  ProductTaxonomy.swift      │ Master product type mappings   │
│  FormTaxonomy.swift         │ Dispensing method rules        │
│  BrandDatabase.swift        │ Non-Black brand intelligence   │
│  IngredientDatabase.swift   │ Ingredient keyword library     │
│  SizeExtractor.swift        │ Size pattern recognition       │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                  CLASSIFICATION LAYER                        │
├──────────────────────────────────────────────────────────────┤
│  AdvancedClassifier.swift   │ 6-tier extraction engine       │
│  ConfidenceScorer.swift     │ Cumulative scoring system      │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                    SEARCH LAYER                              │
├──────────────────────────────────────────────────────────────┤
│  TypesenseClient.swift      │ Weighted search + ranking      │
│  Models.swift               │ Product, ScoredProduct models  │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                  PRESENTATION LAYER                          │
├──────────────────────────────────────────────────────────────┤
│  ScanView.swift             │ Main scan interface            │
│  CameraScanView.swift       │ Camera + results UI            │
│  LiveScannerView.swift      │ VisionKit camera scanner       │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                   PERSISTENCE LAYER                          │
├──────────────────────────────────────────────────────────────┤
│  ScanLogger.swift           │ Scan logging + analytics       │
│  CoreData Model             │ Local database                 │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. THE 6-TIER SCORING SYSTEM

### Overview
Unlike traditional classification (which is binary: match or no match), our system uses **cumulative weighted scoring** where every criterion contributes to the final confidence score.

### The 6 Tiers

#### **Tier 1: Product Type Recognition (40% weight)**
**Purpose**: Identify what the product IS  
**Examples**: Shampoo, Facial Cleanser, Body Butter, Lip Gloss

**Why 40%**: This is the most critical factor. A shampoo alternative must be a shampoo.

**Scoring Logic**:
```
Exact match:           1.0  (100%)  "Facial Cleanser" = "Facial Cleanser"
Synonym match:         0.9  (90%)   "Face Wash" ≈ "Facial Cleanser"
Same category:         0.6  (60%)   "Face Cleanser" and "Face Scrub" (both face care)
Partial keyword:       0.4  (40%)   "Cleanser" in both
No match:              0.0  (0%)    "Shampoo" vs "Lipstick"
```

#### **Tier 2: Form/Dispensing Method (25% weight)**
**Purpose**: Match how the product is dispensed  
**Examples**: foam, liquid, cream, gel, spray, bar, stick, oil, powder

**Why 25%**: Users expect similar application method. Foaming cleanser users want foam, not gel.

**Scoring Logic**:
```
Exact match:           1.0  (100%)  "foam" = "foam"
Compatible forms:      0.7  (70%)   "liquid" ≈ "cream", "gel" ≈ "gelly"
Generic match:         0.5  (50%)   "other" or missing
Incompatible:          0.3  (30%)   "foam" vs "bar"
```

#### **Tier 3: Brand Category Association (15% weight)**
**Purpose**: Match products from similar brand categories  
**Examples**: If scanning CeraVe (dermatologist brand), prioritize clinical skincare

**Why 15%**: Helps maintain user expectations about product positioning/quality.

**Scoring Logic**:
```
Same brand category:   1.0  (100%)  CeraVe (clinical) → other clinical brands
Similar category:      0.7  (70%)   Clinical → Natural/organic
General category:      0.5  (50%)   Any skincare brand
Unknown brand:         0.5  (50%)   No brand detected
```

#### **Tier 4: Ingredient Clarity (10% weight)**
**Purpose**: Ensure we're not confused by ingredient names  
**Examples**: "Coconut Oil Shampoo" - coconut is ingredient, shampoo is type

**Why 10%**: Prevents misclassification but shouldn't override other factors.

**Scoring Logic**:
```
No ingredient confusion:     1.0  (100%)  Clean product type
Minor ingredient mention:    0.7  (70%)   "Shea Butter Face Cream" (clear it's a cream)
Heavy ingredient focus:      0.5  (50%)   "Pure Coconut Oil" (ambiguous)
Ingredient as type:          0.3  (30%)   "Shea Butter" (is it butter or just has shea?)
```

#### **Tier 5: Size/Quantity Compatibility (5% weight)**
**Purpose**: Match similar product sizes  
**Examples**: If scanning 12 oz bottle, prefer 8-16 oz alternatives

**Why 5%**: Nice-to-have but not critical. Users adapt to different sizes.

**Scoring Logic**:
```
Exact size match:      1.0  (100%)  12 oz → 12 oz
Size within 25%:       0.9  (90%)   12 oz → 10-14 oz
Size within 50%:       0.7  (70%)   12 oz → 8-16 oz
Size within 2x:        0.5  (50%)   12 oz → 6-24 oz
Size unknown:          0.5  (50%)   No size detected
Very different:        0.3  (30%)   12 oz → 64 oz (bulk)
```

#### **Tier 6: Visual Recognition (5% weight) - Phase 2**
**Purpose**: Match product shape/packaging visually  
**Examples**: Pump bottle, tube, jar, stick, aerosol can

**Why 5%**: Added later with CoreML. Helpful but not essential.

**Scoring Logic** (Future):
```
Exact packaging match: 1.0  (100%)  Pump bottle → Pump bottle
Similar packaging:     0.7  (70%)   Pump → Squeeze bottle
Generic packaging:     0.5  (50%)   Standard bottle
Unknown:               0.5  (50%)   No visual data
```

---

## 4. IMPLEMENTATION COMPONENTS

### Component 1: ProductTaxonomy.swift

**Purpose**: Master database of all product types with normalization

**Structure**:
```swift
struct ProductType {
    let canonical: String           // "Leave-In Conditioner"
    let variations: [String]        // ["Leave-in Conditioner", "Leave In", "leave-in"]
    let synonyms: [String]          // ["Leave-In Treatment", "Daily Leave-In"]
    let category: String            // "Hair Care"
    let subcategory: String?        // "Conditioners"
    let typicalForms: [String]      // ["liquid", "cream", "spray"]
    let keywords: [String]          // ["leave", "conditioner", "leave-in"]
}

class ProductTaxonomy {
    private let types: [ProductType]
    
    // Find canonical type from any variation
    func normalize(_ input: String) -> String?
    
    // Check if two types are synonyms
    func areSynonyms(_ type1: String, _ type2: String) -> Bool
    
    // Get all types in a category
    func getTypesInCategory(_ category: String) -> [ProductType]
    
    // Find best match from OCR text
    func findBestMatch(_ text: String) -> (type: ProductType, confidence: Double)?
}
```

**Implementation Approach**:
1. Extract all 2,229 unique product types from JSON
2. Group by similarity (using string distance + manual review)
3. Create ~500 canonical types
4. Map all variations to canonical names
5. Add synonyms (Face Wash = Facial Cleanser)
6. Add typical forms for each type

**Example Entries**:
```swift
ProductType(
    canonical: "Facial Cleanser",
    variations: ["Face Cleanser", "facial cleanser", "Facial Wash", "Face Wash"],
    synonyms: ["Face Wash", "Cleansing Gel", "Face Soap"],
    category: "Skincare",
    subcategory: "Face Care",
    typicalForms: ["foam", "gel", "liquid", "cream"],
    keywords: ["facial", "face", "cleanser", "wash", "cleansing"]
)

ProductType(
    canonical: "Leave-In Conditioner",
    variations: ["Leave-in Conditioner", "Leave In Conditioner", "leave-in"],
    synonyms: ["Leave-In Treatment", "Daily Leave-In"],
    category: "Hair Care",
    subcategory: "Conditioners",
    typicalForms: ["liquid", "cream", "spray"],
    keywords: ["leave", "in", "conditioner", "leave-in"]
)

ProductType(
    canonical: "Body Butter",
    variations: ["body butter", "Body Cream"],
    synonyms: ["Body Moisturizer", "Moisturizing Cream"],
    category: "Body Care",
    subcategory: "Moisturizers",
    typicalForms: ["cream", "butter"],
    keywords: ["body", "butter", "cream", "moisturizer"]
)
```

---

### Component 2: FormTaxonomy.swift

**Purpose**: Standardize and infer product dispensing methods

**Structure**:
```swift
struct FormType {
    let canonical: String           // "foam"
    let variations: [String]        // ["foaming", "mousse", "lather"]
    let compatibleForms: [String]   // ["liquid", "gel"]
    let incompatibleForms: [String] // ["bar", "stick"]
    let keywords: [String]          // ["foam", "foaming", "mousse"]
}

class FormTaxonomy {
    private let forms: [FormType]
    
    // Normalize form from text
    func normalize(_ input: String) -> String?
    
    // Check compatibility
    func areCompatible(_ form1: String, _ form2: String) -> Bool
    
    // Infer form from product type and name
    func inferForm(productType: String, productName: String) -> String?
    
    // Extract form from text
    func extractForm(_ text: String) -> (form: String, confidence: Double)?
}
```

**Form Categories**:
```swift
// Liquid-based
"liquid" → ["liquid", "lotion", "serum"]
"cream" → ["cream", "créme", "moisturizer"]
"oil" → ["oil", "serum oil"]
"gel" → ["gel", "gelly", "jelly"]
"foam" → ["foam", "foaming", "mousse", "lather"]

// Solid-based
"bar" → ["bar", "bar soap", "soap bar"]
"stick" → ["stick", "roll-on"]
"powder" → ["powder", "loose powder", "pressed powder"]
"balm" → ["balm", "salve"]

// Spray-based
"spray" → ["spray", "mist", "spritz"]
"aerosol" → ["aerosol", "aerosol spray"]

// Special
"wax" → ["wax", "pomade wax"]
"other" → default
```

**Inference Rules**:
```swift
// Product type → likely form
"Foaming Facial Cleanser" → "foam"
"Bar Soap" → "bar"
"Hair Oil" → "oil"
"Deodorant Stick" → "stick"
"Setting Spray" → "spray"
"Face Cream" → "cream"
```

---

### Component 3: BrandDatabase.swift

**Purpose**: Intelligence about non-Black-owned brands users will scan

**Structure**:
```swift
struct Brand {
    let name: String                    // "CeraVe"
    let variations: [String]            // ["cerave", "cera ve"]
    let categories: [String]            // ["Skincare", "Face Care", "Body Care"]
    let positioning: BrandPositioning   // .clinical, .massMarket, .luxury
    let commonProducts: [String]        // ["Facial Cleanser", "Moisturizer"]
    let confidence: Double              // Recognition confidence
}

enum BrandPositioning {
    case clinical          // CeraVe, Neutrogena, La Roche-Posay
    case massMarket        // Dove, Pantene, Suave
    case natural           // Burt's Bees, Yes To
    case luxury            // SK-II, La Mer
    case premium           // Drunk Elephant, Tatcha
}

class BrandDatabase {
    private let brands: [Brand]
    
    // Detect brand from OCR text
    func detectBrand(_ text: String) -> Brand?
    
    // Get brand category
    func getBrandPositioning(_ brandName: String) -> BrandPositioning?
    
    // Check if brand is in database
    func isKnownBrand(_ name: String) -> Bool
}
```

**Example Brands** (50+ total):
```swift
// Clinical/Dermatologist Brands
Brand(name: "CeraVe", variations: ["cerave"], categories: ["Skincare", "Face Care", "Body Care"], 
      positioning: .clinical, commonProducts: ["Facial Cleanser", "Moisturizer", "Body Wash"])

Brand(name: "Neutrogena", variations: ["neutrogena"], categories: ["Skincare", "Face Care"], 
      positioning: .clinical, commonProducts: ["Facial Cleanser", "Sunscreen", "Moisturizer"])

Brand(name: "Cetaphil", variations: ["cetaphil"], categories: ["Skincare"], 
      positioning: .clinical, commonProducts: ["Facial Cleanser", "Moisturizer"])

// Mass Market Body Care
Brand(name: "Dove", variations: ["dove"], categories: ["Body Care", "Hair Care"], 
      positioning: .massMarket, commonProducts: ["Bar Soap", "Body Wash", "Shampoo"])

Brand(name: "Olay", variations: ["olay", "oil of olay"], categories: ["Skincare", "Body Care"], 
      positioning: .massMarket, commonProducts: ["Moisturizer", "Body Wash"])

// Mass Market Hair Care
Brand(name: "Pantene", variations: ["pantene", "pantene pro-v"], categories: ["Hair Care"], 
      positioning: .massMarket, commonProducts: ["Shampoo", "Conditioner"])

Brand(name: "Head & Shoulders", variations: ["head and shoulders", "head & shoulders"], 
      categories: ["Hair Care"], positioning: .massMarket, commonProducts: ["Shampoo"])

Brand(name: "TRESemmé", variations: ["tresemme", "tresemmé"], categories: ["Hair Care"], 
      positioning: .massMarket, commonProducts: ["Shampoo", "Conditioner", "Hair Spray"])

// Premium/Luxury
Brand(name: "Fenty Beauty", variations: ["fenty"], categories: ["Makeup"], 
      positioning: .premium, commonProducts: ["Foundation", "Lipstick"])
// Note: Fenty is Black-owned but users might scan to verify

Brand(name: "Drunk Elephant", variations: ["drunk elephant"], categories: ["Skincare"], 
      positioning: .premium, commonProducts: ["Face Serum", "Moisturizer"])
```

---

### Component 4: IngredientDatabase.swift

**Purpose**: Recognize ingredient keywords to avoid confusion

**Structure**:
```swift
struct IngredientKeyword {
    let name: String                // "shea butter"
    let variations: [String]        // ["shea", "sheabutter"]
    let commonInProducts: [String]  // ["Hair Cream", "Body Butter", "Lip Balm"]
    let isDescriptor: Bool          // true = just an ingredient, not product type
}

class IngredientDatabase {
    private let ingredients: [IngredientKeyword]
    
    // Detect ingredients in text
    func detectIngredients(_ text: String) -> [String]
    
    // Check if word is an ingredient
    func isIngredient(_ word: String) -> Bool
    
    // Calculate ingredient clarity score
    func calculateClarityScore(text: String, productType: String) -> Double
}
```

**Ingredient Categories**:
```swift
// Oils
["coconut oil", "coconut", "argan oil", "argan", "jojoba oil", "jojoba", 
 "castor oil", "castor", "olive oil", "avocado oil"]

// Butters
["shea butter", "shea", "cocoa butter", "cocoa", "mango butter", "mango"]

// Botanicals
["aloe vera", "aloe", "tea tree", "rose", "lavender", "chamomile", 
 "rosemary", "mint", "peppermint"]

// Actives
["vitamin c", "vitamin e", "vitamin", "hyaluronic acid", "hyaluronic", 
 "salicylic acid", "glycolic acid", "retinol", "niacinamide"]

// Proteins
["keratin", "collagen", "biotin", "protein"]

// Other
["honey", "charcoal", "clay", "oatmeal"]
```

**Clarity Scoring Logic**:
```swift
func calculateClarityScore(text: String, productType: String) -> Double {
    let detectedIngredients = detectIngredients(text)
    
    // No ingredients mentioned → perfect clarity
    if detectedIngredients.isEmpty {
        return 1.0
    }
    
    // Product type is clear and dominant
    // Example: "Coconut Oil Shampoo" - "shampoo" is clear, "coconut oil" is just ingredient
    if productType appears after ingredients {
        return 0.9
    }
    
    // Ingredient mentioned but product type is specific
    // Example: "Shea Moisture Curl Cream" - "cream" is clear
    if productType is specific (not "Other") {
        return 0.7
    }
    
    // Heavy ingredient focus, product type unclear
    // Example: "Pure Shea Butter" - is this butter product or has shea butter?
    if ingredients > 2 && productType is generic {
        return 0.5
    }
    
    // Ingredient IS the product type
    // Example: "Coconut Oil" - unclear if pure coconut oil or product with coconut oil
    if ingredient matches productType {
        return 0.3
    }
    
    return 0.5  // default
}
```

---

### Component 5: SizeExtractor.swift

**Purpose**: Extract size/quantity from product text

**Structure**:
```swift
struct ProductSize {
    let value: Double           // 12.0
    let unit: SizeUnit          // .fluidOunces
    let rawText: String         // "12 fl oz"
    let confidence: Double      // 0.9
}

enum SizeUnit {
    case fluidOunces           // oz, fl oz
    case milliliters           // ml, mL
    case grams                 // g, gm
    case pounds                // lb, lbs
    case liters                // l, L, liter
    case ounces                // oz (weight)
    case count                 // count, pieces
}

class SizeExtractor {
    // Extract size from text
    func extractSize(_ text: String) -> ProductSize?
    
    // Check if two sizes are compatible
    func areCompatible(_ size1: ProductSize, _ size2: ProductSize) -> Bool
    
    // Calculate size compatibility score
    func scoreCompatibility(_ scanned: ProductSize?, _ product: ProductSize?) -> Double
}
```

**Regex Patterns**:
```swift
let patterns = [
    // Fluid ounces
    #"(\d+(?:\.\d+)?)\s*(?:fl\s*)?oz"#,          // "12 fl oz", "8 oz"
    #"(\d+(?:\.\d+)?)\s*fluid\s*ounces?"#,       // "12 fluid ounces"
    
    // Milliliters
    #"(\d+(?:\.\d+)?)\s*ml"#i,                   // "350ml", "350 ML"
    #"(\d+(?:\.\d+)?)\s*milliliters?"#,          // "350 milliliters"
    
    // Grams
    #"(\d+(?:\.\d+)?)\s*g(?:\s|$)"#,             // "100g", "100 g"
    #"(\d+(?:\.\d+)?)\s*grams?"#,                // "100 grams"
    
    // Pounds
    #"(\d+(?:\.\d+)?)\s*lbs?"#,                  // "2 lb", "2 lbs"
    #"(\d+(?:\.\d+)?)\s*pounds?"#,               // "2 pounds"
    
    // Liters
    #"(\d+(?:\.\d+)?)\s*l(?:iter)?s?"#,          // "1L", "1 liter"
    
    // Count
    #"(\d+)\s*(?:count|ct|pieces?|pack)"#        // "24 count", "3 pack"
]
```

**Compatibility Scoring**:
```swift
func scoreCompatibility(_ scanned: ProductSize?, _ product: ProductSize?) -> Double {
    guard let scanned = scanned, let product = product else {
        return 0.5  // Unknown size
    }
    
    // Convert to common unit (ml for liquids, g for solids)
    let scannedMl = convertToMilliliters(scanned)
    let productMl = convertToMilliliters(product)
    
    let ratio = max(scannedMl, productMl) / min(scannedMl, productMl)
    
    if ratio <= 1.1 {         // Within 10%
        return 1.0
    } else if ratio <= 1.25 { // Within 25%
        return 0.9
    } else if ratio <= 1.5 {  // Within 50%
        return 0.7
    } else if ratio <= 2.0 {  // Within 2x
        return 0.5
    } else {
        return 0.3            // Very different
    }
}
```

---

### Component 6: AdvancedClassifier.swift

**Purpose**: Main classification engine - extract all 6 tiers from OCR text

**Structure**:
```swift
struct ScanClassification {
    // Tier 1: Product Type
    let productType: ProductTypeResult
    
    // Tier 2: Form
    let form: FormResult?
    
    // Tier 3: Brand
    let brand: BrandResult?
    
    // Tier 4: Ingredients
    let ingredients: [String]
    let ingredientClarity: Double
    
    // Tier 5: Size
    let size: ProductSize?
    
    // Raw data
    let rawText: String
    let processedText: String
}

struct ProductTypeResult {
    let type: String              // "Facial Cleanser"
    let confidence: Double        // 0.95
    let matchedKeywords: [String] // ["facial", "cleanser"]
    let category: String?         // "Skincare"
}

struct FormResult {
    let form: String              // "foam"
    let confidence: Double        // 0.90
    let source: FormSource        // .explicit (found in text) or .inferred
}

struct BrandResult {
    let name: String              // "CeraVe"
    let positioning: BrandPositioning
    let categories: [String]
    let confidence: Double
}

class AdvancedClassifier {
    private let productTaxonomy: ProductTaxonomy
    private let formTaxonomy: FormTaxonomy
    private let brandDatabase: BrandDatabase
    private let ingredientDatabase: IngredientDatabase
    private let sizeExtractor: SizeExtractor
    
    // Main classification method
    func classify(_ ocrText: String) -> ScanClassification
    
    // Tier 1: Product Type
    private func classifyProductType(_ text: String) -> ProductTypeResult
    
    // Tier 2: Form
    private func classifyForm(_ text: String, productType: String?) -> FormResult?
    
    // Tier 3: Brand
    private func detectBrand(_ text: String) -> BrandResult?
    
    // Tier 4: Ingredients
    private func analyzeIngredients(_ text: String, productType: String) -> (ingredients: [String], clarity: Double)
    
    // Tier 5: Size
    private func extractSize(_ text: String) -> ProductSize?
    
    // Text preprocessing
    private func preprocessText(_ text: String) -> String
}
```

**Classification Algorithm**:
```swift
func classify(_ ocrText: String) -> ScanClassification {
    // Step 1: Preprocess text
    let processed = preprocessText(ocrText)
    
    // Step 2: Extract product type (MOST IMPORTANT)
    let productType = classifyProductType(processed)
    
    // Step 3: Extract form (use product type for inference)
    let form = classifyForm(processed, productType: productType.type)
    
    // Step 4: Detect brand
    let brand = detectBrand(processed)
    
    // Step 5: Analyze ingredients
    let (ingredients, clarity) = analyzeIngredients(processed, productType: productType.type)
    
    // Step 6: Extract size
    let size = extractSize(processed)
    
    return ScanClassification(
        productType: productType,
        form: form,
        brand: brand,
        ingredients: ingredients,
        ingredientClarity: clarity,
        size: size,
        rawText: ocrText,
        processedText: processed
    )
}
```

---

### Component 7: ConfidenceScorer.swift

**Purpose**: Score products cumulatively against classification

**Structure**:
```swift
struct ScoredProduct {
    let product: Product
    let confidenceScore: Double       // 0.0-1.0 (final cumulative)
    let breakdown: ScoreBreakdown
    let explanation: String
}

struct ScoreBreakdown {
    let productTypeScore: Double      // 0.0-1.0
    let formScore: Double             // 0.0-1.0
    let brandScore: Double            // 0.0-1.0
    let ingredientScore: Double       // 0.0-1.0
    let sizeScore: Double             // 0.0-1.0
    let visualScore: Double?          // 0.0-1.0 (Phase 2)
    
    // Human-readable details
    var details: [String: Double] {
        [
            "Product Type": productTypeScore,
            "Form/Dispensing": formScore,
            "Brand Category": brandScore,
            "Ingredient Clarity": ingredientScore,
            "Size": sizeScore
        ]
    }
}

class ConfidenceScorer {
    private let productTaxonomy: ProductTaxonomy
    private let formTaxonomy: FormTaxonomy
    private let sizeExtractor: SizeExtractor
    
    // Main scoring method
    func score(product: Product, against classification: ScanClassification) -> ScoredProduct
    
    // Individual tier scoring
    private func scoreProductType(_ productType: String, against target: ProductTypeResult) -> Double
    private func scoreForm(_ form: String?, against target: FormResult?) -> Double
    private func scoreBrand(_ product: Product, against brand: BrandResult?) -> Double
    private func scoreIngredients(_ product: Product, clarity: Double) -> Double
    private func scoreSize(_ product: Product, against size: ProductSize?) -> Double
}
```

**Cumulative Scoring Algorithm**:
```swift
func score(product: Product, against classification: ScanClassification) -> ScoredProduct {
    // TIER 1: Product Type (40% weight)
    let productTypeScore = scoreProductType(
        product.productType,
        against: classification.productType
    )
    
    // TIER 2: Form (25% weight)
    let formScore = scoreForm(
        product.form,
        against: classification.form
    )
    
    // TIER 3: Brand Category (15% weight)
    let brandScore = scoreBrand(
        product,
        against: classification.brand
    )
    
    // TIER 4: Ingredient Clarity (10% weight)
    let ingredientScore = scoreIngredients(
        product,
        clarity: classification.ingredientClarity
    )
    
    // TIER 5: Size (5% weight)
    let sizeScore = scoreSize(
        product,
        against: classification.size
    )
    
    // CUMULATIVE WEIGHTED SCORE
    let finalScore = (
        (productTypeScore * 0.40) +
        (formScore * 0.25) +
        (brandScore * 0.15) +
        (ingredientScore * 0.10) +
        (sizeScore * 0.05)
        // + (visualScore * 0.05) in Phase 2
    )
    
    let breakdown = ScoreBreakdown(
        productTypeScore: productTypeScore,
        formScore: formScore,
        brandScore: brandScore,
        ingredientScore: ingredientScore,
        sizeScore: sizeScore,
        visualScore: nil
    )
    
    let explanation = buildExplanation(breakdown, classification, product)
    
    return ScoredProduct(
        product: product,
        confidenceScore: finalScore,
        breakdown: breakdown,
        explanation: explanation
    )
}
```

**Individual Scoring Functions**:

```swift
// TIER 1: Product Type Scoring
func scoreProductType(_ productType: String, against target: ProductTypeResult) -> Double {
    let normalizedProduct = productTaxonomy.normalize(productType)
    let normalizedTarget = productTaxonomy.normalize(target.type)
    
    // Exact match
    if normalizedProduct == normalizedTarget {
        return 1.0
    }
    
    // Synonym match
    if productTaxonomy.areSynonyms(normalizedProduct ?? "", normalizedTarget ?? "") {
        return 0.9
    }
    
    // Same category
    if let productCat = productTaxonomy.getCategory(productType),
       let targetCat = productTaxonomy.getCategory(target.type),
       productCat == targetCat {
        return 0.6
    }
    
    // Partial keyword match
    let productKeywords = Set(productType.lowercased().split(separator: " "))
    let targetKeywords = Set(target.type.lowercased().split(separator: " "))
    let overlap = productKeywords.intersection(targetKeywords)
    
    if overlap.count >= 1 {
        return 0.4
    }
    
    return 0.0
}

// TIER 2: Form Scoring
func scoreForm(_ form: String?, against target: FormResult?) -> Double {
    guard let form = form, let target = target else {
        return 0.5  // Unknown form, neutral score
    }
    
    let normalizedForm = formTaxonomy.normalize(form) ?? form
    let normalizedTarget = formTaxonomy.normalize(target.form) ?? target.form
    
    // Exact match
    if normalizedForm == normalizedTarget {
        return 1.0
    }
    
    // Compatible forms
    if formTaxonomy.areCompatible(normalizedForm, normalizedTarget) {
        return 0.7
    }
    
    // Generic/other
    if normalizedForm == "other" || normalizedTarget == "other" {
        return 0.5
    }
    
    // Incompatible
    return 0.3
}

// TIER 3: Brand Category Scoring
func scoreBrand(_ product: Product, against brand: BrandResult?) -> Double {
    guard let brand = brand else {
        return 0.5  // No brand detected, neutral
    }
    
    // Check if product's category matches scanned brand's categories
    let productCategory = product.mainCategory
    
    if brand.categories.contains(where: { $0.lowercased() == productCategory.lowercased() }) {
        return 1.0  // Same category
    }
    
    // Check if related categories (e.g., "Face Care" and "Skin Care")
    if areRelatedCategories(productCategory, brand.categories) {
        return 0.7
    }
    
    return 0.5  // Different category but OK
}

// TIER 4: Ingredient Clarity Scoring
func scoreIngredients(_ product: Product, clarity: Double) -> Double {
    // The clarity score is already calculated in classification
    // Just return it (it's already 0.0-1.0)
    return clarity
}

// TIER 5: Size Scoring
func scoreSize(_ product: Product, against size: ProductSize?) -> Double {
    guard let scannedSize = size else {
        return 0.5  // No size detected, neutral
    }
    
    // Try to extract size from product name or tags
    let productSize = sizeExtractor.extractSize(product.name) 
                   ?? extractSizeFromTags(product.tags)
    
    guard let productSize = productSize else {
        return 0.5  // Product has no size info
    }
    
    return sizeExtractor.scoreCompatibility(scannedSize, productSize)
}
```

---

## 5. COMPLETE LOGIC FLOW

### Detailed Step-by-Step Process

```
USER ACTION: Scans "CeraVe Foaming Facial Cleanser For Normal to Oily Skin 12 fl oz"
│
├─► STEP 1: OCR Recognition (LiveScannerView.swift)
│   ├─ VisionKit captures text: "CeraVe Foaming Facial Cleanser For Normal to Oily Skin 12 fl oz"
│   ├─ Debounce: Wait 1 second for more text
│   └─ Callback to ScanView with recognized text
│
├─► STEP 2: Text Preprocessing (AdvancedClassifier.swift)
│   ├─ Convert to lowercase: "cerave foaming facial cleanser for normal to oily skin 12 fl oz"
│   ├─ Remove noise: "™", "®", "©"
│   ├─ Normalize whitespace
│   └─ Result: "cerave foaming facial cleanser for normal to oily skin 12 fl oz"
│
├─► STEP 3: TIER 1 - Product Type Classification
│   ├─ Scan for product type keywords: ["facial", "cleanser"]
│   ├─ Match against ProductTaxonomy
│   ├─ Find: "Facial Cleanser" (canonical)
│   ├─ Confidence: 0.95 (both keywords present, clear match)
│   └─ Result: ProductTypeResult(type: "Facial Cleanser", confidence: 0.95)
│
├─► STEP 4: TIER 2 - Form Classification
│   ├─ Scan for form keywords: ["foaming"]
│   ├─ Match against FormTaxonomy
│   ├─ "foaming" → canonical: "foam"
│   ├─ Confidence: 0.90 (explicit mention)
│   └─ Result: FormResult(form: "foam", confidence: 0.90, source: .explicit)
│
├─► STEP 5: TIER 3 - Brand Detection
│   ├─ Scan for brand names: ["cerave"]
│   ├─ Match against BrandDatabase
│   ├─ Found: "CeraVe" (clinical dermatologist brand)
│   ├─ Categories: ["Skincare", "Face Care", "Body Care"]
│   ├─ Positioning: .clinical
│   └─ Result: BrandResult(name: "CeraVe", positioning: .clinical, confidence: 0.95)
│
├─► STEP 6: TIER 4 - Ingredient Analysis
│   ├─ Scan for ingredients: None found (no "shea", "coconut", "argan", etc.)
│   ├─ Product type is clear: "Facial Cleanser"
│   ├─ No confusion between ingredients and product type
│   └─ Result: ingredients: [], clarity: 1.0
│
├─► STEP 7: TIER 5 - Size Extraction
│   ├─ Scan for size patterns: "12 fl oz"
│   ├─ Regex match: (\d+(?:\.\d+)?)\s*(?:fl\s*)?oz
│   ├─ Extract: 12.0 fluid ounces
│   └─ Result: ProductSize(value: 12.0, unit: .fluidOunces)
│
├─► STEP 8: Build Classification Object
│   └─ ScanClassification(
│       productType: "Facial Cleanser" (0.95),
│       form: "foam" (0.90),
│       brand: "CeraVe" (clinical, 0.95),
│       ingredients: [],
│       ingredientClarity: 1.0,
│       size: 12 fl oz
│     )
│
├─► STEP 9: Typesense Search (TypesenseClient.swift)
│   ├─ Build search query: "facial cleanser face wash foaming"
│   ├─ Add filters: main_category: ["Beauty & Personal Care", "Skin Care"]
│   ├─ Weighted search: product_type^3, form^2, name^1, tags^1
│   ├─ Retrieve: 100+ candidate products
│   └─ Results: 127 products returned
│
├─► STEP 10: Score Each Product (ConfidenceScorer.swift)
│   │
│   ├─ Product A: "African Black Soap Foaming Facial Cleanser" (8 oz)
│   │   ├─ Tier 1: "Facial Cleanser" = "Facial Cleanser" → 1.0 × 0.40 = 0.40
│   │   ├─ Tier 2: "foam" = "foam" → 1.0 × 0.25 = 0.25
│   │   ├─ Tier 3: Face Care category matches → 1.0 × 0.15 = 0.15
│   │   ├─ Tier 4: No confusion → 1.0 × 0.10 = 0.10
│   │   ├─ Tier 5: 8 oz within 50% of 12 oz → 0.7 × 0.05 = 0.035
│   │   └─ TOTAL: 0.40 + 0.25 + 0.15 + 0.10 + 0.035 = 0.935 (93.5%)
│   │
│   ├─ Product B: "Clean Up Gel Facial Cleanser" (12 oz)
│   │   ├─ Tier 1: "Facial Cleanser" = "Facial Cleanser" → 1.0 × 0.40 = 0.40
│   │   ├─ Tier 2: "gel" compatible with "foam" → 0.7 × 0.25 = 0.175
│   │   ├─ Tier 3: Face Care category matches → 1.0 × 0.15 = 0.15
│   │   ├─ Tier 4: No confusion → 1.0 × 0.10 = 0.10
│   │   ├─ Tier 5: 12 oz exact match → 1.0 × 0.05 = 0.05
│   │   └─ TOTAL: 0.40 + 0.175 + 0.15 + 0.10 + 0.05 = 0.875 (87.5%)
│   │
│   ├─ Product C: "Moisturizing Face Wash" (16 oz)
│   │   ├─ Tier 1: "Face Wash" synonym of "Facial Cleanser" → 0.9 × 0.40 = 0.36
│   │   ├─ Tier 2: "liquid" compatible → 0.7 × 0.25 = 0.175
│   │   ├─ Tier 3: Face Care matches → 1.0 × 0.15 = 0.15
│   │   ├─ Tier 4: "Moisturizing" is descriptor, not ingredient → 0.9 × 0.10 = 0.09
│   │   ├─ Tier 5: 16 oz within 50% → 0.7 × 0.05 = 0.035
│   │   └─ TOTAL: 0.36 + 0.175 + 0.15 + 0.09 + 0.035 = 0.81 (81%)
│   │
│   ├─ Product D: "Shea Butter Cleanser" (unknown size)
│   │   ├─ Tier 1: "Cleanser" partial match → 0.6 × 0.40 = 0.24
│   │   ├─ Tier 2: Form unknown → 0.5 × 0.25 = 0.125
│   │   ├─ Tier 3: Face Care matches → 1.0 × 0.15 = 0.15
│   │   ├─ Tier 4: "Shea Butter" ingredient in name → 0.7 × 0.10 = 0.07
│   │   ├─ Tier 5: Size unknown → 0.5 × 0.05 = 0.025
│   │   └─ TOTAL: 0.24 + 0.125 + 0.15 + 0.07 + 0.025 = 0.61 (61%)
│   │
│   └─ Product E: "Body Wash" (16 oz)
│       ├─ Tier 1: "Body Wash" wrong category → 0.2 × 0.40 = 0.08
│       ├─ Tier 2: "liquid" form → 0.7 × 0.25 = 0.175
│       ├─ Tier 3: Body Care, not Face Care → 0.5 × 0.15 = 0.075
│       ├─ Tier 4: No confusion → 1.0 × 0.10 = 0.10
│       ├─ Tier 5: 16 oz close → 0.7 × 0.05 = 0.035
│       └─ TOTAL: 0.08 + 0.175 + 0.075 + 0.10 + 0.035 = 0.465 (46.5%)
│
├─► STEP 11: Filter & Rank
│   ├─ Filter: Remove products with confidence < 30% (threshold)
│   ├─ Sort: By confidence score (descending)
│   ├─ Result: 31 products above threshold
│   └─ Select: Top 20 products
│
├─► STEP 12: Display Results (CameraScanView.swift)
│   ├─ Header:
│   │   ├─ "Found: Facial Cleanser"
│   │   ├─ "Confidence: 93.5%" (top product's score)
│   │   └─ "Black-owned alternatives to CeraVe"
│   ├─ Meta: "Showing 20 of 31 products"
│   ├─ Sort: "Suggested" (by confidence)
│   └─ Grid: Display top 20 products with numbered badges
│
└─► STEP 13: Log Scan (ScanLogger.swift)
    ├─ Save to CoreData:
    │   ├─ OCR text
    │   ├─ Classification results
    │   ├─ Number of results
    │   ├─ Top result confidence
    │   └─ Timestamp
    └─ Use for future improvement
```

---

## 6. ALGORITHMS & SCORING FUNCTIONS

### Master Scoring Algorithm

```swift
func calculateFinalConfidence(
    product: Product,
    classification: ScanClassification
) -> Double {
    
    // TIER 1: Product Type (40%)
    let t1 = scoreProductType(product.productType, classification.productType)
    
    // TIER 2: Form (25%)
    let t2 = scoreForm(product.form, classification.form)
    
    // TIER 3: Brand Category (15%)
    let t3 = scoreBrandCategory(product, classification.brand)
    
    // TIER 4: Ingredient Clarity (10%)
    let t4 = classification.ingredientClarity
    
    // TIER 5: Size (5%)
    let t5 = scoreSize(product, classification.size)
    
    // TIER 6: Visual (5%) - Phase 2
    let t6 = 0.5  // Neutral for now
    
    // WEIGHTED CUMULATIVE SCORE
    return (t1 * 0.40) + (t2 * 0.25) + (t3 * 0.15) + (t4 * 0.10) + (t5 * 0.05) + (t6 * 0.05)
}
```

### String Similarity Algorithm

For fuzzy matching of product types:

```swift
func normalizedLevenshteinDistance(_ s1: String, _ s2: String) -> Double {
    let distance = levenshteinDistance(s1, s2)
    let maxLength = max(s1.count, s2.count)
    return 1.0 - (Double(distance) / Double(maxLength))
}

func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
    let s1 = Array(s1.lowercased())
    let s2 = Array(s2.lowercased())
    
    var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2.count + 1), count: s1.count + 1)
    
    for i in 0...s1.count {
        matrix[i][0] = i
    }
    
    for j in 0...s2.count {
        matrix[0][j] = j
    }
    
    for i in 1...s1.count {
        for j in 1...s2.count {
            if s1[i-1] == s2[j-1] {
                matrix[i][j] = matrix[i-1][j-1]
            } else {
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,     // deletion
                    matrix[i][j-1] + 1,     // insertion
                    matrix[i-1][j-1] + 1    // substitution
                )
            }
        }
    }
    
    return matrix[s1.count][s2.count]
}
```

### Keyword Matching Algorithm

```swift
func scoreKeywordMatch(_ text: String, _ keywords: [String]) -> Double {
    let textWords = Set(text.lowercased().split(separator: " ").map(String.init))
    let keywordSet = Set(keywords.map { $0.lowercased() })
    
    let matches = textWords.intersection(keywordSet)
    
    if matches.isEmpty {
        return 0.0
    }
    
    // Score based on percentage of keywords matched
    let matchPercentage = Double(matches.count) / Double(keywordSet.count)
    
    // Bonus for complete match
    if matches.count == keywordSet.count {
        return 1.0
    }
    
    // Bonus for multiple matches
    if matches.count >= 2 {
        return min(matchPercentage * 1.2, 1.0)
    }
    
    return matchPercentage
}
```

---

## 7. DATA STRUCTURES

### Core Models

```swift
// Product (existing in Models.swift, enhanced)
struct Product: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let company: String
    let price: Double
    let imageUrl: String
    let productUrl: String
    let mainCategory: String
    let productType: String
    let form: String?
    let setBundle: String?
    let tags: [String]?
    let subcategory2: String?
    
    var formattedPrice: String
    var categoryDisplay: String
}

// NEW: Scored Product (result of confidence scoring)
struct ScoredProduct: Identifiable {
    let id: String  // product.id
    let product: Product
    let confidenceScore: Double
    let breakdown: ScoreBreakdown
    let explanation: String
    
    var confidencePercentage: Int {
        Int(confidenceScore * 100)
    }
    
    var confidenceLevel: ConfidenceLevel {
        switch confidenceScore {
        case 0.9...1.0: return .excellent
        case 0.75..<0.9: return .good
        case 0.5..<0.75: return .fair
        default: return .low
        }
    }
}

enum ConfidenceLevel {
    case excellent  // 90%+
    case good       // 75-89%
    case fair       // 50-74%
    case low        // <50%
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return Color(red: 0.5, green: 0.8, blue: 0.3)
        case .fair: return .orange
        case .low: return .red
        }
    }
}

// NEW: Score Breakdown
struct ScoreBreakdown {
    let productTypeScore: Double
    let formScore: Double
    let brandScore: Double
    let ingredientScore: Double
    let sizeScore: Double
    let visualScore: Double?
    
    var totalWeighted: Double {
        (productTypeScore * 0.40) +
        (formScore * 0.25) +
        (brandScore * 0.15) +
        (ingredientScore * 0.10) +
        (sizeScore * 0.05) +
        ((visualScore ?? 0.5) * 0.05)
    }
    
    var criteriaMatched: Int {
        var count = 0
        if productTypeScore >= 0.7 { count += 1 }
        if formScore >= 0.7 { count += 1 }
        if brandScore >= 0.7 { count += 1 }
        if ingredientScore >= 0.7 { count += 1 }
        if sizeScore >= 0.7 { count += 1 }
        return count
    }
}
```

### Classification Models

```swift
// Complete scan classification
struct ScanClassification {
    let productType: ProductTypeResult
    let form: FormResult?
    let brand: BrandResult?
    let ingredients: [String]
    let ingredientClarity: Double
    let size: ProductSize?
    let rawText: String
    let processedText: String
    let timestamp: Date
    
    // Computed
    var inferredMainCategory: String {
        productType.category ?? "Beauty & Personal Care"
    }
    
    var searchQuery: String {
        buildOptimizedSearchQuery()
    }
}

// Product type result
struct ProductTypeResult {
    let type: String
    let confidence: Double
    let matchedKeywords: [String]
    let category: String?
    let subcategory: String?
}

// Form result
struct FormResult {
    let form: String
    let confidence: Double
    let source: FormSource
}

enum FormSource {
    case explicit      // Found in text: "foaming"
    case inferred      // Inferred from product type: "Bar Soap" → "bar"
    case unknown       // Could not determine
}

// Brand result
struct BrandResult {
    let name: String
    let positioning: BrandPositioning
    let categories: [String]
    let confidence: Double
}

enum BrandPositioning {
    case clinical
    case massMarket
    case natural
    case luxury
    case premium
}

// Product size
struct ProductSize {
    let value: Double
    let unit: SizeUnit
    let rawText: String
    let confidence: Double
}

enum SizeUnit: String {
    case fluidOunces = "fl oz"
    case milliliters = "ml"
    case grams = "g"
    case pounds = "lb"
    case liters = "L"
    case ounces = "oz"
    case count = "count"
}
```

### Logging Models

```swift
// CoreData entity for scan logging
@objc(ScanLog)
class ScanLog: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var timestamp: Date
    @NSManaged var ocrText: String
    @NSManaged var processedText: String
    
    // Classification results
    @NSManaged var detectedProductType: String?
    @NSManaged var detectedForm: String?
    @NSManaged var detectedBrand: String?
    @NSManaged var detectedSize: String?
    
    // Results
    @NSManaged var resultsCount: Int
    @NSManaged var topResultConfidence: Double
    @NSManaged var averageConfidence: Double
    
    // User action
    @NSManaged var userViewedResults: Bool
    @NSManaged var userSelectedProduct: Bool
    @NSManaged var selectedProductId: String?
    @NSManaged var selectedProductRank: Int  // Was it #1, #2, etc?
    
    // For improvement
    @NSManaged var wasSuccessful: Bool  // confidence >= 0.5
    @NSManaged var needsReview: Bool    // confidence < 0.3
}
```

---

## 8. SEARCH STRATEGY

### Product Filtering Gates (NEW in v2.2)

Before scoring, products go through **4 filtering gates** to ensure high accuracy:

#### Gate 1: Accessory Filter
**Problem**: User scans "Foundation" but gets "Foundation Brush" as top result  
**Solution**: Filter out accessories when scanning consumable products

Keywords: `brush`, `applicator`, `sponge`, `tool`, `mirror`, `bag`, `case`, `holder`, `dispenser`, `blender`

#### Gate 2: Use-Case Validation
**Problem**: "Hand Wash" returns "Feminine Wash" products  
**Solution**: Block use-case mismatches
- Hand/Face products ≠ Feminine products
- Shampoo ≠ Conditioner
- Body products ≠ Facial products

#### Gate 3: Form Type Mismatch Detection
**Problem**: "Facial Towelettes" returns facial lotions/creams  
**Solution**: Block incompatible forms
- Towelettes/Wipes ≠ Lotions/Creams/Serums
- Serum ≠ Lotion/Conditioner
- Powder ≠ Liquid/Cream
- Bar ≠ Liquid/Gel
- Spray ≠ Cream/Bar

#### Gate 4: Specificity-Based Name Scoring
**Problem**: "Leave-In Serum" matches "Leave-In Conditioner" equally  
**Solution**: Prioritize specific descriptor words over generic modifiers

**Specific words** (high priority): `sanitizer`, `cleanser`, `wash`, `soap`, `shampoo`, `conditioner`, `lotion`, `cream`, `serum`, `oil`, `gel`, `balm`, `butter`, `mask`, `scrub`, `toner`, `primer`, `foundation`, `powder`, `spray`, `foam`, `bar`, `wipe`, `towelette`

**Scoring**:
- Full phrase match: **100%**
- Multiple specific words match: **95%**
- One specific word + most other words: **70%**
- One specific word only: **55%**
- Multiple generic words: **40%**
- One generic word or tags: **25-35%**
- No match: **FILTER OUT**

**Example**: "Leave-In Serum"
- ✅ "Hydrating Leave-In Serum" → 95% (both "leave-in" and "serum" match)
- ✅ "Leave-In Hair Serum" → 95% (both specific words)
- ⚠️ "Leave-In Conditioner" → 70% ("leave-in" matches, "serum" missing)
- ⚠️ "Hair Serum" → 55% ("serum" matches, "leave-in" missing)
- ❌ "Leave-In Detangler" → 40% (only "leave-in" generic word)

### Typesense Query Structure

```swift
// Build optimized search query
func buildOptimizedSearchQuery(_ classification: ScanClassification) -> String {
    var queryTerms: [String] = []
    
    // Primary: Product type (most important)
    queryTerms.append(classification.productType.type)
    
    // Add synonyms for better recall
    if let synonyms = productTaxonomy.getSynonyms(classification.productType.type) {
        queryTerms.append(contentsOf: synonyms.prefix(2))
    }
    
    // Secondary: Form (if confident)
    if let form = classification.form, form.confidence > 0.7 {
        queryTerms.append(form.form)
    }
    
    // Tertiary: Category keywords
    if let category = classification.productType.category {
        queryTerms.append(category.lowercased())
    }
    
    return queryTerms.joined(separator: " ")
}

// Example queries:
// "facial cleanser face wash skincare"
// "shampoo hair cleanser hair care"
// "body butter body cream moisturizer body care"
```

### Weighted Field Search

```swift
// In TypesenseClient.swift
func searchWithConfidenceRanking(
    classification: ScanClassification,
    maxResults: Int = 20
) async throws -> [ScoredProduct] {
    
    let query = buildOptimizedSearchQuery(classification)
    
    // WEIGHTED FIELDS
    // product_type^3 = 3x weight (most important)
    // form^2 = 2x weight
    // name^1 = 1x weight (default)
    // tags^1 = 1x weight
    let queryBy = "product_type^3,form^2,name^1,tags^1"
    
    // FILTERS
    var filters: [String] = []
    
    // Filter by main category if confident
    if classification.productType.confidence > 0.7 {
        let category = classification.inferredMainCategory
        filters.append("main_category:[\(category)]")
    }
    
    // Combine filters
    let filterBy = filters.isEmpty ? nil : filters.joined(separator: " && ")
    
    // SEARCH
    let params = SearchParameters(
        query: query,
        page: 1,
        perPage: 100,  // Get 100 candidates
        queryBy: queryBy,
        filterBy: filterBy
    )
    
    let response = try await search(parameters: params)
    
    // SCORE EACH RESULT
    let scorer = ConfidenceScorer()
    let scoredProducts = response.products.map { product in
        scorer.score(product: product, against: classification)
    }
    
    // FILTER & RANK
    let filtered = scoredProducts.filter { $0.confidenceScore >= 0.3 }  // 30% threshold
    let sorted = filtered.sorted { $0.confidenceScore > $1.confidenceScore }
    
    return Array(sorted.prefix(maxResults))
}
```

### Multi-Pass Fallback (if needed)

```swift
// If first search returns < 10 results, broaden
func searchWithFallback(
    classification: ScanClassification
) async throws -> [ScoredProduct] {
    
    // Pass 1: Strict search
    var results = try await searchWithConfidenceRanking(
        classification: classification,
        maxResults: 20
    )
    
    // If insufficient results, broaden
    if results.count < 10 {
        // Pass 2: Remove form filter
        var broadenedClassification = classification
        broadenedClassification.form = nil
        
        let additionalResults = try await searchWithConfidenceRanking(
            classification: broadenedClassification,
            maxResults: 30
        )
        
        // Merge and re-sort
        results.append(contentsOf: additionalResults)
        results = Array(Set(results))  // Remove duplicates
        results.sort { $0.confidenceScore > $1.confidenceScore }
        results = Array(results.prefix(20))
    }
    
    return results
}
```

---

## 9. UI/UX DESIGN

### Results Card Design

**From Screenshot Analysis**:

```swift
// Results bottom sheet
struct ScanResultsCard: View {
    let classification: ScanClassification
    let results: [ScoredProduct]
    
    var body: some View {
        VStack(spacing: 0) {
            // HEADER
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text("Found: \(classification.productType.type)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                // Confidence
                HStack(spacing: 4) {
                    Text("Confidence:")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("\(results.first?.confidencePercentage ?? 0)%")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(results.first?.confidenceLevel.color ?? .gray)
                }
                
                // Subtitle
                Text(buildSubtitle())
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // META INFO
            HStack {
                Text("Showing \(min(results.count, 20)) of \(results.count) products")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Sort dropdown
                Menu {
                    Button("Suggested (Confidence)") { }
                    Button("Price: Low to High") { }
                    Button("Price: High to Low") { }
                    Button("Alphabetical") { }
                } label: {
                    HStack {
                        Text("Suggested")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // PRODUCTS GRID
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 16) {
                    ForEach(Array(results.prefix(20).enumerated()), id: \.element.id) { index, scoredProduct in
                        ProductCardWithBadge(
                            product: scoredProduct.product,
                            number: index + 1,
                            confidence: scoredProduct.confidenceScore
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(24)
    }
    
    func buildSubtitle() -> String {
        if let brand = classification.brand {
            return "Black-owned alternatives to \(brand.name)"
        } else {
            return "Black-owned \(classification.productType.type.lowercased()) products"
        }
    }
}
```

### Product Card with Confidence Badge

```swift
struct ProductCardWithBadge: View {
    let product: Product
    let number: Int
    let confidence: Double
    
    @State private var isSaved = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // IMAGE + BADGES
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: product.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemGray6)
                        .overlay(ProgressView())
                }
                .frame(height: 180)
                .clipped()
                
                // Number Badge (top-left)
                Circle()
                    .fill(Color(red: 0.26, green: 0.63, blue: 0.95))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text("\(number)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 10, y: 10)
                
                // Confidence Badge (top-right) - optional
                if confidence >= 0.9 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("\(Int(confidence * 100))%")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.9))
                    .cornerRadius(12)
                    .offset(x: -10, y: 10)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                // Heart Icon (top-right)
                Button {
                    isSaved.toggle()
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(isSaved ? .red : .white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                .offset(x: -10, y: 10)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            // PRODUCT INFO
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(height: 36, alignment: .top)
                
                Text(product.company)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(product.formattedPrice)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
```

---

## 10. TESTING & VALIDATION

### Test Cases

**Basic Product Types**:
```swift
let basicTests = [
    ("Dove Bar Soap", "Bar Soap", 0.95),
    ("CeraVe Foaming Facial Cleanser", "Facial Cleanser", 0.95),
    ("Pantene Pro-V Shampoo", "Shampoo", 0.95),
    ("Neutrogena Hydro Boost Water Gel", "Face Moisturizer", 0.90),
    ("Olay Body Wash", "Body Wash", 0.95),
]
```

**Complex Cases (with ingredients)**:
```swift
let complexTests = [
    ("Shea Moisture Coconut & Hibiscus Curl Cream", "Hair Cream", 0.85),
    ("Burt's Bees Lip Balm with Coconut Oil", "Lip Balm", 0.90),
    ("Aveeno Daily Moisturizing Lotion with Oatmeal", "Body Lotion", 0.85),
]
```

**Edge Cases**:
```swift
let edgeCases = [
    ("2-in-1 Shampoo and Conditioner", "Shampoo", 0.75),
    ("Lip Balm SPF 30", "Lip Balm", 0.90),
    ("All-in-One Face Wash & Scrub", "Facial Cleanser", 0.70),
]
```

### Validation Process

```swift
class ScanAccuracyTester {
    func runTestSuite() -> TestResults {
        var results = TestResults()
        
        // Test basic cases
        for (input, expected, minConfidence) in basicTests {
            let classification = classifier.classify(input)
            let isCorrect = classification.productType.type == expected
            let meetsThreshold = classification.productType.confidence >= minConfidence
            
            results.addResult(
                input: input,
                expected: expected,
                actual: classification.productType.type,
                confidence: classification.productType.confidence,
                passed: isCorrect && meetsThreshold
            )
        }
        
        // Calculate accuracy
        let accuracy = Double(results.passedCount) / Double(results.totalCount)
        results.accuracy = accuracy
        
        return results
    }
}

struct TestResults {
    var totalCount = 0
    var passedCount = 0
    var failedTests: [(input: String, expected: String, actual: String, confidence: Double)] = []
    var accuracy: Double = 0.0
    
    mutating func addResult(input: String, expected: String, actual: String, confidence: Double, passed: Bool) {
        totalCount += 1
        if passed {
            passedCount += 1
        } else {
            failedTests.append((input, expected, actual, confidence))
        }
    }
    
    func printReport() {
        print("=== SCAN ACCURACY TEST RESULTS ===")
        print("Total Tests: \(totalCount)")
        print("Passed: \(passedCount)")
        print("Failed: \(failedTests.count)")
        print("Accuracy: \(accuracy * 100)%")
        print()
        
        if !failedTests.isEmpty {
            print("Failed Tests:")
            for test in failedTests {
                print("  Input: \(test.input)")
                print("  Expected: \(test.expected)")
                print("  Actual: \(test.actual)")
                print("  Confidence: \(test.confidence)")
                print()
            }
        }
    }
}
```

---

## 11. FUTURE ENHANCEMENTS

### Phase 2: Visual Recognition

**Goal**: Add visual product recognition using CoreML

**Implementation**:
1. Train CoreML model on product packaging shapes
2. Categories: pump bottle, tube, jar, stick, bar, aerosol, etc.
3. Integrate with existing scoring (Tier 6)

**Benefits**:
- Disambiguate unclear text scans
- Add 5% to confidence scoring
- Better handle worn/damaged labels

---

### Phase 3: Backend Logging & Analytics

**Goal**: Centralized logging for continuous improvement

**Features**:
- Cloud sync of scan logs
- Dashboard for failed scans
- Analytics: most scanned products, success rates by category
- A/B testing of classification rules

**Tech Stack**:
- Firebase/Supabase for backend
- Analytics dashboard (web)
- Automated alerts for low-confidence scans

---

### Phase 4: Machine Learning Enhancement

**Goal**: Supplement rules with ML for edge cases

**Approach**:
- Keep rule-based system as primary
- Add ML model for "Other" products (the 7,108 uncategorized)
- Train on logged scan data
- Use ML only when rules confidence < 0.6

**Benefits**:
- Handle long-tail products
- Continuous improvement from user scans
- Maintain speed and privacy (local ML)

---

## 12. TECHNICAL DECISIONS LOG

### Decision 1: Fully Local vs Cloud ML
**Chosen**: Fully local  
**Rationale**:
- Privacy-first (no data leaves device)
- Works offline
- Faster (no network latency)
- No API costs
- Rule-based can achieve 95%+ with good design

### Decision 2: Cumulative Scoring vs Pass/Fail
**Chosen**: Cumulative weighted scoring  
**Rationale**:
- More accurate than binary classification
- Allows showing "why" a product matched
- Gracefully handles imperfect matches
- Users see best alternatives even if not perfect

### Decision 3: 6-Tier System Weights
**Weights**: 40% + 25% + 15% + 10% + 5% + 5%  
**Rationale**:
- Product type is most critical (40%)
- Form/dispensing is important for UX (25%)
- Brand category helps positioning (15%)
- Ingredients prevent confusion (10%)
- Size is nice-to-have (5%)
- Visual is future enhancement (5%)

### Decision 4: Search Strategy
**Chosen**: Single broad search + local scoring  
**Rationale**:
- Simpler than multi-pass
- Faster (one network call)
- More flexible (scoring happens locally)
- Easier to debug and improve

### Decision 5: Threshold for Results
**Chosen**: 30% minimum confidence  
**Rationale**:
- Below 30% is likely irrelevant
- Ensures quality results
- Users see 20-100 products typically
- Can adjust based on testing

### Decision 6: Local Logging (CoreData)
**Chosen**: CoreData for now, cloud later  
**Rationale**:
- Start simple
- No backend setup needed
- Privacy-first
- Can add cloud sync in Phase 3

### Decision 7: OpenAI Vision Integration (February 5, 2026)
**Chosen**: Replace VisionKit OCR with OpenAI GPT-4 Vision  
**Rationale**:
- VisionKit OCR was too weak (captured "COMANT" instead of "GARNIER FRUCTIS")
- OpenAI Vision provides **structured data extraction** (not just text)
- Built-in understanding of product context (brand, type, form, size)
- 95%+ accuracy out of the box
- Cost: ~$0.01 per scan (acceptable)
- 2-3 second response time (good UX)

### Decision 8: Name-Based Filtering + Typesense Ranking (February 5, 2026)
**Chosen**: Name matching as primary gate, Typesense position as secondary ranking  
**Rationale**:
- **Problem**: Typesense returned 23 products but included "nail gel polish" for "Hand Sanitizer"
- **Root cause**: `product_type` field in catalog is often wrong ("Other", "Gel/Gelly")
- **Solution**: 
  - **Gate**: Name must have 1+ matching words (filters garbage)
  - **Ranking**: Typesense position (70%) + Name quality (30%)
  - **Result**: Only relevant products shown, ranked by Typesense intelligence
- **Improvement**: Went from 3 results (too strict) to 20+ relevant results

### Decision 9: Broader Typesense Search (February 5, 2026)
**Chosen**: Increase `per_page` to 250, prioritize name/tags over product_type  
**Rationale**:
- User had 20+ hand sanitizers but only 3 were found
- **Problem**: Typesense query was too strict, relied on bad `product_type` metadata
- **Solution**:
  - Increased candidate retrieval: 50 → 250
  - Reweighted fields: name:10, tags:8, product_type:3 (trust name/tags more)
  - Enable prefix matching on all fields
- **Result**: Find ALL relevant products, let name filter and scoring handle quality

---

## 📚 QUICK REFERENCE

### File Locations
```
BlackScan/Scanning/
├── AdvancedClassifier.swift       - Main classification engine
├── ProductTaxonomy.swift          - 500 product types
├── FormTaxonomy.swift             - 11+ forms
├── BrandDatabase.swift            - 50+ brands
├── IngredientDatabase.swift       - 30+ ingredients
├── SizeExtractor.swift            - Size patterns
├── ConfidenceScorer.swift         - 6-tier scoring
└── ScanLogger.swift               - CoreData logging
```

### Key Algorithms
1. **Product Type Matching**: Exact → Synonym → Category → Keyword
2. **Form Matching**: Exact → Compatible → Generic → Incompatible
3. **Size Matching**: Exact → ±25% → ±50% → ±100%
4. **Final Score**: Σ(tier_score × tier_weight)

### Success Metrics
- **95%+ accuracy** on test set
- **< 1 second** scan-to-results
- **30% minimum** confidence threshold
- **20 results** shown to user

---

## 🎯 IMPLEMENTATION CHECKLIST

### Phase 1: Foundation
- [ ] ProductTaxonomy.swift - 2,229 types → 500 canonical
- [ ] FormTaxonomy.swift - 11 forms + inference rules
- [ ] BrandDatabase.swift - 50+ non-Black brands
- [ ] IngredientDatabase.swift - 30+ ingredients
- [ ] SizeExtractor.swift - Regex patterns

### Phase 2: Classification
- [ ] AdvancedClassifier.swift - 6-tier extraction
- [ ] ConfidenceScorer.swift - Weighted scoring

### Phase 3: Search
- [ ] TypesenseClient.swift - Weighted queries
- [ ] Models.swift - ScoredProduct model

### Phase 4: UI
- [ ] ScanView.swift - Confidence display
- [ ] CameraScanView.swift - Results card
- [ ] ScanLogger.swift - CoreData logging

### Phase 5: Testing
- [ ] Test suite (100+ cases)
- [ ] Iterate to 95%+ accuracy
- [ ] Performance optimization

---

**END OF MASTER REFERENCE**

This document serves as the complete technical reference for BlackScan's scanning system. All implementation decisions, algorithms, and logic flows are documented here for future reference and team onboarding.

**Version**: 2.1  
**Last Updated**: February 5, 2026  
**Author**: BlackScan Development Team

**Change Log**:
- **v2.1 (Feb 5)**: Refined scoring (name-based filtering + Typesense ranking), broader search, better button text
- **v2.0 (Feb 5)**: OpenAI GPT-4 Vision integration replaces VisionKit OCR
- **v1.0 (Feb 4)**: Initial 6-tier classification system with VisionKit
