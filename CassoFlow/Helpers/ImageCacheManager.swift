import SwiftUI
import Foundation

/// 图片缓存管理器
@MainActor
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()
    
    // 内存缓存
    private var imageCache: [String: UIImage] = [:]
    private let maxMemoryCacheSize = 50 // 内存缓存数量限制
    
    // 持久化缓存目录
    private let diskCacheDirectory: URL
    private let maxDiskCacheSize: Int = 200 * 1024 * 1024 // 200MB磁盘缓存限制
    
    // 正在下载的URL集合，避免重复下载
    private var downloadingURLs: Set<String> = []
    
    private init() {
        // 创建磁盘缓存目录
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDirectory = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)
        
        // 确保缓存目录存在
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
        
        // 启动时清理过期的磁盘缓存
        Task {
            await cleanExpiredDiskCache()
        }
        
        print("📁 图片缓存目录: \(diskCacheDirectory.path)")
    }
    
    /// 生成缓存文件名
    private func cacheFileName(for urlString: String) -> String {
        return urlString.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-") ?? ""
    }
    
    /// 获取磁盘缓存文件URL
    private func diskCacheURL(for urlString: String) -> URL {
        let fileName = cacheFileName(for: urlString) + ".jpg"
        return diskCacheDirectory.appendingPathComponent(fileName)
    }
    
    /// 获取缓存的图片
    func getCachedImage(for url: URL) -> UIImage? {
        let urlString = url.absoluteString
        
        // 先检查内存缓存
        if let memoryImage = imageCache[urlString] {
            return memoryImage
        }
        
        // 检查磁盘缓存
        let diskURL = diskCacheURL(for: urlString)
        if FileManager.default.fileExists(atPath: diskURL.path),
           let imageData = try? Data(contentsOf: diskURL),
           let diskImage = UIImage(data: imageData) {
            
            // 将磁盘缓存加载到内存缓存
            cacheImageInMemory(diskImage, for: urlString)
            print("💿 从磁盘加载图片: \(url)")
            return diskImage
        }
        
        return nil
    }
    
    /// 预加载图片
    func preloadImage(from url: URL) {
        let urlString = url.absoluteString
        
        // 如果已经缓存或正在下载，直接返回
        if getCachedImage(for: url) != nil || downloadingURLs.contains(urlString) {
            return
        }
        
        // 标记为正在下载
        downloadingURLs.insert(urlString)
        
        Task {
            do {
                print("🎨 ImageCacheManager: 开始下载图片: \(url)")
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                // 检查HTTP响应状态
                if let httpResponse = response as? HTTPURLResponse {
                    print("🎨 ImageCacheManager: HTTP状态码: \(httpResponse.statusCode)")
                    print("🎨 ImageCacheManager: Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "未知")")
                    print("🎨 ImageCacheManager: 响应数据大小: \(data.count) bytes")
                    
                    guard httpResponse.statusCode == 200 else {
                        let errorContent = String(data: data.prefix(500), encoding: .utf8) ?? "无法解析响应内容"
                        print("❌ ImageCacheManager: HTTP错误 \(httpResponse.statusCode): \(errorContent)")
                        throw URLError(.badServerResponse)
                    }
                    
                    // 检查Content-Type
                    let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
                    
                    // AudioStation封面API可能返回JSON错误而不是图片
                    if contentType.contains("application/json") {
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
                
                // 检查数据是否为空或太小
                guard data.count > 100 else {
                    print("❌ ImageCacheManager: 数据太小，可能不是有效的图片数据，大小: \(data.count)")
                    throw URLError(.cannotDecodeContentData)
                }
                
                // 尝试创建UIImage
                guard let image = UIImage(data: data) else {
                    print("❌ ImageCacheManager: 无法从数据创建UIImage，数据大小: \(data.count)")
                    let dataHeader = data.prefix(20).map { String(format: "%02x", $0) }.joined(separator: " ")
                    print("❌ ImageCacheManager: 数据头部: \(dataHeader)")
                    
                    let jpegHeader = data.starts(with: [0xFF, 0xD8])
                    let pngHeader = data.starts(with: [0x89, 0x50, 0x4E, 0x47])
                    let gifHeader = data.starts(with: [0x47, 0x49, 0x46])
                    
                    print("❌ ImageCacheManager: 格式检查 - JPEG: \(jpegHeader), PNG: \(pngHeader), GIF: \(gifHeader)")
                    
                    throw URLError(.cannotDecodeContentData)
                }
                
                print("✅ ImageCacheManager: 图片解析成功，尺寸: \(image.size)")
                
                // 优化图片处理
                let processedImage = self.processImage(image)
                
                // 同时缓存到内存和磁盘
                await self.cacheImage(processedImage, for: urlString, originalData: data)
                
            } catch {
                print("❌ ImageCacheManager: 图片加载失败: \(url) - \(error)")
                if let urlError = error as? URLError {
                    print("❌ ImageCacheManager: URLError详情: \(urlError.localizedDescription)")
                }
                
                // AudioStation特殊处理：如果是Authentication错误，记录会话可能过期
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
    
    /// 缓存图片到内存
    private func cacheImageInMemory(_ image: UIImage, for urlString: String) {
        // 如果内存缓存已满，移除最旧的一些项目
        if imageCache.count >= maxMemoryCacheSize {
            let keysToRemove = Array(imageCache.keys.prefix(maxMemoryCacheSize / 4))
            for key in keysToRemove {
                imageCache.removeValue(forKey: key)
            }
            print("🧹 ImageCacheManager: 清理了 \(keysToRemove.count) 个内存缓存")
        }
        
        imageCache[urlString] = image
    }
    
    /// 缓存图片到内存和磁盘
    private func cacheImage(_ image: UIImage, for urlString: String, originalData: Data) async {
        await MainActor.run {
            // 缓存到内存
            self.cacheImageInMemory(image, for: urlString)
            print("✅ ImageCacheManager: 图片已缓存到内存，当前缓存数量: \(self.imageCache.count)")
        }
        
        // 异步缓存到磁盘
        Task.detached {
            do {
                let diskURL = await self.diskCacheURL(for: urlString)
                
                // 将图片转换为JPEG格式以节省空间
                let quality: CGFloat = 0.8
                if let jpegData = image.jpegData(compressionQuality: quality) {
                    try jpegData.write(to: diskURL)
                    print("💿 图片已缓存到磁盘: \(diskURL.lastPathComponent)")
                    
                    // 检查磁盘缓存大小
                    await self.manageDiskCacheSize()
                } else {
                    print("❌ 无法将图片转换为JPEG格式")
                }
            } catch {
                print("❌ 磁盘缓存失败: \(error)")
            }
        }
    }
    
    /// 管理磁盘缓存大小
    private func manageDiskCacheSize() async {
        do {
            let fileManager = FileManager.default
            let cacheFiles = try fileManager.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            // 计算总缓存大小
            var totalSize = 0
            var fileInfos: [(url: URL, size: Int, date: Date)] = []
            
            for fileURL in cacheFiles {
                let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let size = attributes.fileSize ?? 0
                let date = attributes.creationDate ?? Date.distantPast
                
                totalSize += size
                fileInfos.append((url: fileURL, size: size, date: date))
            }
            
            print("💿 磁盘缓存统计 - 文件数: \(fileInfos.count), 总大小: \(totalSize / 1024 / 1024)MB")
            
            // 如果超过限制，删除最旧的文件
            if totalSize > maxDiskCacheSize {
                // 按创建时间排序
                fileInfos.sort { $0.date < $1.date }
                
                var deletedSize = 0
                let targetSize = maxDiskCacheSize * 3 / 4 // 删除到75%
                
                for fileInfo in fileInfos {
                    if totalSize - deletedSize <= targetSize {
                        break
                    }
                    
                    try fileManager.removeItem(at: fileInfo.url)
                    deletedSize += fileInfo.size
                    print("🗑️ 删除过期缓存: \(fileInfo.url.lastPathComponent)")
                }
                
                print("🧹 磁盘缓存清理完成 - 删除: \(deletedSize / 1024 / 1024)MB")
            }
            
        } catch {
            print("❌ 磁盘缓存管理失败: \(error)")
        }
    }
    
    /// 清理过期的磁盘缓存
    private func cleanExpiredDiskCache() async {
        do {
            let fileManager = FileManager.default
            let cacheFiles = try fileManager.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            let expirationInterval: TimeInterval = 7 * 24 * 60 * 60 // 7天过期
            let expirationDate = Date().addingTimeInterval(-expirationInterval)
            
            var deletedCount = 0
            
            for fileURL in cacheFiles {
                let attributes = try fileURL.resourceValues(forKeys: [.creationDateKey])
                let creationDate = attributes.creationDate ?? Date.distantPast
                
                if creationDate < expirationDate {
                    try fileManager.removeItem(at: fileURL)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                print("🧹 清理了 \(deletedCount) 个过期的磁盘缓存文件")
            }
            
        } catch {
            print("❌ 清理过期磁盘缓存失败: \(error)")
        }
    }
    
    /// 检查是否正在下载
    func isDownloading(_ url: URL) -> Bool {
        return downloadingURLs.contains(url.absoluteString)
    }
    
    /// 清理缓存
    func clearCache() {
        // 清理内存缓存
        imageCache.removeAll()
        downloadingURLs.removeAll()
        
        // 清理磁盘缓存
        let diskDirectory = diskCacheDirectory
        Task.detached {
            do {
                let fileManager = FileManager.default
                try fileManager.removeItem(at: diskDirectory)
                try fileManager.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
                print("🗑️ 所有图片缓存已清理")
            } catch {
                print("❌ 清理磁盘缓存失败: \(error)")
            }
        }
    }
    
    /// 获取缓存统计信息
    func getCacheStats() -> (memoryCount: Int, diskSizeMB: Double) {
        let memoryCount = imageCache.count
        
        var diskSizeMB: Double = 0
        do {
            let fileManager = FileManager.default
            let cacheFiles = try fileManager.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            var totalSize = 0
            for fileURL in cacheFiles {
                let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += attributes.fileSize ?? 0
            }
            
            diskSizeMB = Double(totalSize) / 1024 / 1024
        } catch {
            print("❌ 获取磁盘缓存统计失败: \(error)")
        }
        
        return (memoryCount, diskSizeMB)
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
            // URL变化时重新加载
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
        
        // 先检查缓存（包括内存和磁盘）
        if let cached = cacheManager.getCachedImage(for: imageURL) {
            print("🎨 CachedAsyncImage: 使用缓存图片: \(imageURL)")
            cachedImage = cached
            return
        }
        
        // 检查是否正在下载
        if cacheManager.isDownloading(imageURL) {
            print("🎨 CachedAsyncImage: 图片正在下载中: \(imageURL)")
            isLoading = true
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
            // 等待下载完成，最多等待30秒
            let maxWaitTime = 30.0
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
