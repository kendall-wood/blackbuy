import SwiftUI

/// Checkout Manager modal
struct CheckoutManagerView: View {
    
    @Binding var selectedTab: AppTab
    @EnvironmentObject var cartManager: CartManager
    
    @State private var showingMenu = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppHeader(centerContent: .logo, onBack: { selectedTab = .scan })
            
            // Checkout Manager Title
            Text("Checkout Manager")
                .font(DS.pageTitle)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Content
            ScrollView {
                VStack(spacing: DS.sectionSpacing) {
                    // Item Count and Sort
                    HStack {
                        Text("\(cartManager.totalItemCount) items")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color(.systemGray))
                        
                        Spacer()
                        
                        DSSortButton(label: "Sort") {
                            Button("By Company") { }
                            Button("By Price") { }
                            Button("By Name") { }
                        }
                    }
                    .padding(.horizontal, DS.horizontalPadding)
                    .padding(.top, 8)
                    
                    // Cart Items (grouped by company)
                    if cartManager.cartItems.isEmpty {
                        emptyCartView
                    } else {
                        VStack(spacing: 16) {
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
        .padding(.vertical, 80)
    }
    
    // MARK: - Total Bar
    
    private var totalBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total")
                        .font(DS.body)
                        .foregroundColor(Color(.systemGray))
                    
                    Text(cartManager.formattedTotalPrice)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(cartManager.totalItemCount) items")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                    
                    Text("\(cartManager.companyCount) stores")
                        .font(DS.body)
                        .foregroundColor(Color(.systemGray2))
                }
            }
            .padding(.horizontal, DS.horizontalPadding)
            .padding(.vertical, 20)
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
                    .font(DS.sectionHeader)
                    .foregroundColor(.black)
                
                Spacer()
                
                Text(group.formattedTotalPrice)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DS.brandBlue)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Products in this company
            VStack(spacing: 14) {
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
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
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
                        withAnimation {
                            dragOffset = 0
                            isShowingActions = false
                        }
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 92, height: 120)
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
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 92, height: 120)
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
            .frame(height: 120)
        }
        .frame(height: 120)
    }
    
    private var cardContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // Product Image
            CachedAsyncImage(url: URL(string: item.product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.white.overlay(ProgressView())
            }
            .frame(width: 80, height: 80)
            .background(Color.white)
            .cornerRadius(DS.radiusSmall)
            .clipped()
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(item.product.formattedPrice)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(.systemGray))
                    .padding(.bottom, 1)
                
                // Quantity Controls
                HStack(spacing: 10) {
                    Button(action: {
                        if item.quantity > 1 {
                            onQuantityChange(item.quantity - 1)
                        } else {
                            onRemove()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray))
                                .frame(width: 24, height: 24)
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(item.quantity)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .frame(minWidth: 20)
                    
                    Button(action: { onQuantityChange(item.quantity + 1) }) {
                        ZStack {
                            Circle()
                                .fill(DS.brandBlue)
                                .frame(width: 24, height: 24)
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 12)
            
            // Total Price and Buy Button stacked
            VStack(spacing: 10) {
                Text(item.formattedTotalPrice)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Button(action: onBuy) {
                    Text("Buy")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(DS.brandGradient)
                        .cornerRadius(DS.radiusSmall)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(height: 120)
        .background(DS.cardBackground)
        .cornerRadius(DS.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusMedium)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

/// Scan History View (accessed from floating button)
struct ScanHistoryView: View {
    
    @EnvironmentObject var scanHistoryManager: ScanHistoryManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppHeader(centerContent: .logo, onBack: { dismiss() })
            
            // Content
            ScrollView {
                VStack(spacing: 0) {
                    if scanHistoryManager.scanHistory.isEmpty {
                        emptyStateView
                    } else {
                        historyList
                    }
                }
            }
            .background(DS.cardBackground)
        }
        .background(DS.cardBackground)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Scan History")
                .font(DS.sectionHeader)
                .foregroundColor(.black)
            
            Text("Your scanned products will appear here")
                .font(DS.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 80)
    }
    
    // MARK: - History List
    
    private var historyList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scan History")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.black)
                .padding(.horizontal, DS.horizontalPadding)
                .padding(.top, 20)
            
            VStack(spacing: 12) {
                ForEach(scanHistoryManager.scanHistory.reversed()) { entry in
                    ScanHistoryCard(entry: entry)
                }
            }
            .padding(.horizontal, DS.horizontalPadding)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Scan History Card

struct ScanHistoryCard: View {
    let entry: ScanHistoryEntry
    @Environment(\.dismiss) var dismiss
    @State private var showingSearch = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timestamp
            Text(entry.timestamp, style: .date)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(.systemGray))
            + Text(" at ")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(.systemGray))
            + Text(entry.timestamp, style: .time)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(.systemGray))
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.classifiedProduct ?? entry.recognizedText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(2)
                    
                    Text("\(entry.resultCount) products found")
                        .font(DS.caption)
                        .foregroundColor(Color(.systemGray2))
                }
                
                Spacer()
                
                // Shop button
                Button(action: { showingSearch = true }) {
                    HStack(spacing: 4) {
                        Text("Shop")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DS.brandGradient)
                    .cornerRadius(DS.radiusSmall)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(DS.cardBackground)
        .cornerRadius(DS.radiusMedium)
        .dsCardShadow()
        .fullScreenCover(isPresented: $showingSearch) {
            SearchView(initialSearchText: entry.classifiedProduct ?? entry.recognizedText)
        }
    }
}

#Preview {
    CheckoutManagerView(selectedTab: .constant(.checkout))
        .environmentObject(CartManager())
}
