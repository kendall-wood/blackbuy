import SwiftUI

struct BottomNavBar: View {
    @Binding var selectedTab: AppTab
    
    enum AppTab {
        case profile
        case saved
        case scan
        case shop
        case checkout
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 20) {
                NavBarButton(icon: "person.fill", label: "Profile", isSelected: selectedTab == .profile) {
                    selectedTab = .profile
                }
                
                NavBarButton(icon: "heart.fill", label: "Saved", isSelected: selectedTab == .saved) {
                    selectedTab = .saved
                }
                
                NavBarButton(icon: "camera.fill", label: "Scan", isSelected: selectedTab == .scan) {
                    selectedTab = .scan
                }
                
                NavBarButton(icon: "storefront.fill", label: "Shop", isSelected: selectedTab == .shop) {
                    selectedTab = .shop
                }
                
                NavBarButton(icon: "bag.fill", label: "Cart", isSelected: selectedTab == .checkout) {
                    selectedTab = .checkout
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 2)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}

struct NavBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isSelected ? Color(red: 0.26, green: 0.63, blue: 0.95) : Color(.systemGray6))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        BottomNavBar(selectedTab: .constant(.profile))
    }
}
