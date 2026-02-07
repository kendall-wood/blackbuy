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
    # Remove HTML tags like <br>, <br/>, etc.
    text = re.sub(r'<[^>]+>', ' ', str(text))
    # Convert to lowercase, remove extra spaces
    return re.sub(r'\s+', ' ', text.lower().strip())

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
    
    # Try to match against our map using word-boundary matching
    # Sort keys longest-first so "men's care" matches before "men"
    sorted_keys = sorted(main_category_map.keys(), key=len, reverse=True)
    for cat in all_cats:
        cat_normalized = normalize_text(cat)
        for key in sorted_keys:
            # Use word boundary regex to prevent "men" matching inside "women", "supplement", etc.
            pattern = r'(?:^|[\s,;/\-])' + re.escape(key) + r'(?:$|[\s,;/\-])'
            if re.search(pattern, cat_normalized) or cat_normalized == key:
                return main_category_map[key]
    
    # Default fallback
    return "Other"

def map_product_type(name, description, categories, product_type_synonyms, existing_product_type=""):
    """Enhanced product type mapping with multiple fallback strategies"""
    
    # Strategy 1: Use existing product type if it's already classified and not empty
    if existing_product_type and existing_product_type.strip() and existing_product_type.strip() != "Other":
        return existing_product_type.strip()
    
    # Clean and prepare text for matching
    text = f"{name} {description}".lower()
    text = re.sub(r'[^\w\s]', ' ', text)  # Remove punctuation
    text = re.sub(r'\s+', ' ', text).strip()
    
    # Sort synonyms by length (longest first) to prioritize more specific matches
    sorted_synonyms = sorted(product_type_synonyms.items(), key=lambda x: len(x[0]), reverse=True)
    
    # Strategy 2: Exact word boundary matching (highest priority)
    for synonym, canonical in sorted_synonyms:
        pattern = r'\b' + re.escape(synonym.lower()) + r'\b'
        if re.search(pattern, text):
            return canonical
    
    # Strategy 3: Multi-word fuzzy matching
    text_words = set(text.split())
    for synonym, canonical in sorted_synonyms:
        synonym_words = set(synonym.lower().split())
        # If all synonym words are found in text (in any order)
        if synonym_words.issubset(text_words):
            return canonical
    
    # Strategy 4: Substring matching (lower priority)
    for synonym, canonical in sorted_synonyms:
        if synonym.lower() in text:
            return canonical
    
    # Strategy 5: Category-based fallback
    if categories:
        cat_text = str(categories).lower()
        cat_text = re.sub(r'[^\w\s]', ' ', cat_text)
        cat_text = re.sub(r'\s+', ' ', cat_text).strip()
        
        # Try exact word matching on categories
        for synonym, canonical in sorted_synonyms:
            pattern = r'\b' + re.escape(synonym.lower()) + r'\b'
            if re.search(pattern, cat_text):
                return canonical
        
        # Try substring matching on categories
        for synonym, canonical in sorted_synonyms:
            if synonym.lower() in cat_text:
                return canonical
    
    # Strategy 6: Smart keyword-based classification for common patterns
    smart_patterns = {
        r'\b(mask|masque)\b': 'Face Mask',
        r'\b(cream|creme)\b.*\b(hair|curl)\b': 'Hair Cream',
        r'\b(oil)\b.*\b(hair|scalp)\b': 'Hair Oil',
        r'\b(gel|gelly|custard)\b.*\b(hair|curl|style)\b': 'Hair Gel',
        r'\b(butter)\b.*\b(hair|curl|body)\b': 'Hair Butter',
        r'\b(brush)\b.*\b(hair|wave|style)\b': 'Hair Brush',
        r'\b(shampoo|cleanser)\b': 'Shampoo',
        r'\b(conditioner)\b': 'Conditioner',
        r'\bleave.?in\b': 'Leave-In Conditioner',
        r'\b(serum)\b.*\b(face|facial|skin)\b': 'Face Serum',
        r'\b(scrub)\b.*\b(face|facial)\b': 'Face Scrub',
        r'\b(scrub)\b.*\b(body)\b': 'Body Scrub',
        r'\b(moisturizer)\b.*\b(face|facial)\b': 'Face Moisturizer',
        r'\b(moisturizer|lotion)\b.*\b(body)\b': 'Body Butter',
        r'\b(cleanser)\b.*\b(face|facial)\b': 'Face Cleanser',
        r'\b(balm)\b.*\b(lip)\b': 'Lip Balm',
        r'\b(gloss)\b.*\b(lip)\b': 'Lip Gloss',
        r'\b(polish)\b.*\b(nail)\b': 'Nail Polish',
        r'\b(candle)\b': 'Scented Candle',
        r'\b(perfume|fragrance|cologne)\b': 'Perfume',
        r'\b(dress)\b': 'Dress',
        r'\b(bikini)\b': 'Bikini',
        r'\b(bag|handbag|purse)\b': 'Handbag',
        r'\b(soap)\b.*\b(bar)\b': 'Bar Soap',
        r'\b(vitamins|supplements)\b': 'Vitamins',
    }
    
    for pattern, product_type in smart_patterns.items():
        if re.search(pattern, text, re.IGNORECASE):
            return product_type
    
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

