#!/usr/bin/env python3
"""
BlackScan Product Normalizer
Converts raw 87k+ product JSON into clean taxonomy for Typesense indexing.
"""

import json
import re
from collections import Counter
from pathlib import Path
import sys

# Load mapping files
def load_maps():
    """Load synonym and category mapping files"""
    maps_dir = Path(__file__).parent / "maps"
    
    with open(maps_dir / "main_category_map.json") as f:
        main_category_map = json.load(f)
    
    with open(maps_dir / "product_type_synonyms.json") as f:
        product_type_synonyms = json.load(f)
    
    return main_category_map, product_type_synonyms

def normalize_text(text):
    """Clean and normalize text for matching"""
    if not text:
        return ""
    # Convert to lowercase, remove extra spaces
    return re.sub(r'\s+', ' ', str(text).lower().strip())

def extract_form(name, description=""):
    """Extract product form (oil, cream, gel, etc.) from name/description"""
    text = f"{name} {description}".lower()
    
    forms = {
        'oil': ['oil', 'serum'],
        'cream': ['cream', 'lotion', 'butter'],
        'gel': ['gel', 'gelly'],
        'spray': ['spray', 'mist'],
        'foam': ['foam', 'mousse'],
        'bar': ['bar', 'soap bar'],
        'serum': ['serum'],
        'balm': ['balm'],
        'wax': ['wax', 'pomade'],
        'powder': ['powder'],
        'liquid': ['liquid', 'shampoo', 'conditioner']
    }
    
    for form, keywords in forms.items():
        if any(keyword in text for keyword in keywords):
            return form
    
    return "other"

def detect_set_bundle(name, description=""):
    """Detect if product is a kit/bundle or single item"""
    text = f"{name} {description}".lower()
    
    bundle_keywords = ['kit', 'set', 'bundle', 'pack', 'duo', 'trio', 'collection', 'system']
    
    if any(keyword in text for keyword in bundle_keywords):
        return "kit/bundle"
    
    return "single"

def map_main_category(categories, subcategories, main_category_map):
    """Map noisy categories to clean main_category"""
    # Combine all category info
    all_cats = []
    if categories:
        if isinstance(categories, list):
            all_cats.extend(categories)
        else:
            all_cats.append(categories)
    
    if subcategories:
        if isinstance(subcategories, list):
            all_cats.extend(subcategories)
        else:
            all_cats.append(subcategories)
    
    # Try to match against our map
    for cat in all_cats:
        cat_normalized = normalize_text(cat)
        for key, mapped in main_category_map.items():
            if key in cat_normalized:
                return mapped
    
    # Default fallback
    return "Other"

def map_product_type(name, description, categories, product_type_synonyms):
    """Map product name/description to canonical product_type"""
    text = f"{name} {description}".lower()
    
    # Direct matching against synonyms
    for synonym, canonical in product_type_synonyms.items():
        if synonym.lower() in text:
            return canonical
    
    # Category-based fallback
    if categories:
        cat_text = str(categories).lower()
        for synonym, canonical in product_type_synonyms.items():
            if synonym.lower() in cat_text:
                return canonical
    
    return "Other"

def extract_tags(name, description="", categories=None):
    """Extract searchable tags from product info"""
    tags = set()
    
    # Add descriptive words from name
    name_words = re.findall(r'\b\w+\b', name.lower())
    meaningful_words = [w for w in name_words if len(w) > 2 and w not in {'the', 'and', 'for', 'with'}]
    tags.update(meaningful_words[:5])  # Limit to avoid noise
    
    # Add category info
    if categories:
        if isinstance(categories, list):
            tags.update([normalize_text(c) for c in categories[:3]])
        else:
            tags.add(normalize_text(categories))
    
    return list(tags)

