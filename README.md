# BlackScan

Scan any product. Find your Black-owned option.

A SwiftUI iOS app that uses GPT-4 Vision to identify products from camera scans and surfaces Black-owned alternatives via Typesense search.

## How It Works

1. **Scan** — Point your camera at any product label
2. **AI Analysis** — GPT-4 Vision identifies the product type, form, and ingredients
3. **Search** — Typesense finds matching Black-owned alternatives from 6,400+ products
4. **Discover** — Browse results, save favorites, add to cart, buy from the store

## Tech Stack

- **iOS App**: SwiftUI, iOS 17+, camera-first interface
- **AI**: OpenAI GPT-4o for product label analysis
- **Search**: Typesense Cloud with semantic matching
- **Auth**: Apple Sign In with Keychain credential storage
- **Data Pipeline**: Python normalizer (87k raw products to 6.4k curated catalog)

## Repository Structure

```
blackscan/
├── BlackScan/                  # Xcode project (see BlackScan/README.md for full details)
│   ├── BlackScanApp.swift      # App entry point
│   ├── MainTabView.swift       # Navigation controller
│   ├── BlackScan/              # Source files (views, models, services, security)
│   ├── Configuration/          # Secrets.xcconfig template
│   ├── BlackScanTests/
│   └── BlackScanUITests/
│
├── data-normalizer/            # Python pipeline for product data
│   ├── normalize.py            # Main normalizer script
│   └── maps/                   # Synonym and category mapping files
│
├── infra/                      # Typesense collection schema
│   └── typesense_products_schema.json
│
└── privacy-policy/             # Hosted privacy policy
```

## Quick Start

```bash
# 1. Configure secrets
cp BlackScan/Configuration/Secrets.xcconfig.template BlackScan/Configuration/Secrets.xcconfig
# Edit Secrets.xcconfig with your Typesense, OpenAI, and backend credentials

# 2. Normalize and import product data
cd data-normalizer
python3 normalize.py
# Import normalized_products.json to your Typesense cluster (see BlackScan/README.md)

# 3. Open in Xcode and build to a physical device
open BlackScan/BlackScan.xcodeproj
```

See [BlackScan/README.md](BlackScan/README.md) for detailed setup, architecture, and App Store compliance notes.
