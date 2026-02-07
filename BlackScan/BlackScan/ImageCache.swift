import SwiftUI

/// Image cache manager for faster loading
class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    /// Clear entire cache
    func clearAll() {
        cache.removeAllObjects()
    }
}

/// Cached async image view with URL validation and proper task cancellation
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var loadTask: Task<Void, Never>?
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
                    .onDisappear {
                        // Cancel in-flight request when view disappears (prevents memory leaks)
                        loadTask?.cancel()
                        loadTask = nil
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        // Validate URL is HTTPS (security: prevent loading from untrusted sources)
        guard InputValidator.isImageURLTrusted(url.absoluteString) else {
            Log.warning("Blocked untrusted image URL", category: .network)
            return
        }
        
        // Check cache first
        if let cached = ImageCache.shared.get(forKey: url.absoluteString) {
            self.image = cached
            return
        }
        
        // Cancel any existing load
        loadTask?.cancel()
        
        // Load from network using async/await with proper cancellation
        loadTask = Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                // Check for cancellation
                guard !Task.isCancelled else { return }
                
                // Validate response
                guard let httpResponse = response as? HTTPURLResponse,
                      200...299 ~= httpResponse.statusCode else {
                    return
                }
                
                // Validate content type
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                   !contentType.hasPrefix("image/") {
                    return
                }
                
                guard let downloadedImage = UIImage(data: data) else {
                    return
                }
                
                // Cache the image
                ImageCache.shared.set(downloadedImage, forKey: url.absoluteString)
                
                // Update UI on main thread
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.image = downloadedImage
                }
            } catch {
                // Silently handle cancellation and network errors
                if !Task.isCancelled {
                    Log.debug("Image load failed for URL", category: .network)
                }
            }
        }
    }
}