def normalize_product(product, main_category_map, product_type_synonyms):
    """Normalize a single product to clean schema"""
    
    # Extract basic fields (adjust these keys based on your actual JSON structure)
    # You'll need to adapt these field names to match your 87k product JSON
    name = product.get('name', product.get('title', ''))
    company = product.get('company', product.get('brand', product.get('vendor', '')))
    price = product.get('price', product.get('cost', 0))
    image_url = product.get('image_url', product.get('image', ''))
    product_url = product.get('product_url', product.get('url', ''))
    description = product.get('description', '')
    categories = product.get('categories', product.get('category', ''))
    subcategories = product.get('subcategories', '')
    
    # Apply taxonomy mapping
    main_category = map_main_category(categories, subcategories, main_category_map)
    product_type = map_product_type(name, description, categories, product_type_synonyms)
    form = extract_form(name, description)
    set_bundle = detect_set_bundle(name, description)
    tags = extract_tags(name, description, categories)
    
    # Generate clean ID
    product_id = product.get('id', f"product_{hash(name + str(company))}")
    
    return {
        "id": str(product_id),
        "name": name,
        "company": company,
        "price": price,
        "image_url": image_url,
        "product_url": product_url,
        "main_category": main_category,
        "product_type": product_type,
        "form": form,
        "set_bundle": set_bundle,
        "tags": tags,
        "_raw": product  # Keep original for debugging
    }

def main():
    # Check for input file
    input_file = Path("input_products.json")
    if not input_file.exists():
        print("❌ Error: input_products.json not found")
        print("   Please copy your 87k+ product JSON to data-normalizer/input_products.json")
        return
    
    # Load mapping files
    try:
        main_category_map, product_type_synonyms = load_maps()
        print(f"✅ Loaded {len(main_category_map)} category mappings")
        print(f"✅ Loaded {len(product_type_synonyms)} product type synonyms")
    except Exception as e:
        print(f"❌ Error loading maps: {e}")
        return
    
    # Load and process products
    print("📁 Loading products...")
    try:
        with open(input_file) as f:
            data = json.load(f)
            
        # Handle different JSON structures
        if isinstance(data, list):
            products = data
        elif isinstance(data, dict) and 'products' in data:
            products = data['products']
        else:
            products = [data]  # Single product
            
        print(f"📦 Found {len(products)} products")
        
        # Process first 1000 for testing
        sample_size = min(1000, len(products))
        print(f"🔬 Processing sample of {sample_size} products...")
        
        normalized_products = []
        stats = {
            'main_categories': Counter(),
            'product_types': Counter(),
            'forms': Counter(),
            'set_bundles': Counter(),
            'unknown_types': []
        }
        
        for i, product in enumerate(products[:sample_size]):
            try:
                normalized = normalize_product(product, main_category_map, product_type_synonyms)
                normalized_products.append(normalized)
                
                # Track stats
                stats['main_categories'][normalized['main_category']] += 1
                stats['product_types'][normalized['product_type']] += 1
                stats['forms'][normalized['form']] += 1
                stats['set_bundles'][normalized['set_bundle']] += 1
                
                # Track unknown types for future synonym expansion
                if normalized['product_type'] == 'Other':
                    stats['unknown_types'].append(normalized['name'][:50])
                    
            except Exception as e:
                print(f"⚠️  Error processing product {i}: {e}")
                continue
        
        # Save normalized output
        output_file = Path("normalized_products.json")
        with open(output_file, 'w') as f:
            for product in normalized_products:
                f.write(json.dumps(product) + '\n')  # JSONL format for Typesense
        
        print(f"✅ Saved {len(normalized_products)} normalized products to {output_file}")
        
        # Print report
        print("\n" + "="*50)
        print("📊 NORMALIZATION REPORT")
        print("="*50)
        
        print(f"\n📈 TOP MAIN CATEGORIES:")
        for category, count in stats['main_categories'].most_common(10):
            print(f"  {category}: {count}")
        
        print(f"\n🏷️  TOP PRODUCT TYPES:")
        for ptype, count in stats['product_types'].most_common(15):
            print(f"  {ptype}: {count}")
        
        print(f"\n🧴 PRODUCT FORMS:")
        for form, count in stats['forms'].most_common():
            print(f"  {form}: {count}")
            
        print(f"\n📦 SET/BUNDLE DISTRIBUTION:")
        for bundle, count in stats['set_bundles'].most_common():
            print(f"  {bundle}: {count}")
        
        if stats['unknown_types']:
            print(f"\n❓ UNKNOWN PRODUCT TYPES (first 10):")
            print("   (Consider adding these to product_type_synonyms.json)")
            for name in stats['unknown_types'][:10]:
                print(f"  • {name}")
        
        print(f"\n✨ Next steps:")
        print(f"   1. Review unknown types and update synonym maps")
        print(f"   2. Re-run on full dataset when ready")
        print(f"   3. Import to Typesense: normalized_products.json")
        
    except Exception as e:
        print(f"❌ Error processing products: {e}")
        return

if __name__ == "__main__":
    main()
