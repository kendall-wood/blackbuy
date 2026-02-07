import SwiftUI

/// Checkout Manager modal
struct CheckoutManagerView: View {
    
    @Binding var selectedTab: AppTab
    var onBack: () -> Void = {}
    @EnvironmentObject var cartManager: CartManager
    
    @State private var showingMenu = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppHeader(centerContent: .logo, onBack: onBack)
            
            // Checkout Manager Title
            Text("Checkout Manager")
                .font(DS.pageTitle)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DS.sectionSpacing) {
                    // Item Count and Sort
                    HStack {
                        Text("\(cartManager.totalItemCount) items")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color(.systemGray))
                        
                        Spacer()
                    }
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.top, 8)
                    
                    // Cart Items (grouped by company)
                    if cartManager.cartItems.isEmpty {
                        emptyCartView
                    } else {
                        VStack(spacing: 12) {
                            ForEach(cartManager.groupedByCompany()) { group in
                                CompanyCartGroup(group: group)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(DS.cardBackground)
            
            // Bottom Total Bar
            if !cartManager.cartItems.isEmpty {
                totalBar
            }
        }
        .background(DS.cardBackground)
    }
    
    private func openProductURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Empty Cart
    
    private var emptyCartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bag")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Your cart is empty")
                .font(DS.sectionHeader)
                .foregroundColor(.black)
            
            Text("Add products to get started")
                .font(DS.body)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 60)
    }
    
    // MARK: - Total Bar
    
    private var totalBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(DS.caption)
                        .foregroundColor(Color(.systemGray))
                    
                    Text(cartManager.formattedTotalPrice)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(cartManager.totalItemCount) items")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                    
                    Text("\(cartManager.companyCount) stores")
                        .font(DS.caption)
                        .foregroundColor(Color(.systemGray2))
                }
            }
            .padding(.horizontal, DS.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .background(DS.cardBackground)
        }
    }
}

/// Company cart group
struct CompanyCartGroup: View {
    
    let group: CartItemGroup
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Company name header
            HStack {
                Text(group.company)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.black)
                
                Spacer()
                
