# Hybrid Scan System - Cost Optimization Strategy

**Date**: February 5, 2026  
**Status**: Infrastructure Complete, OCR Implementation Pending  
**Expected Savings**: 70-90% reduction in API costs

---

## 🎯 **What We Built**

A smart hybrid scanning system that chooses between:

### **Option 1: Cheap Path** (~$0.001 per scan)
```
1. Capture 3 frames rapidly (0.5s apart)
2. Extract text with VisionKit OCR (free, local)
3. Merge and quality-check text
4. Send to GPT-4 Text API (cheap!)
5. Return structured data
```

### **Option 2: Expensive Path** (~$0.01 per scan)
```
1. Capture single frame
2. Send to GPT-4 Vision API
3. Return structured data
```

**The system automatically chooses the best option based on quality!**

---

## 📊 **Expected Cost Savings**

| Scenario | Current | With Hybrid | Savings |
|----------|---------|-------------|---------|
| **100 scans** | $1-2 | $0.30 | **$1.70** 💰 |
| **1,000 scans** | $10-20 | $3 | **$17** 💰 |
| **10,000 scans** | $100-200 | $30 | **$170** 💰 |

**Average: 70-90% cost reduction!**

---

## 🔬 **How It Works**

### **Step 1: Multi-Frame OCR**
```swift
// Capture 3 frames to get complete text
Frame 1: "PURELL ADVANCED"
Frame 2: "HAND SANITIZER GEL"
Frame 3: "2 FL OZ (59 ML)"

→ Merged: "PURELL ADVANCED HAND SANITIZER GEL 2 FL OZ (59 ML)"
```

### **Step 2: Quality Scoring**
```swift
Quality Score = base 100%
- Text length < 30 chars: -30%
- No product keywords: -20%
- Has brand name: +10%
- Has size units: +10%

Example:
"PURELL HAND SANITIZER GEL 2 FL OZ"
→ Length: 35 chars ✅
→ Keywords: sanitizer, gel ✅
→ Brand: Purell ✅
→ Size: FL OZ ✅
→ Quality: 100% ✅ → Use cheap API!
```

### **Step 3: Smart Decision**
```
IF quality >= 70% AND words >= 5:
    → Try GPT-4 Text API ($0.001)
    
    IF GPT confidence >= 70%:
        ✅ SUCCESS - return results
        💰 Saved $0.009!
    ELSE:
        ⚠️ Low confidence → fallback to Vision
ELSE:
    ⚠️ Poor OCR → use Vision directly
```

---

## 🛡️ **Accuracy Safeguards**

### **1. Multi-Frame Aggregation**
- ✅ Capture 3 frames instead of 1
- ✅ Merge results (catches what individual frames miss)
- ✅ Deduplicate text
- ✅ More complete capture

### **2. Quality Scoring**
- ✅ Check text length (longer = more complete)
- ✅ Check for product keywords (gel, spray, sanitizer, etc.)
- ✅ Check for brand names (Dove, Garnier, Purell, etc.)
- ✅ Check for size units (oz, ml, fl)
- ✅ Reject if score < 70%

### **3. Confidence Gating**
- ✅ GPT must be 70%+ confident in parsing
- ✅ Auto-fallback if unsure
- ✅ Worst case = Vision API (expensive but accurate)

### **4. Smart Prompting**
- ✅ Tell GPT that OCR may have errors
- ✅ Ask it to infer from context
- ✅ Provide common brand names
- ✅ Handle spelling corrections

---

## 📁 **New Files Created**

### **1. MultiFrameOCRService.swift**
```swift
// Captures 3 frames and aggregates OCR results
// Quality scoring and decision logic
// Returns: text, confidence, quality score
```

### **2. GPT4TextService.swift**
```swift
// Analyzes OCR text via GPT-4 Text API
// Cost: $0.001 per scan (10x cheaper!)
// Handles OCR errors intelligently
```

### **3. HybridScanService.swift**
```swift
// Coordinator between OCR+Text and Vision
// Smart fallback logic
// Cost tracking and logging
```

---

## 🚧 **Current Status**

### ✅ **Completed**
- Infrastructure architecture
- Service classes created
- Quality scoring logic
- Cost tracking
- Fallback system
- ScanView integration

### 🚧 **TODO (Next Steps)**
1. **Implement actual OCR** in `MultiFrameOCRService.swift`
   - Use Apple's Vision framework
   - Text recognition API
   - Confidence scores

2. **Multi-frame camera capture**
   - Capture 3 frames automatically
   - 0.5s apart
   - Pass all 3 to OCR service

3. **Test and tune thresholds**
   - Quality score gate (currently 70%)
   - Confidence gate (currently 70%)
   - Measure actual cost savings

### 🔄 **Currently**
- System uses Vision API for everything (expensive)
- Infrastructure ready for OCR implementation
- No breaking changes
- Transparent fallback

---

## 🧪 **Testing Plan**

### **Phase 1: Implement OCR**
1. Add Vision framework text recognition
2. Test on 10 products
3. Compare OCR vs Vision accuracy

### **Phase 2: Tune Thresholds**
1. Try different quality gates (60%, 70%, 80%)
2. Measure accuracy vs cost
3. Find optimal balance

### **Phase 3: Production Testing**
1. Test with 100 scans
2. Measure:
   - % using cheap API
   - % using Vision fallback
   - Average cost per scan
   - Accuracy maintained

---

## 💡 **Expected Results**

### **Accuracy**
- **Target**: 90-95% (vs 95-98% with pure Vision)
- **Method**: Multi-frame OCR + smart fallback
- **Worst case**: Auto-fallback to Vision (same as before)

### **Cost**
- **Target**: $0.002-0.003 average per scan
- **Breakdown**: 80% cheap ($0.001), 20% Vision ($0.01)
- **Savings**: 70-80% reduction

### **Speed**
- **OCR path**: ~1.5 seconds
- **Vision path**: ~2.5 seconds
- **Average**: ~1.8 seconds (similar to before)

---

## 🎯 **Why This Approach?**

### **Advantages**
✅ **Huge cost savings** (70-90%)  
✅ **Maintains accuracy** (auto-fallback)  
✅ **Faster** (no image upload for 80% of scans)  
✅ **Works offline** (OCR is local)  
✅ **Smart fallback** (expensive when needed)  

### **Risks (Mitigated)**
⚠️ OCR might miss text → Multi-frame capture  
⚠️ OCR errors → Quality scoring + fallback  
⚠️ GPT misparses → Confidence gating + fallback  
⚠️ Complex labels → Auto-fallback to Vision  

---

## 📈 **Next Implementation Session**

When ready to implement the actual OCR:

1. Open `MultiFrameOCRService.swift`
2. Replace `extractText()` placeholder with Vision framework code
3. Test with real product images
4. Tune quality thresholds
5. Measure cost savings

**Infrastructure is ready - just need the OCR implementation!**

---

## 🔗 **Related Files**

- `BlackScan/Scanning/HybridScanService.swift` - Main coordinator
- `BlackScan/Scanning/MultiFrameOCRService.swift` - OCR capture & quality
- `BlackScan/Scanning/GPT4TextService.swift` - Cheap text parsing
- `BlackScan/OpenAIVisionService.swift` - Expensive fallback
- `BlackScan/ScanView.swift` - UI integration

---

**Status**: Ready for OCR implementation when you want to reduce costs by 70-90%! 🚀
