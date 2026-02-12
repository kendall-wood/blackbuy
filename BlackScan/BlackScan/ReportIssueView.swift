import SwiftUI

/// Hierarchical report-an-issue view presented as a sheet.
/// Design mirrors ProfileView / CheckoutManagerView patterns:
/// white cards with stroke shadows, icon rows, DS typography, pill buttons.
struct ReportIssueView: View {
    
    /// The current tab when the user triggered the report (auto-selects the page).
    let currentTab: AppTab
    
    /// Optional product context — auto-filled when reporting from ProductDetailView.
    let product: Product?
    
    init(currentTab: AppTab, product: Product? = nil) {
        self.currentTab = currentTab
        self.product = product
    }
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AppleAuthManager
    @StateObject private var feedbackManager = FeedbackManager()
    
    // MARK: - Navigation State
    
    @State private var selectedPage: FeedbackManager.ReportPage? = nil
    @State private var selectedCategory: FeedbackManager.ReportCategory? = nil
    @State private var selectedSubCategory: FeedbackManager.ReportSubCategory? = nil
    @State private var selectedDetail: FeedbackManager.ReportDetail? = nil
    @State private var userNotes: String = ""
    @State private var showSubmitConfirmation = false
    @State private var submitError: String? = nil
    @State private var step: ReportStep = .page
    @State private var selectedReportedCategory: String? = nil
    
    enum ReportStep: Int, Comparable {
        case page = 0
        case category = 1
        case subCategory = 2
        case detail = 3
        case notes = 4
        
        static func < (lhs: ReportStep, rhs: ReportStep) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header — matches AppHeader style but with Cancel instead of back on first step
            header
            
            // Page Title
            Text("Report Issue")
                .font(DS.pageTitle)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.top, 24)
                .padding(.bottom, 8)
            
