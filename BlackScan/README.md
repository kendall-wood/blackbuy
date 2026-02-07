# BlackScan - AI-Powered Product Scanner

A SwiftUI iOS app that scans any product label using GPT-4 Vision and finds Black-owned alternatives via Typesense search.

## Features

- **AI Scan**: Point camera at any product label — GPT-4 Vision identifies the product type, form, and ingredients, then finds matching Black-owned alternatives
- **Shop**: Browse by category, search products and brands, featured brands carousel
- **Cart**: Checkout manager with company-grouped items, quantity controls, and direct "Buy" links to store websites
- **Saved**: Save favorite products and companies for quick access
- **Profile**: Apple Sign In, data export (GDPR), full data deletion, privacy policy link
- **Offline Detection**: Network monitor with auto-dismissing offline banner
- **Scan History**: View and revisit previous scans

## Architecture

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 17+, light mode) |
| AI Vision | OpenAI GPT-4o via REST API |
| OCR Fallback | VisionKit + on-device hybrid scan pipeline |
| Search | Typesense Cloud (semantic + faceted search) |
| Auth | Apple Sign In (ASAuthorizationController) |
| Storage | Keychain (credentials), UserDefaults (cart, saved items, preferences) |
| Security | TLS 1.2+, input sanitization, image URL validation, network retry with backoff |
| Config | xcconfig-injected secrets via Info.plist |

## Project Structure

```
BlackScan/
├── BlackScanApp.swift                  # @main entry, environment objects, splash
├── MainTabView.swift                   # Tab-less navigation (scan, shop, saved, profile, checkout)
│
├── BlackScan/
│   ├── ScanView.swift                  # Camera UI, scan button states, results sheet
│   ├── ShopView.swift                  # Search, categories, featured products grid
│   ├── SavedView.swift                 # Saved products & companies
│   ├── ProfileView.swift               # Apple Sign In, settings, data export/deletion
│   ├── CheckoutManagerView.swift       # Cart grouped by company, quantity controls
│   ├── ProductDetailView.swift         # Product detail with similar products
│   ├── CompanyView.swift               # All products from a single company
│   ├── AllFeaturedProductsView.swift   # Full featured products listing
│   ├── CameraScanView.swift            # Legacy camera scanning view
│   ├── LaunchScreenView.swift          # Splash screen
│   ├── LiveScannerView.swift           # VisionKit DataScanner wrapper
│   │
│   ├── Models.swift                    # Product, TypesenseSearchResponse, etc.
│   ├── CartItem.swift                  # Cart item model
│   ├── Item.swift                      # Generic item model
│   ├── DesignSystem.swift              # DS tokens, AppTab, AppHeader, toast system
│   ├── ProductCard.swift               # UnifiedProductCard used across the app
│   ├── ImageCache.swift                # NSCache image cache + CachedAsyncImage view
│   │
│   ├── Env.swift                       # Environment config (Typesense, OpenAI, backend)
│   ├── TestEnv.swift                   # Startup validation for env vars
│   ├── TypesenseClient.swift           # Typesense search API client
│   ├── OpenAIVisionService.swift       # GPT-4 Vision product analysis
│   ├── Classifier.swift                # Rule-based fallback classifier
│   ├── ProductCacheManager.swift       # Pre-fetches featured products at launch
│   ├── CartManager.swift               # Cart state + UserDefaults persistence
│   ├── SavedProductsManager.swift      # Saved products persistence
│   ├── SavedCompaniesManager.swift     # Saved companies persistence
│   ├── ScanHistoryManager.swift        # Scan history persistence
│   ├── AppleAuthManager.swift          # Apple Sign In + Keychain credential storage
│   ├── UserAuthService.swift           # Anonymous user auth service
│   ├── FeedbackManager.swift           # Issue reporting to backend
│   │
│   ├── Scanning/                       # Hybrid scan pipeline
│   │   ├── HybridScanService.swift     # Orchestrates OCR vs Vision API
│   │   ├── AdvancedClassifier.swift    # Multi-signal product classification
│   │   ├── ConfidenceScorer.swift      # Scoring models (ScoredProduct, etc.)
│   │   ├── MultiFrameOCRService.swift  # On-device OCR aggregation
│   │   ├── GPT4TextService.swift       # GPT-4 text-only fallback
│   │   ├── ProductTaxonomy.swift       # Product type normalization + synonyms
│   │   ├── FormTaxonomy.swift          # Form normalization (gel, cream, etc.)
│   │   ├── BrandDatabase.swift         # Known brand lookups
│   │   ├── IngredientDatabase.swift    # Ingredient recognition
│   │   └── SizeExtractor.swift         # Size/volume parsing
│   │
│   ├── Security/                       # Security & validation
│   │   ├── InputValidator.swift        # Search/feedback sanitization, URL validation
│   │   ├── NetworkSecurity.swift       # Retry logic, secure URLSession config
│   │   ├── SecureStorage.swift         # Keychain wrapper
│   │   ├── NetworkMonitor.swift        # NWPathMonitor connectivity tracking
│   │   └── LogManager.swift            # Production-safe logging (stripped in Release)
│   │
│   ├── Info.plist                      # Env var placeholders for xcconfig injection
│   ├── BlackScan.entitlements          # Apple Sign In capability
│   ├── PrivacyInfo.xcprivacy           # Privacy manifest (required by App Store)
│   └── Assets.xcassets/                # App icons, images, colors
│
├── Configuration/
│   └── Secrets.xcconfig.template       # Template for API keys
│
├── BlackScanTests/
└── BlackScanUITests/
```

