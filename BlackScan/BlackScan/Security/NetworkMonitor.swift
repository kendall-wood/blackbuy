import Foundation
import Network
import SwiftUI

/// Monitors network connectivity using NWPathMonitor.
/// Publishes `isConnected` for use by the offline toast overlay.
@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected: Bool = true
    @Published var showOfflineBanner: Bool = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.blackscan.networkmonitor")
    
    private var dismissTask: Task<Void, Never>?
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                
                if !self.isConnected {
                    // Lost connection — show banner
                    self.dismissTask?.cancel()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        self.showOfflineBanner = true
                    }
                } else if wasConnected == false && self.isConnected {
                    // Regained connection — auto-dismiss after a short delay
                    self.dismissTask?.cancel()
                    self.dismissTask = Task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        if !Task.isCancelled {
                            withAnimation(.easeIn(duration: 0.2)) {
                                self.showOfflineBanner = false
                            }
                        }
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