def _is_womens_care(name_and_type):
    """Return True if the product text indicates feminine hygiene / intimate care."""
    womens_care_kw = [
        'yoni', 'feminine wash', 'feminine hygiene', 'feminine deodorant',
        'feminine care', 'feminine spray', 'feminine oil', 'feminine foam',
        'feminine soothing', 'feminine skin', 'foaming feminine',
        'intimate wash', 'intimate spray', 'intimate oil', 'intimate gel',
        'intimate flora', 'vaginal', 'vagina', 'menstrual', 'period underwear',
        'period panty', 'reusable period', 'boric acid', 'v steam', 'vsteam',
        'womb detox', 'womb matter', 'yoni steam', 'yoni oil', 'yoni wash',
        'yoni egg', 'yoni toning', 'yoni elixir', 'yoni duo', 'kitty potion',
        'cookie wash', 'cookie oil', 'cookie restore', 'ph balance',
        'prenatal', 'postpartum', 'fertility supplement', 'ovulation',
        'menstrual cup', 'feminine hygiene bundle', 'yin trifecta',
    ]
    return any(kw in name_and_type for kw in womens_care_kw)


def refine_category(main_category, product, product_type):
    """Post-process category for complex splits that keyword matching can't handle."""
    name = product.get('Name', '').lower()
    raw_subcat1 = product.get('Subcategory 1', '').lower()
    raw_main_cat = product.get('Main Category', '').lower()
    raw_combined = f"{raw_main_cat} {raw_subcat1}".lower()
    pt_lower = product_type.lower() if product_type else ''
    raw_pt = product.get('Product Type', '').lower()
    name_and_type = f"{name} {pt_lower} {raw_pt}"

    # --- Women's Care FIRST: highest priority so feminine products are never
    #     swallowed by Clothing, Vitamins, or any other split ---
    if _is_womens_care(name_and_type):
        return "Women's Care"

    # --- Clothing -> Men's Clothing / Women's Clothing ---
    if main_category == "Clothing":
        # Check raw subcategories for gender
        # IMPORTANT: Check women's BEFORE men's because "men's" is a
        # substring of "women's" — checking mens first would misclassify.
        kids_indicators = ["girls' clothing", "baby", "toddler", "kids'", "pet supplies", "pet clothing", "pet apparel", "dog"]
        womens_indicators = ["women's", "female", "bridal", "lingerie"]
        
        if any(kw in raw_combined for kw in kids_indicators):
            return "Baby & Kids"
        elif any(kw in raw_combined for kw in womens_indicators):
            return "Women's Clothing"
        elif "men's" in raw_combined and "women's" not in raw_combined:
            # Catches men's apparel, men's accessories, men's clothing, etc.
            return "Men's Clothing"
        else:
            # Default ambiguous clothing (hats, unisex) to Women's Clothing
            return "Women's Clothing"

    # --- Health & Wellness -> Vitamins & Supplements or redistribute ---
    if main_category == "Health & Wellness":
        vitamin_kw = ['vitamin', 'supplement', 'protein', 'collagen', 'probiotic',
                       'gummies', 'gummy', 'creatine', 'elderberry', 'melatonin',
                       'testosterone', 'multivitamin', 'capsule', 'tablet',
                       'meal replacement', 'nutritional shake', 'weight gain',
                       'pre-workout', 'energy supplement', 'superfood',
                       'sea moss', 'herbal extract', 'herbal supplement']
        if any(kw in name_and_type for kw in vitamin_kw):
            return "Vitamins & Supplements"
        
        mens_kw = ['razor', 'beard', 'shav', 'grooming', 'shaver']
        if any(kw in name_and_type for kw in mens_kw):
            return "Men's Care"
        
        # Everything else (soap, bath, body, deodorant, toothbrush, etc.) -> Body Care
        return "Body Care"

    # --- Accessories -> Books & More or Home Care (batteries) ---
    if main_category == "Accessories":
        # Battery products -> Home Care
        if 'battery' in name_and_type or 'batteries' in name_and_type or 'charger pack' in name_and_type or 'battery charger' in name_and_type:
            if 'rechargeable' in name_and_type or 'battery' in name_and_type or 'charger' in name_and_type:
                return "Home Care"
        
        # Books & More
        books_kw = ['book', 'ebook', 'e-book', 'journal', 'planner', 'guide',
                     'workbook', 'coloring', 'print', 'painting', 'postcard',
                     'dice', 'play dough', 'affirmation cards', 'banner',
                     'pencil', 'crayon', 'paint brush', 'stationery',
                     'recipe book', 'digital download', 'digital workbook']
        if any(kw in name_and_type for kw in books_kw):
            return "Books & More"
        
        return "Accessories"

    return main_category


