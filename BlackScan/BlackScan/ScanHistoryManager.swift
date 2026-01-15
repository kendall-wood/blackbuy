import Foundation

/// Represents a single scan entry in history
struct ScanHistoryEntry: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let recognizedText: String
    let classifiedProduct: String?
    let resultCount: Int
    
    /// Formatted date string for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Relative time string (e.g., "2 hours ago")
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

/// Manages scan history with local storage using UserDefaults
@MainActor
class ScanHistoryManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published var scanHistory: [ScanHistoryEntry] = []
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "BlackScan_ScanHistory"
    private let maxHistoryCount = 50 // Limit to last 50 scans for performance
    
    // MARK: - Initialization
    
    init() {
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    /// Add a new scan to history
    func addScan(
        recognizedText: String,
        classifiedProduct: String?,
        resultCount: Int
    ) {
        let entry = ScanHistoryEntry(
            timestamp: Date(),
            recognizedText: recognizedText.trimmingCharacters(in: .whitespacesAndNewlines),
            classifiedProduct: classifiedProduct,
            resultCount: resultCount
        )
        
        // Add to beginning of array (most recent first)
        scanHistory.insert(entry, at: 0)
        
        // Limit to maxHistoryCount entries
        if scanHistory.count > maxHistoryCount {
            scanHistory = Array(scanHistory.prefix(maxHistoryCount))
        }
        
        saveHistory()
        
        print("📚 ScanHistory: Added scan - '\(classifiedProduct ?? "Unknown")' with \(resultCount) results")
    }
    
    /// Clear all scan history
    func clearHistory() {
        scanHistory.removeAll()
        saveHistory()
        print("📚 ScanHistory: Cleared all history")
    }
    
    /// Remove a specific scan from history
    func removeScan(_ entry: ScanHistoryEntry) {
        scanHistory.removeAll { $0.id == entry.id }
        saveHistory()
        print("📚 ScanHistory: Removed scan - '\(entry.classifiedProduct ?? "Unknown")'")
    }
    
    // MARK: - Private Methods
    
    private func loadHistory() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            print("📚 ScanHistory: No existing history found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            scanHistory = try decoder.decode([ScanHistoryEntry].self, from: data)
            print("📚 ScanHistory: Loaded \(scanHistory.count) entries")
        } catch {
            print("❌ ScanHistory: Failed to load history - \(error)")
            scanHistory = []
        }
    }
    
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(scanHistory)
            userDefaults.set(data, forKey: storageKey)
            print("📚 ScanHistory: Saved \(scanHistory.count) entries")
        } catch {
            print("❌ ScanHistory: Failed to save history - \(error)")
        }
    }
}