## Setup

### 1. Configure Secrets

```bash
cp Configuration/Secrets.xcconfig.template Configuration/Secrets.xcconfig
```

Edit `Secrets.xcconfig` with your values:

```
TYPESENSE_HOST = your-cluster.a1.typesense.net
TYPESENSE_API_KEY = your-search-only-api-key
OPENAI_API_KEY = sk-your-openai-key
BACKEND_URL = https://your-backend.com
```

The xcconfig file is git-ignored. Values are injected into Info.plist at build time.

### 2. Product Data

```bash
cd data-normalizer
python3 normalize.py    # Creates normalized_products.json from raw input
```

### 3. Import to Typesense

```bash
export TYPESENSE_HOST="https://your-cluster.a1.typesense.net"
export TYPESENSE_API_KEY="your-admin-api-key"

# Create collection
curl -X POST "${TYPESENSE_HOST}/collections" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d @infra/typesense_products_schema.json

# Import products
curl -X POST "${TYPESENSE_HOST}/collections/products/documents/import?action=upsert" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}" \
  -H "Content-Type: application/jsonl" \
  --data-binary @data-normalizer/normalized_products.json
```

### 4. Build & Run

- Open `BlackScan.xcodeproj` in Xcode
- Select a physical device (camera required for scanning)
- Build and run (Cmd+R)

## App Store Compliance

| Requirement | Status |
|-------------|--------|
| Privacy Manifest (`PrivacyInfo.xcprivacy`) | Declares collected data types, API reasons, no tracking |
| Camera Permission (`NSCameraUsageDescription`) | Clear purpose string in build settings |
| Account Deletion | Profile > Delete All My Data (clears Keychain, UserDefaults, all managers) |
| Data Export | Profile > Export My Data (JSON with all user data) |
| Apple Sign In Entitlement | Configured in `.entitlements` |
| No Private APIs | Public `UIScreen.main.displayCornerRadius` with fallback |
| Production Logging | Debug/info/warning stripped in Release; errors redacted |
| Secure Credential Storage | iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| Network Security | TLS 1.2 minimum, HTTPS-only image loading, input sanitization |

## Environment Variables

| Key | Description |
|-----|-------------|
| `TYPESENSE_HOST` | Typesense cluster URL |
| `TYPESENSE_API_KEY` | Search-only API key (not admin) |
| `OPENAI_API_KEY` | OpenAI API key for GPT-4 Vision |
| `BACKEND_URL` | Backend URL for feedback submissions |