def infer_category_from_name(name, description, main_category_map):
    """Fallback: infer main_category from product name/description text"""
    text = normalize_text(f"{name} {description}")
    
    # Name-based signals — check multi-word keys first (longest first)
    sorted_keys = sorted(main_category_map.keys(), key=len, reverse=True)
    for key in sorted_keys:
        pattern = r'(?:^|[\s,;/\-])' + re.escape(key) + r'(?:$|[\s,;/\-\'s])'
        if re.search(pattern, text):
            return main_category_map[key]
    
    return "Other"


def normalize_product(product, main_category_map, product_type_synonyms):
    """Normalize a single product to clean schema"""
    
    # Extract basic fields from your current JSON structure
    name = product.get('Name', '')
    company = product.get('Company', '')
    
    # Clean HTML tags from name
    name = re.sub(r'<[^>]+>', ' ', name)
    name = re.sub(r'\s+', ' ', name.strip())
    price_str = product.get('Price', '0')
    # Convert price string to float
    try:
        price = float(price_str) if price_str else 0.0
    except (ValueError, TypeError):
        price = 0.0
    
    # Convert Nigerian Naira (NGN) prices to USD for known Nigerian sources
    NGN_SOURCES = {'nubanbeauty.com', 'yangabeauty.com'}
    NGN_TO_USD = 1 / 1500  # Approximate exchange rate
    source = product.get('Source', '')
    if source in NGN_SOURCES and price > 0:
        price = round(price * NGN_TO_USD, 2)
    
    image_url = product.get('Image URL', '')
    product_url = product.get('Link', '')
    description = ''  # Not in your current JSON
    
    # Categories from your JSON structure
    main_cat = product.get('Main Category', '')
    subcategory1 = product.get('Subcategory 1', '')
    subcategory2 = product.get('Subcategory 2', '')
    existing_product_type = product.get('Product Type', '')
    
    # Combine categories for processing
    categories = [main_cat, subcategory1, subcategory2, existing_product_type]
    categories = [c for c in categories if c]  # Remove empty strings
    subcategories = f"{subcategory1} {subcategory2}".strip()
    
    # Apply taxonomy mapping
    main_category = map_main_category(categories, subcategories, main_category_map)
    
    # If category mapping returned "Other", try to infer from product name
    if main_category == "Other":
        main_category = infer_category_from_name(name, description, main_category_map)
    
    product_type = map_product_type(name, description, categories, product_type_synonyms, existing_product_type)
    
    # Refine category with post-processing (clothing gender split, H&W dissolution, etc.)
    main_category = refine_category(main_category, product, product_type)
    
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
        "subcategory_2": subcategory2,  # Add subcategory 2 for filtering
        "_raw": product  # Keep original for debugging
    }

def main():
    # Check for input file
    input_file = Path("../combined_complete_and_classified_products.json")
    if not input_file.exists():
        print("❌ Error: ../combined_complete_and_classified_products.json not found")
        print("   Please ensure your complete product JSON is in the parent directory")
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
        
        # Process all products
        sample_size = len(products)
        print(f"🔬 Processing all {sample_size} products...")
        
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
        
        # Deduplicate: keep first occurrence of each product ID
        seen_ids = set()
        deduped_products = []
        for product in normalized_products:
            pid = product['id']
            if pid not in seen_ids:
                seen_ids.add(pid)
                deduped_products.append(product)
        
        dupes_removed = len(normalized_products) - len(deduped_products)
        if dupes_removed > 0:
            print(f"🔄 Removed {dupes_removed} duplicate products (by ID)")
            # Recompute stats after dedup
            stats['main_categories'] = Counter()
            stats['product_types'] = Counter()
            stats['forms'] = Counter()
            stats['set_bundles'] = Counter()
            for p in deduped_products:
                stats['main_categories'][p['main_category']] += 1
                stats['product_types'][p['product_type']] += 1
                stats['forms'][p['form']] += 1
                stats['set_bundles'][p['set_bundle']] += 1
        normalized_products = deduped_products
        
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
        
        print(f"\n📈 ALL MAIN CATEGORIES:")
        for category, count in stats['main_categories'].most_common():
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
