import SwiftUI

/// Launch screen matching the BlackBuy branding
/// Clean white background with centered blue "blackbuy" text
struct LaunchScreenView: View {
    
    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea(.all)
            
            // Centered "blackbuy" text
            Text("blackbuy")
                .font(.system(size: 48, weight: .medium, design: .default))
                .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0)) // Blue color matching the design
                .kerning(1.0) // Slight letter spacing for elegance
        }
    }
}

// MARK: - Preview

#Preview("Launch Screen") {
    LaunchScreenView()
}
