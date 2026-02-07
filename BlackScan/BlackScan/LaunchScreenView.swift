import SwiftUI

/// Launch screen matching the BlackBuy branding
/// White background with centered blue BlackBuy logo
struct LaunchScreenView: View {
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea(.all)
            
            VStack(spacing: 16) {
                Image("shop_logo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .foregroundColor(DS.brandBlue)
                
                ProgressView()
                    .tint(DS.brandBlue)
                    .scaleEffect(0.8)
            }
        }
    }
}

#Preview("Launch Screen") {
    LaunchScreenView()
}