                Text(group.formattedTotalPrice)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.brandBlue)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Products in this company
            VStack(spacing: 10) {
                ForEach(group.items) { entry in
                    CartProductRow(
                        item: entry.item,
                        companyName: group.company,
                        onQuantityChange: { newQuantity in
                            cartManager.updateQuantity(for: entry.item.product, quantity: newQuantity)
                        },
                        onRemove: {
                            cartManager.removeFromCart(entry.item.product)
                        },
                        onBuy: {
                            openProductURL(entry.item.product.productUrl)
                        }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(DS.cardBackground)
        .cornerRadius(DS.radiusLarge)
        .dsCardShadow()
        .padding(.horizontal, DS.horizontalPadding)
    }
    
    private func openProductURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Cart product row
struct CartProductRow: View {
    
    let item: CartItem
    let companyName: String
    let onQuantityChange: (Int) -> Void
    let onRemove: () -> Void
    let onBuy: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isShowingActions = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Complete button (left/green)
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 0
                            isShowingActions = false
                        }
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 72, height: 96)
                            .background(
                                UnevenRoundedRectangle(cornerRadii: .init(
                                    topLeading: DS.radiusMedium,
                                    bottomLeading: DS.radiusMedium,
                                    bottomTrailing: 0,
                                    topTrailing: 0
                                ))
                                .fill(DS.brandGreen)
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(dragOffset > 5 ? 1 : 0)
                    
                    Spacer()
                }
                
                // Delete button (right/red)
                HStack(spacing: 0) {
                    Spacer()
                    
                    Button(action: { onRemove() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 72, height: 96)
                            .background(
                                UnevenRoundedRectangle(cornerRadii: .init(
                                    topLeading: 0,
                                    bottomLeading: 0,
                                    bottomTrailing: DS.radiusMedium,
                                    topTrailing: DS.radiusMedium
                                ))
                                .fill(DS.brandRed)
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(dragOffset < -5 ? 1 : 0)
                }
                
                // Main card content
                cardContent
                    .frame(width: geometry.size.width)
                    .offset(x: dragOffset)
                    .highPriorityGesture(
                        DragGesture()
                            .onChanged { value in
                                let translation = value.translation.width
                                if translation > 0 {
                                    dragOffset = min(translation, 80)
                                } else {
                                    dragOffset = max(translation, -80)
                                }
                            }
                            .onEnded { value in
                                withAnimation(.easeOut(duration: 0.3)) {
                                    if value.translation.width < -50 {
                                        dragOffset = -80
                                        isShowingActions = true
                                    } else if value.translation.width > 50 {
                                        dragOffset = 80
                                        isShowingActions = true
                                    } else {
                                        dragOffset = 0
                                        isShowingActions = false
                                    }
                                }
                            }
                    )
            }
            .frame(height: 96)
        }
        .frame(height: 96)
    }
    
    private var cardContent: some View {
        HStack(alignment: .center, spacing: 10) {
            // Product Image
            CachedAsyncImage(url: URL(string: item.product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.white.overlay(ProgressView())
            }
            .frame(width: 64, height: 64)
            .background(Color.white)
            .cornerRadius(DS.radiusSmall)
            .clipped()
            
            // Product Info
            VStack(alignment: .leading, spacing: 3) {
                Text(item.product.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(item.product.formattedPrice)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(.systemGray))
                
                // Quantity Controls
                HStack(spacing: 8) {
                    Button(action: {
                        if item.quantity > 1 {
                            onQuantityChange(item.quantity - 1)
                        } else {
                            onRemove()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: 22, height: 22)
                            Image(systemName: "minus")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(item.quantity)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black)
                        .frame(minWidth: 16)
                    
                    Button(action: { onQuantityChange(item.quantity + 1) }) {
                        ZStack {
                            Circle()
                                .fill(DS.brandBlue)
                                .frame(width: 22, height: 22)
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Total Price and Buy Button stacked
            VStack(spacing: 8) {
                Text(item.formattedTotalPrice)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                
                Button(action: onBuy) {
                    Text("Buy")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(DS.brandGradient)
                        .cornerRadius(DS.radiusSmall)
                }
                .buttonStyle(DSButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(height: 96)
        .background(DS.cardBackground)
        .cornerRadius(DS.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusMedium)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Recent Scans View

/// Dedicated recent scans page accessed from scan view history button
struct RecentScansView: View {
    
    /// Callback when user taps a scan row to search in the shop
    var onSearchInShop: ((String) -> Void)? = nil
    
    @EnvironmentObject var scanHistoryManager: ScanHistoryManager
    @Environment(\.dismiss) var dismiss
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with logo
            AppHeader(centerContent: .logo, onBack: { dismiss() })
            
            // Page title
            Text("Recent Scans")
                .font(DS.pageTitle)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            // Content
            if scanHistoryManager.scanHistory.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(Color(.systemGray3))
                    
                    Text("No Recent Scans")
                        .font(DS.sectionHeader)
                        .foregroundColor(.black)
                    
                    Text("Products you scan will appear here")
                        .font(DS.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                List {
                    ForEach(scanHistoryManager.scanHistory) { entry in
                        RecentScanRow(
                            entry: entry,
                            dateFormatter: dateFormatter,
                            timeFormatter: timeFormatter,
                            onTapped: {
                                let query = entry.classifiedProduct ?? entry.recognizedText
                                onSearchInShop?(query)
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: DS.horizontalPadding, bottom: 8, trailing: DS.horizontalPadding))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            scanHistoryManager.removeScan(scanHistoryManager.scanHistory[index])
                        }
                    }
                }
                .listStyle(.plain)
                .background(DS.cardBackground)
            }
        }
        .background(DS.cardBackground)
    }
}

/// Single row in the recent scans list
struct RecentScanRow: View {
    let entry: ScanHistoryEntry
    let dateFormatter: DateFormatter
    let timeFormatter: DateFormatter
    var onTapped: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTapped?() }) {
            HStack(spacing: 14) {
                // Scan icon
                ZStack {
                    Circle()
                        .fill(DS.brandBlue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 20))
                        .foregroundColor(DS.brandBlue)
                }
                
                // Scan details
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.classifiedProduct ?? entry.recognizedText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(dateFormatter.string(from: entry.timestamp))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color(.systemGray))
                        
                        Text("•")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.systemGray3))
                        
                        Text(timeFormatter.string(from: entry.timestamp))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color(.systemGray))
                    }
                    
                    Text("\(entry.resultCount) products found")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(.systemGray2))
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
            }
            .padding(14)
            .background(DS.cardBackground)
            .cornerRadius(DS.radiusMedium)
            .dsCardShadow()
        }
        .buttonStyle(DSButtonStyle())
    }
}

#Preview {
    CheckoutManagerView(selectedTab: .constant(.checkout))
        .environmentObject(CartManager())
}
