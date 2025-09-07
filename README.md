# BlackScan MVP

A SwiftUI iOS app for scanning and discovering Black-owned products using camera OCR and search.

## Architecture

- **iOS App**: SwiftUI + VisionKit for camera scanning
- **Data Pipeline**: Python normalizer for 87k+ product taxonomy
- **Search Backend**: Typesense Cloud for fast product search
- **Focus**: Black-owned products with clean UX (tabs: Scan, Shop, Saved)

## Quick Start (10 Steps)

### 1. Setup Product Data
```bash
# Put your 87k+ product JSON file here:
cp /path/to/your/combined_complete_and_classified_products.json data-normalizer/input_products.json
```

### 2. Run Data Normalizer
```bash
cd data-normalizer
python3 normalize.py
```
This creates `normalized_products.json` with clean taxonomy.

### 3. Create Typesense Collection
```bash
# Set your environment variables
export TYPESENSE_HOST="https://your-cluster.a1.typesense.net"
export TYPESENSE_API_KEY="your-admin-api-key"

# Create collection with schema
curl -X POST "${TYPESENSE_HOST}/collections" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d @infra/typesense_products_schema.json

# Verify collection was created
curl -X GET "${TYPESENSE_HOST}/collections/products" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}"
```

### 4. Import Normalized Products
```bash
# Import products to Typesense (upsert mode)
curl -X POST "${TYPESENSE_HOST}/collections/products/documents/import?action=upsert" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}" \
  -H "Content-Type: application/jsonl" \
  --data-binary @data-normalizer/normalized_products.json

# Check import status
curl -X GET "${TYPESENSE_HOST}/collections/products/documents/search?q=*" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}"
```

### 5. Configure Xcode Environment
- Open `ios/BlackScan.xcodeproj` in Xcode
- Edit scheme → Environment Variables:
  - `TYPESENSE_HOST` = `your-cluster.a1.typesense.net`  
  - `TYPESENSE_API_KEY` = `your-search-api-key` (search-only, not admin)

### 6. Build on Physical Device
Camera scanning requires a physical iPhone (iOS 17+).

### 7. Test Scan Flow
- Open app → Scan tab
- Point camera at product text/barcode
- Bottom sheet should appear with Black-owned products

### 8. Test Shop Flow  
- Shop tab → search by brand or product type
- Grid of product cards with "Buy" links

### 9. Optimize (Optional)
```bash
# Update synonym maps and re-run normalizer
vim data-normalizer/maps/product_type_synonyms.json
python3 data-normalizer/normalize.py
# Re-import to Typesense
```

### 10. Next Features
- Saved persistence (UserDefaults → Supabase)
- Better ML classifier (rule-based → trained model)
- Authentication & user profiles

## Project Structure

```
blackscan/
├── ios/
│   ├── BlackScan.xcodeproj
│   └── BlackScan/
│       ├── BlackScanApp.swift      # TabView (Scan, Shop, Saved)
│       ├── Models.swift            # Product, TypesenseHit, etc.
│       ├── TypesenseClient.swift   # Search API client
│       ├── Env.swift              # Environment variables
│       ├── Classifier.swift       # OCR text → product type
│       ├── LiveScannerView.swift  # VisionKit camera scanner
│       ├── ScanView.swift         # Camera + bottom sheet results
│       ├── ProductCard.swift      # Reusable product card component
│       ├── ShopView.swift         # Search + grid results
│       └── SavedView.swift        # Saved items (placeholder)
├── data-normalizer/
│   ├── normalize.py              # Main normalizer script
│   ├── input_products.json       # Your 87k+ raw products (symlink/copy)
│   ├── normalized_products.json  # Clean output for Typesense
│   └── maps/
│       ├── product_type_synonyms.json
│       └── main_category_map.json
├── infra/
│   └── typesense_products_schema.json
├── .env.example                  # Template for environment variables
└── README.md
```

## Development Notes

- **Target**: iOS 17, SwiftUI, VisionKit + Vision for OCR
- **No heavy frameworks**: AsyncImage for now (Nuke later)
- **Small commits**: "feat(scanner): add LiveScannerView", etc.
- **UX from PRD**: Camera scan → classify → slide-up results; history; Shop with search & cards; consistent card design; external "Buy" links

## Environment Variables

Copy `.env.example` to `.env` and fill in your Typesense credentials:

```bash
TYPESENSE_HOST=your-cluster.a1.typesense.net
TYPESENSE_API_KEY=your-search-api-key
```

**Note**: Use search-only API key in the iOS app, not admin key.

## Typesense API Examples

### Collection Management
```bash
# List all collections
curl -X GET "${TYPESENSE_HOST}/collections" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}"

# Delete collection (if needed)
curl -X DELETE "${TYPESENSE_HOST}/collections/products" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}"

# Get collection stats
curl -X GET "${TYPESENSE_HOST}/stats.json" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}"
```

### Search Examples
```bash
# Search for "shampoo" products
curl -X GET "${TYPESENSE_HOST}/collections/products/documents/search" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}" \
  -G \
  -d "q=shampoo" \
  -d "query_by=name,product_type,company,tags" \
 \
  -d "facet_by=main_category,product_type,form,company" \
  -d "sort_by=price:asc"

# Filter by Hair Care category
curl -X GET "${TYPESENSE_HOST}/collections/products/documents/search" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}" \
  -G \
  -d "q=*" \
  -d "query_by=name,product_type,company,tags" \
  -d "filter_by=main_category:=Hair Care" \
  -d "per_page=20"

# Search with price range
curl -X GET "${TYPESENSE_HOST}/collections/products/documents/search" \
  -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}" \
  -G \
  -d "q=curl cream" \
  -d "query_by=name,product_type,tags" \
  -d "filter_by=price:[10..50]" \
  -d "sort_by=price:desc"
```
