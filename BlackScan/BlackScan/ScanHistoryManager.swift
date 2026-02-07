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
    private let maxHistoryCount = 24 // Limit to last 24 scans
    
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
        
        Log.debug("ScanHistory: Added scan with \(resultCount) results", category: .storage)
    }
    
    /// Clear all scan history
    func clearHistory() {
        scanHistory.removeAll()
        saveHistory()
        Log.debug("ScanHistory: Cleared all history", category: .storage)
    }
    
    /// Remove a specific scan from history
    func removeScan(_ entry: ScanHistoryEntry) {
        scanHistory.removeAll { $0.id == entry.id }
        saveHistory()
        Log.debug("ScanHistory: Removed scan entry", category: .storage)
    }
    
    // MARK: - Private Methods
    
    private func loadHistory() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            Log.debug("ScanHistory: No existing history found", category: .storage)
            return
        }
        
        do {
            let decoder = JSONDecoder()
            scanHistory = try decoder.decode([ScanHistoryEntry].self, from: data)
            Log.debug("ScanHistory: Loaded \(scanHistory.count) entries", category: .storage)
        } catch {
            Log.error("ScanHistory: Failed to load history", category: .storage)
            scanHistory = []
        }
    }
    
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(scanHistory)
            userDefaults.set(data, forKey: storageKey)
            Log.debug("ScanHistory: Saved \(scanHistory.count) entries", category: .storage)
        } catch {
            Log.error("ScanHistory: Failed to save history", category: .storage)
        }
    }
}
