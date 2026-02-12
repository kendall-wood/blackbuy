# Import Fixed Products to Typesense

## Problem Fixed
✅ The normalize.py script was extracting prices incorrectly (all showed as 0)
✅ Fixed to handle capitalized field names ("Price" vs "price")
✅ All 6,404 products now have correct prices in normalized_products.json

## Next Step: Reimport to Typesense

You need to reimport the fixed data to Typesense using your ADMIN API key.

### Option 1: Use the Import Script

```bash
cd /Users/kendallwood/Desktop/byme/blackscan/data-normalizer

# Set your Typesense credentials (use ADMIN key, not search key)
export TYPESENSE_HOST='https://your-cluster.a1.typesense.net'
export TYPESENSE_API_KEY='your-admin-api-key-here'

# Install requests if needed
pip3 install requests

# Run the import
python3 import_to_typesense.py
```

### Option 2: Manual Import via Typesense Dashboard

1. Go to your Typesense Cloud dashboard
2. Delete the existing `products` collection
3. Create a new collection with the schema from `infra/typesense_products_schema.json`
4. Import `normalized_products.json` using the dashboard's import tool

### After Import

Run your BlackScan iOS app and navigate to the Shop - all products should now show real prices instead of "Price varies"!

## What Was Changed

### normalize.py
- Line 135-152: Updated field extraction to handle capitalized JSON keys
- Line 137-144: Added proper price parsing (handles both string and number formats)
- Line 201: Changed to process ALL products instead of just first 1000

### Files Generated
- `normalized_products.json` - All 6,404 products with correct prices
- `import_to_typesense.py` - Script to reimport data to Typesense
