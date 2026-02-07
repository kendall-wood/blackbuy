import SwiftUI

// MARK: - Design System

/// Centralized design tokens for the BlackScan/BlackBuy app.
/// Usage: `DS.brandBlue`, `DS.cardShadow`, `DS.radiusMedium`, etc.
enum DS {
    
    // MARK: - Colors
    
    /// Primary brand blue -- used for text, icons, and tints throughout the app.
    static let brandBlue = Color(red: 0.26, green: 0.63, blue: 0.95)
    
    /// Gradient for button backgrounds -- adds depth without being flat.
    static let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.32, green: 0.68, blue: 1.0),
            Color(red: 0.18, green: 0.52, blue: 0.88)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Green for "in cart" / success state.
    static let brandGreen = Color(red: 0, green: 0.75, blue: 0.33)
    
    /// Red for hearts and destructive actions.
    static let brandRed = Color.red
    
    /// Card and surface background.
    static let cardBackground = Color.white
    
    /// Light blue background for brand circle placeholders.
    static let circleFallbackBg = Color(red: 0.95, green: 0.97, blue: 1)
    
    // MARK: - Shadows
    
    /// Standard card shadow.
    static func cardShadow() -> some ViewModifier { ShadowModifier(opacity: 0.08, radius: 8, y: 2) }
    
    /// Floating button shadow (camera overlay buttons).
    static func buttonShadow() -> some ViewModifier { ShadowModifier(opacity: 0.25, radius: 4, y: 2) }
    
    // MARK: - Corner Radii
    
    /// 8pt -- chips, sort buttons, small controls.
    static let radiusSmall: CGFloat = 8
    
    /// 12pt -- card images, medium cards.
    static let radiusMedium: CGFloat = 12
    
    /// 16pt -- large product cards, sheets.
    static let radiusLarge: CGFloat = 16
    
    /// 25pt -- pill-shaped buttons.
    static let radiusPill: CGFloat = 25
    
    // MARK: - Spacing
    
    /// Standard horizontal padding for content sections.
    static let horizontalPadding: CGFloat = 24
    
    /// Grid spacing (both column and row) for product grids.
    static let gridSpacing: CGFloat = 20
    
    /// Spacing between major sections.
    static let sectionSpacing: CGFloat = 24
    
    // MARK: - Typography
    
    /// 28pt bold -- page titles like "Checkout Manager".
    static let pageTitle: Font = .system(size: 28, weight: .bold)
    
    /// 18pt semibold -- section headers like "Featured Brands".
    static let sectionHeader: Font = .system(size: 18, weight: .semibold)
    
    /// 15pt regular -- body text.
    static let body: Font = .system(size: 15, weight: .regular)
    
    /// 13pt regular -- captions, secondary info.
    static let caption: Font = .system(size: 13, weight: .regular)
    
    /// 11pt bold uppercase with tracking -- labels like "CATEGORIES".
    static let label: Font = .system(size: 11, weight: .bold)
    
    /// Standard letter tracking for label text.
    static let labelTracking: CGFloat = 1.2
    
    // MARK: - Header Height
    
    /// Standard header height used across all views.
    static let headerHeight: CGFloat = 60
}

// MARK: - Shadow Modifier

struct ShadowModifier: ViewModifier {
    let opacity: Double
    let radius: CGFloat
    let y: CGFloat
    
    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(opacity), radius: radius, x: 0, y: y)
    }
}

extension View {
    func dsCardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    func dsButtonShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
    }
}

// MARK: - App Tab Enum

/// Navigation tab enum used across the app.
enum AppTab {
    case profile
    case saved
    case scan
    case shop
    case checkout
}

// MARK: - App Back Button

/// Reusable circular back button -- 44pt white circle, shadow, blue chevron.
struct AppBackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(DS.cardBackground)
                    .frame(width: 44, height: 44)
                    .dsCardShadow()
                
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DS.brandBlue)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Header

/// Reusable header bar used across all views.
/// Provides a consistent 60pt-tall header with back button, center content, and optional trailing button.
struct AppHeader: View {
    
    enum CenterContent {
        case logo          // shop_logo image
        case title(String) // text title
    }
    
    let centerContent: CenterContent
    let onBack: () -> Void
    var trailingContent: AnyView? = nil
    
    var body: some View {
        HStack {
            // Leading: Back button
            AppBackButton(action: onBack)
            
            Spacer()
            
            // Center content
            switch centerContent {
            case .logo:
                Image("shop_logo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
                    .foregroundColor(DS.brandBlue)
            case .title(let text):
                Text(text)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
            }
            
            Spacer()
            
            // Trailing: optional button or invisible spacer for balance
            if let trailing = trailingContent {
                trailing
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
        .frame(height: DS.headerHeight)
        .padding(.horizontal, DS.horizontalPadding)
        .background(DS.cardBackground)
    }
}

// MARK: - Sort Button

/// Reusable sort menu button used in Saved, Checkout, Company views.
struct DSSortButton<Content: View>: View {
    let label: String
    @ViewBuilder let menuContent: () -> Content
    
    var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .medium))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.radiusSmall)
                            .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
