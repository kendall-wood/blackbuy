import SwiftUI

/// Checkout Manager modal - matches screenshot 5 exactly
struct CheckoutManagerView: View {
    
    @EnvironmentObject var cartManager: CartManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showingMenu = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // Checkout Manager Title
            Text("Checkout Manager")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Item Count and Sort
                    HStack {
                        Text("\(cartManager.totalItemCount) items")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color(.systemGray))
                        
                        Spacer()
                        
                        Menu {
                            Button("By Company") { }
                            Button("By Price") { }
                            Button("By Name") { }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Sort")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Cart Items (grouped by company)
                    if cartManager.cartItems.isEmpty {
                        emptyCartView
                    } else {
                        VStack(spacing: 24) {
                            ForEach(cartManager.groupedByCompany()) { group in
                                CompanyCartGroup(group: group)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(Color.white)
            
            // Bottom Total Bar
            if !cartManager.cartItems.isEmpty {
                totalBar
            }
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
            
            // Menu Button
            Button(action: {
                showingMenu = true
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
            }
            .buttonStyle(.plain)
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    // MARK: - Empty Cart
    
    private var emptyCartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bag")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Your cart is empty")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.black)
            
            Text("Add products to get started")
                .font(.system(size: 15, weight: .regular))
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
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(.systemGray))
                    
                    Text(cartManager.formattedTotalPrice)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(cartManager.totalItemCount) items")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                    
                    Text("\(cartManager.companyCount) stores")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(.systemGray2))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color.white)
        }
    }
}

/// Company cart group (matches established styling)
struct CompanyCartGroup: View {
    
    let group: CartItemGroup
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Products in this company (no header)
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
        .padding(.horizontal, 20)
    }
    
    private func openProductURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Cart product row (matches established styling)
struct CartProductRow: View {
    
    let item: CartItem
    let companyName: String
    let onQuantityChange: (Int) -> Void
    let onRemove: () -> Void
    let onBuy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Company name - prominent at top
            Text(companyName)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.black)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // Divider line
            Divider()
                .padding(.horizontal, 12)
            
            HStack(alignment: .top, spacing: 12) {
                // Product Image
                CachedAsyncImage(url: URL(string: item.product.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.white
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(width: 80, height: 80)
                .background(Color.white)
                .cornerRadius(8)
                .clipped()
                
                // Product Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.product.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(item.product.formattedPrice)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(.systemGray))
                        .padding(.bottom, 2)
                    
                    // Quantity Controls
                    HStack(spacing: 16) {
                        Button(action: {
                            if item.quantity > 1 {
                                onQuantityChange(item.quantity - 1)
                            } else {
                                onRemove()
                            }
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(.systemGray))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        
                        Text("\(item.quantity)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(minWidth: 24)
                        
                        Button(action: {
                            onQuantityChange(item.quantity + 1)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(red: 0, green: 0.48, blue: 1))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Total Price and Buy Button stacked
                VStack(spacing: 8) {
                    Text(item.formattedTotalPrice)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.black)
                    
                    Button(action: onBuy) {
                        Text("Buy")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(red: 0, green: 0.48, blue: 1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
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
