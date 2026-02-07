import Foundation
import SwiftUI

/// Saved Companies Manager for managing favorite companies
/// Handles saving, removing, and persisting company favorites
@MainActor
class SavedCompaniesManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var savedCompanies: [SavedCompany] = []
    
    // MARK: - Private Properties
    
    private let localStorageKey = "saved_companies_local"
    
    // MARK: - Saved Company Model
    
    struct SavedCompany: Identifiable, Codable, Equatable {
        let id: String // Company name as ID
        let name: String
        let dateSaved: Date
        var productCount: Int? // Optional: number of products from this company
        var cachedImageUrl: String? // Cached product image for fast display
        var cachedCategory: String? // Cached category for fast display
        
        init(name: String, productCount: Int? = nil, imageUrl: String? = nil, category: String? = nil) {
            self.id = name
            self.name = name
            self.dateSaved = Date()
            self.productCount = productCount
            self.cachedImageUrl = imageUrl
            self.cachedCategory = category
        }
    }
    
    // MARK: - Initialization
    
    init() {
        Log.debug("SavedCompaniesManager initializing", category: .storage)
        loadLocalCompanies()
    }
    
    // MARK: - Local Storage
    
    /// Load saved companies from local storage
    private func loadLocalCompanies() {
        do {
            guard let data = UserDefaults.standard.data(forKey: localStorageKey) else {
                Log.debug("No local saved companies found", category: .storage)
                return
            }
            
            let decoder = JSONDecoder()
            let companies = try decoder.decode([SavedCompany].self, from: data)
            
            self.savedCompanies = companies
            Log.debug("Loaded \(companies.count) companies from local storage", category: .storage)
        } catch {
            Log.error("Failed to load local companies", category: .storage)
            self.savedCompanies = []
        }
    }
    
    /// Save companies to local storage
    private func saveLocalCompanies() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(savedCompanies)
            UserDefaults.standard.set(data, forKey: localStorageKey)
            Log.debug("Saved \(savedCompanies.count) companies to local storage", category: .storage)
        } catch {
            Log.error("Failed to save local companies", category: .storage)
        }
    }
    
    // MARK: - Public Methods
    
    /// Check if a company is saved
    func isCompanySaved(_ companyName: String) -> Bool {
        return savedCompanies.contains { $0.name == companyName }
    }
    
    /// Toggle save state for a company
    func toggleSaveCompany(_ companyName: String, productCount: Int? = nil, imageUrl: String? = nil, category: String? = nil) {
        if isCompanySaved(companyName) {
            removeSavedCompany(companyName)
        } else {
            saveCompany(companyName, productCount: productCount, imageUrl: imageUrl, category: category)
        }
    }
    
    /// Save a company to favorites
    func saveCompany(_ companyName: String, productCount: Int? = nil, imageUrl: String? = nil, category: String? = nil) {
        guard !isCompanySaved(companyName) else {
            return
        }
        
        let savedCompany = SavedCompany(name: companyName, productCount: productCount, imageUrl: imageUrl, category: category)
        savedCompanies.append(savedCompany)
        saveLocalCompanies()
        
        Log.debug("Saved company: \(companyName)", category: .storage)
    }
    
    /// Update cached image and category for a saved company (called after lazy fetch)
    func updateCachedImage(for companyName: String, imageUrl: String?, category: String?) {
        if let index = savedCompanies.firstIndex(where: { $0.name == companyName }) {
            savedCompanies[index].cachedImageUrl = imageUrl
            savedCompanies[index].cachedCategory = category
            saveLocalCompanies()
        }
    }
    
    /// Remove a saved company
    func removeSavedCompany(_ companyName: String) {
        savedCompanies.removeAll { $0.name == companyName }
        saveLocalCompanies()
        
        Log.debug("Removed saved company: \(companyName)", category: .storage)
    }
    
    /// Update product count for a saved company
    func updateProductCount(for companyName: String, count: Int) {
        if let index = savedCompanies.firstIndex(where: { $0.name == companyName }) {
            savedCompanies[index].productCount = count
            saveLocalCompanies()
        }
    }
    
    /// Get saved companies sorted by date (most recent first)
    var sortedByDate: [SavedCompany] {
        return savedCompanies.sorted { $0.dateSaved > $1.dateSaved }
    }
    
    /// Get saved companies sorted alphabetically
    var sortedAlphabetically: [SavedCompany] {
        return savedCompanies.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}

// MARK: - Preview Helper

extension SavedCompaniesManager {
    static func preview() -> SavedCompaniesManager {
        let manager = SavedCompaniesManager()
        manager.savedCompanies = [
            SavedCompany(name: "Fenty Beauty", productCount: 45),
            SavedCompany(name: "Pattern Beauty", productCount: 28),
            SavedCompany(name: "The Honey Pot Company", productCount: 32)
        ]
        return manager
    }
}
