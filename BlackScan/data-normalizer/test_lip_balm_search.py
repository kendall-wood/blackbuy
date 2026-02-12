#!/usr/bin/env python3
"""
Test script to verify lip balm search is working in Typesense
"""

import requests

def test_lip_balm_search():
    """Test search for lip balm products"""
    import os
    
    # Read credentials from environment variables — never hardcode keys
    typesense_host = os.getenv('TYPESENSE_HOST', 'https://your-cluster.a1.typesense.net')
    typesense_key = os.getenv('TYPESENSE_API_KEY', '')
    if not typesense_key:
        print("Error: Set TYPESENSE_API_KEY environment variable")
        return
    
    url = f'https://{typesense_host}/collections/products/documents/search'
    headers = {'X-TYPESENSE-API-KEY': typesense_key}
    params = {
        'q': 'Lip Balm',
        'query_by': 'name,company,product_type,tags',
        'per_page': 10
    }

    response = requests.get(url, headers=headers, params=params)
    data = response.json()

    print(f'Search for "Lip Balm":')
    print(f'Found: {data.get("found", 0)} results')
    print()

    for hit in data.get('hits', [])[:10]:
        product = hit['document']
        print(f'• {product.get("name", "Unknown")} - {product.get("company", "Unknown")} (${product.get("price", "N/A")})')
        print(f'  Type: {product.get("product_type", "Unknown")}')
        print()

if __name__ == "__main__":
    test_lip_balm_search()
