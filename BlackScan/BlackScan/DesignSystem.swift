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
    
    /// Subtle stroke color for cards, circles, and UI borders — muted blue-grey.
    static let strokeColor = DS.brandBlue.opacity(0.25)
    
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
    
    /// 24pt semibold -- page titles like "Checkout Manager".
    static let pageTitle: Font = .system(size: 24, weight: .semibold)
    
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

// MARK: - Button Styles

/// Press-scale button style for primary interactive elements.
/// Gives a subtle scale + opacity effect on press for tactile feedback.
struct DSButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
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
        self
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusMedium)
                    .stroke(DS.strokeColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
    
    func dsCardShadow(cornerRadius: CGFloat) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DS.strokeColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
    
    func dsCircleShadow() -> some View {
        self
            .overlay(
                Circle()
                    .stroke(DS.strokeColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
    
    func dsButtonShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted when a view wants to navigate to the Shop and search for a term.
    /// The `object` should be a `String` containing the search query.
    static let searchInShop = Notification.Name("searchInShop")
    
    /// Posted when a view wants to navigate to the Shop and select a category row.
    /// The `object` should be a `String` containing the category name (e.g., "Hair Care").
    static let navigateToCategory = Notification.Name("navigateToCategory")
    
    /// Posted when the user shakes the device to report an issue.
    static let shakeToReport = Notification.Name("shakeToReport")
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
                    .dsCircleShadow()
                
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DS.brandBlue)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shake Detection

/// A hidden view that detects device shakes and posts `.shakeToReport` notification.
/// Place as a `.background()` on the root view (MainTabView).
struct ShakeDetector: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ShakeDetectorViewController {
        ShakeDetectorViewController()
    }
    
    func updateUIViewController(_ uiViewController: ShakeDetectorViewController, context: Context) {}
}

class ShakeDetectorViewController: UIViewController {
    override var canBecomeFirstResponder: Bool { true }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .shakeToReport, object: nil)
        }
    }
}

// MARK: - Report Menu Button

/// Reusable three-dot menu button for the header trailing slot.
/// Opens a menu with "Report Issue" option. Matches AppBackButton style (44pt white circle).
struct ReportMenuButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(DS.cardBackground)
                    .frame(width: 44, height: 44)
                    .dsCircleShadow()
                
                Image(systemName: "ellipsis")
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
                    .offset(y: 3)
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
        .padding(.top, 10)
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

// MARK: - Toast Notification System

/// Types of toast notifications
enum ToastType {
    case addedToCheckout
    case removedFromCheckout
    case saved
    case unsaved
    
    var icon: String {
        switch self {
        case .addedToCheckout: return "checkmark.circle.fill"
        case .removedFromCheckout: return "minus.circle.fill"
        case .saved: return "heart.fill"
        case .unsaved: return "heart"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .addedToCheckout: return DS.brandGreen
        case .removedFromCheckout: return Color(.systemGray)
        case .saved: return DS.brandRed
        case .unsaved: return Color(.systemGray)
        }
    }
    
    var message: String {
        switch self {
        case .addedToCheckout: return "Added to Checkout!"
        case .removedFromCheckout: return "Removed from Checkout"
        case .saved: return "Saved!"
        case .unsaved: return "Removed"
        }
    }
    
    var targetTab: AppTab {
        switch self {
        case .addedToCheckout, .removedFromCheckout: return .checkout
        case .saved, .unsaved: return .saved
        }
    }
}

/// Global toast manager — inject as environmentObject at the app level
@MainActor
class ToastManager: ObservableObject {
    @Published var currentToast: ToastType? = nil
    @Published var isVisible: Bool = false
    /// Screen-coordinate frame of the toast pill, used by ToastWindow for hit testing
    @Published var toastFrame: CGRect = .zero
    
    private var dismissTask: Task<Void, Never>?
    
    func show(_ type: ToastType) {
        dismissTask?.cancel()
        
        withAnimation(.easeOut(duration: 0.2)) {
            currentToast = type
            isVisible = true
        }
        
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_250_000_000) // 2.25 seconds
            if !Task.isCancelled {
                withAnimation(.easeIn(duration: 0.2)) {
                    isVisible = false
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
                if !Task.isCancelled {
                    currentToast = nil
                    toastFrame = .zero
                }
            }
        }
    }
}

