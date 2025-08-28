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
                print("🎨 ImageCacheManager: 开始下载图片: \(url)")
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                // 🔧 检查HTTP响应状态
                if let httpResponse = response as? HTTPURLResponse {
                    print("🎨 ImageCacheManager: HTTP状态码: \(httpResponse.statusCode)")
                    print("🎨 ImageCacheManager: Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "未知")")
                    print("🎨 ImageCacheManager: 响应数据大小: \(data.count) bytes")
                    
                    guard httpResponse.statusCode == 200 else {
                        // 打印错误响应内容（前500字符）
                        let errorContent = String(data: data.prefix(500), encoding: .utf8) ?? "无法解析响应内容"
                        print("❌ ImageCacheManager: HTTP错误 \(httpResponse.statusCode): \(errorContent)")
                        throw URLError(.badServerResponse)
                    }
                    
                    // 🔧 检查Content-Type，AudioStation可能返回其他格式
                    let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
                    
                    // 🔧 AudioStation封面API可能返回JSON错误而不是图片
                    if contentType.contains("application/json") {
                        // 尝试解析JSON错误响应
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("❌ ImageCacheManager: 收到JSON响应而不是图片: \(json)")
                            
                            if let success = json["success"] as? Bool, !success {
                                if let error = json["error"] as? [String: Any],
                                   let message = error["message"] as? String {
                                    print("❌ ImageCacheManager: API错误: \(message)")
                                }
                            }
                        }
                        throw URLError(.badServerResponse)
                    }
                    
                    // 允许的图片Content-Type
                    let validImageTypes = ["image/", "application/octet-stream", "binary/octet-stream"]
                    let isValidImageType = validImageTypes.contains { contentType.hasPrefix($0) } || contentType.isEmpty
                    
                    guard isValidImageType else {
                        let errorContent = String(data: data.prefix(500), encoding: .utf8) ?? "无法解析响应内容"
                        print("❌ ImageCacheManager: 错误的Content-Type '\(contentType)': \(errorContent)")
                        throw URLError(.badServerResponse)
                    }
                }
                
                // 🔧 检查数据是否为空或太小
                guard data.count > 100 else {
                    print("❌ ImageCacheManager: 数据太小，可能不是有效的图片数据，大小: \(data.count)")
                    throw URLError(.cannotDecodeContentData)
                }
                
                // 尝试创建UIImage
                guard let image = UIImage(data: data) else {
                    print("❌ ImageCacheManager: 无法从数据创建UIImage，数据大小: \(data.count)")
                    // 尝试打印数据的前几个字节，看是否是图片格式
                    let dataHeader = data.prefix(20).map { String(format: "%02x", $0) }.joined(separator: " ")
                    print("❌ ImageCacheManager: 数据头部: \(dataHeader)")
                    
                    // 检查是否是常见的图片格式头部
                    let jpegHeader = data.starts(with: [0xFF, 0xD8])
                    let pngHeader = data.starts(with: [0x89, 0x50, 0x4E, 0x47])
                    let gifHeader = data.starts(with: [0x47, 0x49, 0x46])
                    
                    print("❌ ImageCacheManager: 格式检查 - JPEG: \(jpegHeader), PNG: \(pngHeader), GIF: \(gifHeader)")
                    
                    throw URLError(.cannotDecodeContentData)
                }
                
                print("✅ ImageCacheManager: 图片解析成功，尺寸: \(image.size)")
                
                // 优化图片处理，避免色彩配置文件问题
                let processedImage = self.processImage(image)
                
                // 缓存图片
                await self.cacheImage(processedImage, for: urlString)
                
            } catch {
                print("❌ ImageCacheManager: 图片加载失败: \(url) - \(error)")
                if let urlError = error as? URLError {
                    print("❌ ImageCacheManager: URLError详情: \(urlError.localizedDescription)")
                }
                
                // 🔧 AudioStation特殊处理：如果是Authentication错误，记录会话可能过期
                if urlString.contains("AudioStation") && urlString.contains("_sid=") {
                    print("⚠️ ImageCacheManager: AudioStation图片加载失败，可能是会话过期")
                }
            }
            
            // 从下载集合中移除
            _ = await MainActor.run {
                self.downloadingURLs.remove(urlString)
            }
        }
    }
    
    /// 处理图片，修复色彩配置文件问题
    private func processImage(_ image: UIImage) -> UIImage {
        print("🎨 ImageCacheManager: 处理图片，原始尺寸: \(image.size)")
        
        // 创建一个新的图形上下文来重绘图片，这样可以去除有问题的色彩配置文件
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        
        defer {
            UIGraphicsEndImageContext()
        }
        
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let processedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        
        print("✅ ImageCacheManager: 图片处理完成，处理后尺寸: \(processedImage.size)")
        return processedImage
    }
    
    /// 缓存图片
    private func cacheImage(_ image: UIImage, for urlString: String) async {
        await MainActor.run {
            // 如果缓存已满，移除最旧的一些项目
            if self.imageCache.count >= self.maxCacheSize {
                let keysToRemove = Array(self.imageCache.keys.prefix(self.maxCacheSize / 4))
                for key in keysToRemove {
                    self.imageCache.removeValue(forKey: key)
                }
                print("🧹 ImageCacheManager: 清理了 \(keysToRemove.count) 个旧缓存")
            }
            
            self.imageCache[urlString] = image
            print("✅ ImageCacheManager: 图片已缓存，当前缓存数量: \(self.imageCache.count)")
        }
    }
    
    /// 检查是否正在下载
    func isDownloading(_ url: URL) -> Bool {
        return downloadingURLs.contains(url.absoluteString)
    }
    
    /// 清理缓存
    func clearCache() {
        imageCache.removeAll()
        downloadingURLs.removeAll()
        print("🧹 ImageCacheManager: 所有缓存已清理")
    }
}

