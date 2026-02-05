#!/usr/bin/env python3
"""
Debug script to test lip balm classification
"""

import json
import re
from pathlib import Path

def normalize_text(text):
    """Normalize text for comparison"""
    return re.sub(r'\s+', ' ', str(text).strip().lower())

def map_product_type(name, description, categories, product_type_synonyms):
    """Map product name/description to canonical product_type"""
    text = f"{name} {description}".lower()
    
    print(f"Testing: '{text}'")
    
    # Direct matching against synonyms
    for synonym, canonical in product_type_synonyms.items():
        if synonym.lower() in text:
            print(f"  ✅ Found synonym '{synonym}' -> '{canonical}'")
            return canonical
    
    # Category-based fallback
    if categories:
        cat_text = str(categories).lower()
        print(f"Categories: '{cat_text}'")
        for synonym, canonical in product_type_synonyms.items():
            if synonym.lower() in cat_text:
                print(f"  ✅ Found category synonym '{synonym}' -> '{canonical}'")
                return canonical
    
    print(f"  ❌ No match found, returning 'Other'")
    return "Other"

def test_lip_balm_products():
    """Test lip balm product classification"""
    
    # Load synonyms
    with open("maps/product_type_synonyms.json") as f:
        product_type_synonyms = json.load(f)
    
    # Test cases from the actual data
    test_products = [
        {
            "name": "Remedy Conditioning Lip Balm",
            "description": "",
            "categories": []
        },
        {
            "name": "C Lip Serum SPF 30",
            "description": "",
            "categories": []
        },
        {
            "name": "Luxe Lip Balm (2-Pack)",
            "description": "",
            "categories": []
        },
        {
            "name": "Clear Coat Lip Balm SPF 15",
            "description": "Invisible Protection for Every Shade",
            "categories": []
        },
        {
            "name": "Shea Lip Balm",
            "description": "",
            "categories": []
        }
    ]
    
    print("Testing lip balm product classification:")
    print("=" * 50)
    
    for product in test_products:
        print(f"\nProduct: {product['name']}")
        result = map_product_type(
            product['name'], 
            product['description'], 
            product['categories'], 
            product_type_synonyms
        )
        print(f"Result: {result}")
        print("-" * 30)

if __name__ == "__main__":
    test_lip_balm_products()