/// Toast overlay view — place at the top of the view hierarchy
struct ToastOverlay: View {
    @EnvironmentObject var toastManager: ToastManager
    var onNavigate: ((AppTab) -> Void)? = nil
    
    var body: some View {
        VStack {
            if toastManager.isVisible, let toast = toastManager.currentToast {
                Button(action: {
                    onNavigate?(toast.targetTab)
                    withAnimation(.easeIn(duration: 0.15)) {
                        toastManager.isVisible = false
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: toast.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(toast.iconColor)
                        
                        Text(toast.message)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(.systemGray3))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: DS.radiusPill)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                                .onAppear {
                                    toastManager.toastFrame = geo.frame(in: .global)
                                }
                                .onChange(of: geo.frame(in: .global)) { newFrame in
                                    toastManager.toastFrame = newFrame
                                }
                        }
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 56)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastManager.isVisible)
    }
}

// MARK: - Offline Banner (matches toast style)

/// Overlay that shows a pill-shaped "No Internet Connection" banner
/// when the device loses connectivity. Matches the existing toast design.
struct OfflineBannerOverlay: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor
    
    var body: some View {
        VStack {
            if networkMonitor.showOfflineBanner {
                HStack(spacing: 10) {
                    Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(networkMonitor.isConnected ? DS.brandGreen : .orange)
                    
                    Text(networkMonitor.isConnected ? "Back Online" : "No Internet Connection")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusPill)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                )
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: networkMonitor.showOfflineBanner)
    }
}

// MARK: - Toast Window (renders above all sheets/covers)

/// A passthrough window that sits above everything but doesn't block touches.
/// Uses the ToastManager's frame to decide which touches to intercept.
class ToastWindow: UIWindow {
    /// Reference to the toast manager for frame-based hit testing
    weak var toastManager: ToastManager?
    /// Optional reference for offline banner frame (non-interactive, always passes through)
    var isPassthroughOnly = false
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Offline banner window — always pass through (no tap interaction needed)
        if isPassthroughOnly { return false }
        
        // Only intercept taps that land on the actual toast pill
        guard let manager = toastManager else { return false }
        
        // Must be on main thread to read @Published safely
        let frame = manager.toastFrame
        let visible = manager.isVisible
        
        guard visible, !frame.isEmpty else { return false }
        
        // Convert point to screen coordinates and check against toast frame
        let screenPoint = convert(point, to: nil)
        return frame.contains(screenPoint)
    }
}

/// Manages a separate UIWindow for toast overlays so they appear above sheets/covers
class ToastWindowManager {
    static let shared = ToastWindowManager()
    private var toastWindow: ToastWindow?
    private var offlineWindow: ToastWindow?
    
    func setup(toastManager: ToastManager, networkMonitor: NetworkMonitor, onNavigate: @escaping (AppTab) -> Void) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        // Toast overlay window
        let toastView = ToastOverlay(onNavigate: onNavigate)
            .environmentObject(toastManager)
        
        let hostingController = UIHostingController(rootView: toastView)
        hostingController.view.backgroundColor = .clear
        
        let window = ToastWindow(windowScene: scene)
        window.rootViewController = hostingController
        window.toastManager = toastManager
        window.isHidden = false
        window.windowLevel = .alert + 1  // Above everything
        window.backgroundColor = .clear
        
        self.toastWindow = window
        
        // Offline banner window (non-interactive, always passes through)
        let offlineView = OfflineBannerOverlay()
            .environmentObject(networkMonitor)
        
        let offlineHosting = UIHostingController(rootView: offlineView)
        offlineHosting.view.backgroundColor = .clear
        
        let offlineWin = ToastWindow(windowScene: scene)
        offlineWin.rootViewController = offlineHosting
        offlineWin.isPassthroughOnly = true
        offlineWin.isHidden = false
        offlineWin.windowLevel = .alert  // Just below the toast window
        offlineWin.backgroundColor = .clear
        
        self.offlineWindow = offlineWin
    }
}
