#!/usr/bin/env python3
"""
Import normalized products to Typesense
"""

import json
import os
import sys
import requests
from pathlib import Path

def main():
    # Get Typesense credentials from environment
    typesense_host = os.getenv('TYPESENSE_HOST')
    typesense_api_key = os.getenv('TYPESENSE_API_KEY')
    
    if not typesense_host or not typesense_api_key:
        print("❌ Error: TYPESENSE_HOST and TYPESENSE_API_KEY environment variables must be set")
        print("\nUsage:")
        print("  export TYPESENSE_HOST='https://your-cluster.a1.typesense.net'")
        print("  export TYPESENSE_API_KEY='your-admin-api-key'")
        print("  python3 import_to_typesense.py")
        sys.exit(1)
    
    # Ensure host has https://
    if not typesense_host.startswith('http'):
        typesense_host = f'https://{typesense_host}'
    
    collection_name = 'products'
    
    print(f"🔗 Typesense Host: {typesense_host}")
    print(f"📦 Collection: {collection_name}")
    
    # Load normalized products
    products_file = Path('normalized_products.json')
    if not products_file.exists():
        print(f"❌ Error: {products_file} not found")
        print("   Run normalize.py first to generate this file")
        sys.exit(1)
    
    print(f"📁 Loading products from {products_file}...")
    products = []
    with open(products_file) as f:
        for line in f:
            if line.strip():
                product = json.loads(line)
                # Remove _raw field before importing
                if '_raw' in product:
                    del product['_raw']
                products.append(product)
    
    print(f"✅ Loaded {len(products)} products")
    
    # Delete existing collection (if exists)
    print(f"\n🗑️  Deleting existing collection...")
    delete_url = f"{typesense_host}/collections/{collection_name}"
    headers = {'X-TYPESENSE-API-KEY': typesense_api_key}
    
    response = requests.delete(delete_url, headers=headers)
    if response.status_code == 200:
        print("✅ Deleted existing collection")
    elif response.status_code == 404:
        print("ℹ️  Collection doesn't exist yet")
    else:
        print(f"⚠️  Warning: {response.status_code} - {response.text}")
    
    # Create collection schema
    print(f"\n📝 Creating collection schema...")
    schema = {
        "name": collection_name,
        "fields": [
            {"name": "name", "type": "string"},
            {"name": "company", "type": "string", "facet": True},
            {"name": "price", "type": "float", "facet": True},
            {"name": "image_url", "type": "string"},
            {"name": "product_url", "type": "string"},
            {"name": "main_category", "type": "string", "facet": True},
            {"name": "product_type", "type": "string", "facet": True},
            {"name": "form", "type": "string", "facet": True, "optional": True},
            {"name": "set_bundle", "type": "string", "facet": True, "optional": True},
            {"name": "tags", "type": "string[]", "facet": True, "optional": True}
        ],
        "default_sorting_field": "price"
    }
    
    create_url = f"{typesense_host}/collections"
    response = requests.post(create_url, json=schema, headers=headers)
    
    if response.status_code == 201:
        print("✅ Collection schema created")
    else:
        print(f"❌ Error creating schema: {response.status_code}")
        print(response.text)
        sys.exit(1)
    
    # Import products
    print(f"\n📤 Importing {len(products)} products...")
    import_url = f"{typesense_host}/collections/{collection_name}/documents/import"
    headers['Content-Type'] = 'text/plain'
    
    # Convert to JSONL format
    jsonl_data = '\n'.join([json.dumps(p) for p in products])
    
    response = requests.post(import_url, data=jsonl_data, headers=headers)
    
    if response.status_code == 200:
        # Parse import results
        results = [json.loads(line) for line in response.text.strip().split('\n') if line.strip()]
        successes = sum(1 for r in results if r.get('success'))
        failures = len(results) - successes
        
        print(f"✅ Import complete!")
        print(f"   ✓ Successful: {successes}")
        if failures > 0:
            print(f"   ✗ Failed: {failures}")
            print("\n   First 5 failures:")
            for i, result in enumerate([r for r in results if not r.get('success')][:5]):
                print(f"     {i+1}. {result.get('error', 'Unknown error')}")
    else:
        print(f"❌ Error importing: {response.status_code}")
        print(response.text[:500])
        sys.exit(1)
    
    print("\n" + "="*50)
    print("✨ IMPORT COMPLETE!")
    print("="*50)
    print(f"\nYour BlackScan app should now show correct prices!")
    print(f"Test by running the iOS app and navigating to the Shop.")

if __name__ == "__main__":
    main()
