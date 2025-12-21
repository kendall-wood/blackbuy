import SwiftUI

@main
struct BlackScanApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            // Scan Tab
            ScanView()
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("Scan")
                }
            
            // Shop Tab
            ShopView()
                .tabItem {
                    Image(systemName: "storefront")
                    Text("Shop")
                }
            
            // Saved Tab
            SavedView()
                .tabItem {
                    Image(systemName: "heart")
                    Text("Saved")
                }
        }
        .accentColor(.primary) // Use system accent color for tabs
    }
}