            // Breadcrumb trail
            breadcrumb
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.bottom, 16)
            
            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DS.sectionSpacing) {
                    switch step {
                    case .page:
                        pageSelectionSection
                    case .category:
                        categorySelectionSection
                    case .subCategory:
                        subCategorySelectionSection
                    case .detail:
                        detailSelectionSection
                    case .notes:
                        notesAndSubmitSection
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(DS.cardBackground)
        .onAppear {
            selectedPage = FeedbackManager.ReportPage.from(tab: currentTab)
        }
        .alert("Report Submitted", isPresented: $showSubmitConfirmation) {
            Button("Done") { dismiss() }
        } message: {
            Text("Thank you for your report. We'll look into this.")
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            // Leading: Back or Cancel
            if step > .page {
                AppBackButton(action: goBack)
            } else {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DS.brandBlue)
                }
                .buttonStyle(.plain)
                .frame(width: 60, height: 44, alignment: .leading)
            }
            
            Spacer()
            
            // Center: logo
            Image("shop_logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 28)
                .foregroundColor(DS.brandBlue)
                .offset(y: 3)
            
            Spacer()
            
            // Trailing: invisible spacer for balance
            Color.clear
                .frame(width: 60, height: 44)
        }
        .frame(height: DS.headerHeight)
        .padding(.horizontal, DS.horizontalPadding)
        .padding(.top, 10)
        .background(DS.cardBackground)
    }
    
    // MARK: - Breadcrumb
    
    private var breadcrumb: some View {
        HStack(spacing: 6) {
            if let page = selectedPage {
                breadcrumbChip(page.rawValue, isActive: step == .page)
            }
            if let category = selectedCategory, step >= .category {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
                breadcrumbChip(category.rawValue, isActive: step == .category)
            }
            if selectedCategory == .categoriesIssue, let catName = selectedReportedCategory, step >= .subCategory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
                breadcrumbChip(catName, isActive: step == .subCategory)
            } else if let sub = selectedSubCategory, step >= .subCategory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
                breadcrumbChip(sub.rawValue, isActive: step == .subCategory)
            }
            if let detail = selectedDetail, step >= .detail {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
                breadcrumbChip(detail.rawValue, isActive: step == .detail)
            }
            Spacer()
        }
    }
    
    private func breadcrumbChip(_ text: String, isActive: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
            .foregroundColor(DS.brandBlue)
            .lineLimit(1)
    }
    
    // MARK: - Page Selection
    
    private var pageSelectionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What page is the issue on?")
                .font(DS.sectionHeader)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
            
            // Card with grouped rows
            VStack(spacing: 0) {
                ForEach(Array(FeedbackManager.ReportPage.allCases.enumerated()), id: \.element.id) { index, page in
                    Button(action: {
                        selectedPage = page
                        selectedCategory = nil
                        selectedSubCategory = nil
                        selectedDetail = nil
                        withAnimation(.easeInOut(duration: 0.2)) {
                            step = .category
                        }
                    }) {
                        pageRow(page: page)
                    }
                    .buttonStyle(.plain)
                    
                    // Divider between rows (not after last)
                    if index < FeedbackManager.ReportPage.allCases.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.radiusLarge)
                    .fill(Color.white)
            )
            .dsCardShadow(cornerRadius: DS.radiusLarge)
            .padding(.horizontal, DS.horizontalPadding)
        }
    }
    
    private func pageRow(page: FeedbackManager.ReportPage) -> some View {
        HStack(spacing: 14) {
            // Icon in tinted rounded rect — matches ProfileView settingsRow
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DS.brandBlue.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                if let sfSymbol = page.sfSymbol {
                    Image(systemName: sfSymbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DS.brandBlue)
                } else if let asset = page.customImageAsset {
                    Image(asset)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(DS.brandBlue)
                }
            }
            
            Text(page.rawValue)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.black)
            
            Spacer()
            
            // Checkmark if currently selected
            if selectedPage == page {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.brandBlue)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
    }
    
    // MARK: - Category Selection
    
    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let page = selectedPage {
                Text("What type of issue?")
                    .font(DS.sectionHeader)
                    .foregroundColor(.black)
                    .padding(.horizontal, DS.horizontalPadding)
                
                // Product guidance hint — shown above table when product issue selected without product context
                if isProductRelatedIssue && product == nil {
                    productGuidanceHint
                }
                
                VStack(spacing: 0) {
                    let categories = page.categories
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        Button(action: {
                            selectedCategory = category
                            selectedSubCategory = nil
                            selectedDetail = nil
                            selectedReportedCategory = nil
                            
                            if category == .categoriesIssue {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    step = .subCategory
                                }
                            } else if let subs = category.subCategories, !subs.isEmpty {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    step = .subCategory
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    step = .notes
                                }
                            }
                        }) {
                            issueRow(
                                title: category.rawValue,
                                hasChevron: category == .categoriesIssue || category.subCategories != nil
                            )
                        }
                        .buttonStyle(.plain)
                        
                        if index < categories.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusLarge)
                        .fill(Color.white)
                )
                .dsCardShadow(cornerRadius: DS.radiusLarge)
                .padding(.horizontal, DS.horizontalPadding)
            }
        }
    }
    
    // MARK: - Sub-Category Selection
    
    private var subCategorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if selectedCategory == .categoriesIssue {
                categoryPickerSection
            } else if let subs = selectedCategory?.subCategories {
                Text("More specifically?")
                    .font(DS.sectionHeader)
                    .foregroundColor(.black)
                    .padding(.horizontal, DS.horizontalPadding)
                
                // Product guidance hint above table on sub-category step
                if isProductRelatedIssue && product == nil {
                    productGuidanceHint
                }
                
                VStack(spacing: 0) {
                    ForEach(Array(subs.enumerated()), id: \.element.id) { index, sub in
                        Button(action: {
                            selectedSubCategory = sub
                            selectedDetail = nil
                            
                            if let details = sub.details, !details.isEmpty {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    step = .detail
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    step = .notes
                                }
                            }
                        }) {
                            issueRow(
                                title: sub.rawValue,
                                hasChevron: sub.details != nil
                            )
                        }
                        .buttonStyle(.plain)
                        
                        if index < subs.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusLarge)
                        .fill(Color.white)
                )
                .dsCardShadow(cornerRadius: DS.radiusLarge)
                .padding(.horizontal, DS.horizontalPadding)
            }
        }
    }
    
    // MARK: - Category Picker (for Categories Issue)
    
    private let shopCategories = [
        "Hair Care",
        "Skincare",
        "Body Care",
        "Makeup",
        "Fragrance",
        "Women's Care",
        "Men's Care",
        "Women's Clothing",
        "Men's Clothing",
        "Vitamins & Supplements",
        "Home Care",
        "Books & More",
        "Accessories",
        "Baby & Kids"
    ]
    
    private func shopCategoryIcon(for category: String) -> String {
        switch category {
        case "Hair Care":                return "comb"
        case "Skincare":                 return "drop"
        case "Body Care":               return "hands.and.sparkles"
        case "Makeup":                   return "wand.and.stars"
        case "Fragrance":               return "aqi.medium"
        case "Women's Care":            return "♀"
        case "Men's Care":              return "♂"
        case "Women's Clothing":        return "icon_dress"
        case "Men's Clothing":          return "tshirt"
        case "Vitamins & Supplements":  return "pill"
        case "Home Care":               return "house"
        case "Books & More":            return "book"
        case "Accessories":             return "watch.analog"
        case "Baby & Kids":             return "stroller"
        default:                         return "tag"
        }
    }
    
    private var categoryPickerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Which category?")
                .font(DS.sectionHeader)
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(shopCategories, id: \.self) { category in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedReportedCategory = category
                                step = .notes
                            }
                        }) {
                            HStack(spacing: 6) {
                                let icon = shopCategoryIcon(for: category)
                                let isUnicode = icon.unicodeScalars.first.map { !$0.isASCII } ?? false
                                let isAsset = icon.hasPrefix("icon_")
                                if isUnicode {
                                    Text(icon)
                                        .font(.system(size: 14))
                                } else if isAsset {
                                    Image(icon)
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: icon)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                Text(category)
                                    .font(.system(size: 15, weight: selectedReportedCategory == category ? .semibold : .medium))
                            }
                            .foregroundColor(DS.brandBlue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(DS.radiusMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.radiusMedium)
                                    .stroke(selectedReportedCategory == category ? DS.brandBlue : DS.strokeColor, lineWidth: selectedReportedCategory == category ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 14)
            }
            .contentMargins(.horizontal, DS.horizontalPadding, for: .scrollContent)
        }
    }
    
    // MARK: - Detail Selection
    
    private var detailSelectionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let details = selectedSubCategory?.details {
                Text("What's the issue?")
                    .font(DS.sectionHeader)
                    .foregroundColor(.black)
                    .padding(.horizontal, DS.horizontalPadding)
                
                VStack(spacing: 0) {
                    ForEach(Array(details.enumerated()), id: \.element.id) { index, detail in
                        Button(action: {
                            selectedDetail = detail
                            withAnimation(.easeInOut(duration: 0.2)) {
                                step = .notes
                            }
                        }) {
                            issueRow(title: detail.rawValue, hasChevron: false)
                        }
                        .buttonStyle(.plain)
                        
                        if index < details.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusLarge)
                        .fill(Color.white)
                )
                .dsCardShadow(cornerRadius: DS.radiusLarge)
                .padding(.horizontal, DS.horizontalPadding)
            }
        }
    }
    
    // MARK: - Notes + Submit
    
    private var notesAndSubmitSection: some View {
        VStack(alignment: .leading, spacing: DS.sectionSpacing) {
            // Product guidance hint — shown above summary when product issue selected without product context
            if isProductRelatedIssue && product == nil {
                productGuidanceHint
            }
            
            // Summary card
            VStack(alignment: .leading, spacing: 12) {
                Text("REPORT SUMMARY")
                    .font(DS.label)
                    .tracking(DS.labelTracking)
                    .foregroundColor(Color(.systemGray))
                    .padding(.horizontal, DS.horizontalPadding)
                
                VStack(spacing: 0) {
                    summaryRow("Page", value: selectedPage?.rawValue ?? "—")
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    summaryRow("Issue", value: selectedCategory?.rawValue ?? "—")
                    
                    if selectedCategory == .categoriesIssue, let catName = selectedReportedCategory {
                        Divider()
                            .padding(.leading, 16)
                        summaryRow("Category", value: catName)
                    }
                    
                    if let sub = selectedSubCategory {
                        Divider()
                            .padding(.leading, 16)
                        summaryRow("Type", value: sub.rawValue)
                    }
                    
                    if let detail = selectedDetail {
                        Divider()
                            .padding(.leading, 16)
                        summaryRow("Detail", value: detail.rawValue)
                    }
                    
                    // Product context — show product name if attached
                    if let product = product, isProductRelatedIssue {
                        Divider()
                            .padding(.leading, 16)
                        summaryRow("Product", value: product.name)
                        
                        Divider()
                            .padding(.leading, 16)
                        summaryRow("Brand", value: product.company)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusLarge)
                        .fill(Color.white)
                )
                .dsCardShadow(cornerRadius: DS.radiusLarge)
                .padding(.horizontal, DS.horizontalPadding)
            }
            
            // Notes field
            VStack(alignment: .leading, spacing: 8) {
                Text("Additional details (optional)")
                    .font(DS.caption)
                    .foregroundColor(Color(.systemGray))
                    .padding(.horizontal, DS.horizontalPadding)
                
                TextEditor(text: $userNotes)
                    .font(DS.body)
                    .foregroundColor(.black)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100, maxHeight: 160)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: DS.radiusMedium)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.radiusMedium)
                            .stroke(DS.strokeColor, lineWidth: 1)
                    )
                    .padding(.horizontal, DS.horizontalPadding)
            }
            
            // Error message
            if let error = submitError {
                Text(error)
                    .font(DS.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, DS.horizontalPadding)
            }
            
            // Submit button — white background, blue text, stroke border
            Button(action: submitReport) {
                HStack(spacing: 8) {
                    if feedbackManager.isSubmitting {
                        ProgressView()
                            .tint(DS.brandBlue)
                    } else {
                        Text("Submit Report")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundColor(DS.brandBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(DS.radiusPill)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusPill)
                        .stroke(DS.strokeColor, lineWidth: 1)
                )
            }
            .buttonStyle(DSButtonStyle())
            .disabled(feedbackManager.isSubmitting)
            .padding(.horizontal, DS.horizontalPadding)
        }
    }
    
    // MARK: - Reusable Row Components
    
    /// Standard issue row — matches settingsRow pattern from ProfileView
    private func issueRow(title: String, hasChevron: Bool) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.black)
            
            Spacer()
            
            if hasChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }
    
    /// Summary row for the report summary card
    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DS.caption)
                .foregroundColor(Color(.systemGray))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    /// Whether the selected category is product-related (to show product context or hint).
    private var isProductRelatedIssue: Bool {
        selectedCategory == .productIssue
    }
    
    /// Reusable hint prompting the user to navigate to the product before reporting.
    private var productGuidanceHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(DS.brandBlue)
            
            Text("To report a specific product, open the product and report from there.")
                .font(DS.caption)
                .foregroundColor(Color(.systemGray))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DS.radiusMedium)
                .fill(DS.brandBlue.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusMedium)
                .stroke(DS.brandBlue.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, DS.horizontalPadding)
    }
    
    // MARK: - Navigation
    
    private func goBack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch step {
            case .page:
                break
            case .category:
                step = .page
            case .subCategory:
                selectedSubCategory = nil
                selectedReportedCategory = nil
                step = .category
            case .detail:
                selectedDetail = nil
                step = .subCategory
            case .notes:
                if selectedDetail != nil {
                    selectedDetail = nil
                    step = .detail
                } else if selectedCategory == .categoriesIssue {
                    selectedReportedCategory = nil
                    step = .subCategory
                } else if selectedSubCategory != nil {
                    selectedSubCategory = nil
                    step = .subCategory
                } else {
                    step = .category
                }
            }
        }
    }
    
    // MARK: - Submit
    
    private func submitReport() {
        guard let page = selectedPage, let category = selectedCategory else { return }
        
        submitError = nil
        
        let userId = authManager.userId ?? "anonymous"
        
        let report = FeedbackManager.ReportData(
            userId: userId,
            timestamp: Date(),
            page: page,
            category: category,
            subCategory: selectedSubCategory,
            detail: selectedDetail,
            userNotes: userNotes.isEmpty ? nil : userNotes,
            productName: product?.name,
            productCompany: product?.company,
            productId: product?.id,
            reportedCategory: selectedReportedCategory
        )
        
        Task {
            do {
                try await feedbackManager.submitReport(report)
                showSubmitConfirmation = true
            } catch {
                submitError = error.localizedDescription
            }
        }
    }
}
