import SwiftUI

/// Checkout Manager modal - matches screenshot 5 exactly
struct CheckoutManagerView: View {
    
    @EnvironmentObject var cartManager: CartManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showingMenu = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                header
                
                // Item Count and Sort
                HStack {
                    Text("\(cartManager.totalItemCount) items")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Menu {
                        Button("By Company") { }
                        Button("By Price") { }
                        Button("By Name") { }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 14, weight: .medium))
                            Text("Sort")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // Cart Items (grouped by company)
                if cartManager.cartItems.isEmpty {
                    emptyCartView
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            ForEach(cartManager.groupedByCompany()) { group in
                                CompanyCartGroup(group: group)
                            }
                        }
                        .padding(.vertical, 20)
                    }
                }
                
                // Bottom Total Bar
                if !cartManager.cartItems.isEmpty {
                    totalBar
                }
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                // Back Button
                Button(action: {
                    dismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                // BlackBuy Logo - use SVG asset
                Image("shop_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                
                Spacer()
                
                // Menu Button
                Button(action: {
                    showingMenu = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            Text("Checkout Manager")
                .font(.system(size: 28, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }
    
    // MARK: - Empty Cart
    
    private var emptyCartView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bag")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Your cart is empty")
                .font(.system(size: 20, weight: .semibold))
            
            Text("Add products to get started")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Total Bar
    
    private var totalBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Text(cartManager.formattedTotalPrice)
                        .font(.system(size: 32, weight: .bold))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(cartManager.totalItemCount) items")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text("\(cartManager.companyCount) stores")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
        }
    }
}

/// Company cart group (matches screenshot design)
struct CompanyCartGroup: View {
    
    let group: CartItemGroup
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Company Header
            HStack {
                Text(group.company)
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                Text(group.formattedTotalPrice)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
            }
            .padding(.horizontal, 20)
            
            // Products in this company
            ForEach(group.items) { entry in
                CartProductRow(
                    item: entry.item,
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
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func openProductURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Cart product row (matches screenshot design)
struct CartProductRow: View {
    
    let item: CartItem
    let onQuantityChange: (Int) -> Void
    let onRemove: () -> Void
    let onBuy: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image
            AsyncImage(url: URL(string: item.product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.systemGray6)
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Product Info
            VStack(alignment: .leading, spacing: 8) {
                Text(item.product.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                
                Text(item.product.formattedPrice)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                
                // Quantity Controls
                HStack(spacing: 12) {
                    Button(action: {
                        if item.quantity > 1 {
                            onQuantityChange(item.quantity - 1)
                        } else {
                            onRemove()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Text("\(item.quantity)")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(minWidth: 24)
                    
                    Button(action: {
                        onQuantityChange(item.quantity + 1)
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0, green: 0.48, blue: 1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Total Price and Buy Button
            VStack(spacing: 8) {
                Text(item.formattedTotalPrice)
                    .font(.system(size: 17, weight: .bold))
                
                Button(action: onBuy) {
                    Text("Buy")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0, green: 0.48, blue: 1))
                        )
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

/// Scan History View (accessed from floating button)
struct ScanHistoryView: View {
    
    @EnvironmentObject var scanHistoryManager: ScanHistoryManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            header
            
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
            .background(Color.white)
        }
        .background(Color.white)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            // Back Button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // BlackBuy Logo
            Image("shop_logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 28)
                .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
            
            Spacer()
            
            // Spacer for symmetry
            Color.clear
                .frame(width: 22)
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Scan History")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.black)
            
            Text("Your scanned products will appear here")
                .font(.system(size: 15, weight: .regular))
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
                .padding(.horizontal, 20)
                .padding(.top, 20)
            
            VStack(spacing: 12) {
                ForEach(scanHistoryManager.scanHistory.reversed()) { entry in
                    ScanHistoryCard(entry: entry)
                }
            }
            .padding(.horizontal, 20)
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
            // Timestamp at top
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
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.classifiedProduct ?? entry.recognizedText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(2)
                    
                    Text("\(entry.resultCount) products found")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(.systemGray2))
                }
                
                Spacer()
                
                // Shop button
                Button(action: {
                    showingSearch = true
                }) {
                    HStack(spacing: 4) {
                        Text("Shop")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0, green: 0.48, blue: 1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .fullScreenCover(isPresented: $showingSearch) {
            SearchView(initialSearchText: entry.classifiedProduct ?? entry.recognizedText)
        }
    }
}

#Preview {
    CheckoutManagerView()
        .environmentObject(CartManager())
}