/// 改进的缓存图片视图组件
struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: () -> AnyView
    let content: (Image) -> AnyView
    
    @StateObject private var cacheManager = ImageCacheManager.shared
    @State private var cachedImage: UIImage?
    @State private var isLoading = false
    
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
            } else if isLoading {
                placeholder()
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else {
                placeholder()
            }
        }
        .onChange(of: url) { _, newURL in
            // 🔧 关键改进：URL变化时重新加载
            loadImage(from: newURL)
        }
        .onAppear {
            loadImage(from: url)
        }
    }
    
    private func loadImage(from imageURL: URL?) {
        // 重置状态
        cachedImage = nil
        isLoading = false
        
        guard let imageURL = imageURL else {
            print("🎨 CachedAsyncImage: URL为空")
            return
        }
        
        print("🎨 CachedAsyncImage: 开始加载图片: \(imageURL)")
        
        // 先检查缓存
        if let cached = cacheManager.getCachedImage(for: imageURL) {
            print("🎨 CachedAsyncImage: 使用缓存图片: \(imageURL)")
            cachedImage = cached
            return
        }
        
        // 检查是否正在下载
        if cacheManager.isDownloading(imageURL) {
            print("🎨 CachedAsyncImage: 图片正在下载中: \(imageURL)")
            isLoading = true
            // 等待下载完成
            waitForDownload(url: imageURL)
            return
        }
        
        // 开始新的下载
        isLoading = true
        print("🎨 CachedAsyncImage: 开始预加载图片: \(imageURL)")
        cacheManager.preloadImage(from: imageURL)
        
        // 等待下载完成
        waitForDownload(url: imageURL)
    }
    
    private func waitForDownload(url: URL) {
        Task {
            // 等待下载完成，最多等待20秒
            let maxWaitTime = 20.0
            let startTime = Date()
            let checkInterval: UInt64 = 200_000_000 // 0.2秒
            
            while Date().timeIntervalSince(startTime) < maxWaitTime {
                if let cached = cacheManager.getCachedImage(for: url) {
                    await MainActor.run {
                        print("🎨 CachedAsyncImage: 下载完成: \(url)")
                        cachedImage = cached
                        isLoading = false
                    }
                    return
                }
                
                // 如果不再下载中，说明下载失败
                if !cacheManager.isDownloading(url) {
                    await MainActor.run {
                        print("❌ CachedAsyncImage: 下载失败或完成但未缓存: \(url)")
                        isLoading = false
                    }
                    return
                }
                
                try? await Task.sleep(nanoseconds: checkInterval)
            }
            
            // 超时处理
            await MainActor.run {
                print("⏱️ CachedAsyncImage: 下载超时: \(url)")
                isLoading = false
            }
        }
    }
}
