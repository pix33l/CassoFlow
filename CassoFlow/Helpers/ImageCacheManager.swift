import SwiftUI
import Foundation

/// 图片缓存管理器
@MainActor
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()
    
    // 内存缓存
    private var imageCache: [String: UIImage] = [:]
    private let maxCacheSize = 100 // 最大缓存数量
    
    // 正在下载的URL集合，避免重复下载
    private var downloadingURLs: Set<String> = []
    
    private init() {}
    
    /// 获取缓存的图片
    func getCachedImage(for url: URL) -> UIImage? {
        return imageCache[url.absoluteString]
    }
    
    /// 预加载图片
    func preloadImage(from url: URL) {
        let urlString = url.absoluteString
        
        // 如果已经缓存或正在下载，直接返回
        if imageCache[urlString] != nil || downloadingURLs.contains(urlString) {
            return
        }
        
        // 标记为正在下载
        downloadingURLs.insert(urlString)
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    // 优化图片处理，避免色彩配置文件问题
                    let processedImage = self.processImage(image)
                    // 缓存图片
                    self.cacheImage(processedImage, for: urlString)
                    // 从下载集合中移除
                    self.downloadingURLs.remove(urlString)
                }
            } catch {
                self.downloadingURLs.remove(urlString)
            }
        }
    }
    
    /// 处理图片，修复色彩配置文件问题
    private func processImage(_ image: UIImage) -> UIImage {
        // 创建一个新的图形上下文来重绘图片，这样可以去除有问题的色彩配置文件
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let processedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return processedImage
    }
    
    /// 缓存图片
    private func cacheImage(_ image: UIImage, for urlString: String) {
        // 如果缓存已满，移除最旧的一些项目
        if imageCache.count >= maxCacheSize {
            let keysToRemove = Array(imageCache.keys.prefix(maxCacheSize / 4))
            for key in keysToRemove {
                imageCache.removeValue(forKey: key)
            }
        }
        
        imageCache[urlString] = image
    }
    
    /// 清理缓存
    func clearCache() {
        imageCache.removeAll()
        downloadingURLs.removeAll()
    }
}

/// 缓存图片视图组件
struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: () -> AnyView
    let content: (Image) -> AnyView
    
    @StateObject private var cacheManager = ImageCacheManager.shared
    @State private var cachedImage: UIImage?
    
    init(
        url: URL?,
        @ViewBuilder placeholder: @escaping () -> some View,
        @ViewBuilder content: @escaping (Image) -> some View
    ) {
        self.url = url
        self.placeholder = { AnyView(placeholder()) }
        self.content = { image in AnyView(content(image)) }
    }
    
    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                content(Image(uiImage: cachedImage))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        // 先检查缓存
        if let cached = cacheManager.getCachedImage(for: url) {
            cachedImage = cached
            return
        }
        
        // 预加载图片
        cacheManager.preloadImage(from: url)
        
        // 监听缓存更新
        Task {
            // 增加超时机制，避免无限等待
            let maxWaitTime = 10.0 // 最长等待10秒
            let startTime = Date()
            
            while cachedImage == nil {
                if let cached = cacheManager.getCachedImage(for: url) {
                    await MainActor.run {
                        cachedImage = cached
                    }
                    break
                }
                
                // 检查是否超时
                if Date().timeIntervalSince(startTime) > maxWaitTime {
                    break
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
        }
    }
}