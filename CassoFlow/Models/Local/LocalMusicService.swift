import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// 本地音乐项目
struct LocalMusicItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let artwork: Data? // 封面图片数据
    let trackNumber: Int? // 音轨号
    let year: Int? // 年份信息
    let genre: String? // 流派信息
    
    init(url: URL) async {
        self.url = url
        
        // 使用AVAsset获取音乐元数据
        let asset = AVAsset(url: url)
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "未知艺术家"
        var album = "未知专辑"
        var duration: TimeInterval = 0
        var artwork: Data?
        var trackNumber: Int?
        var year: Int?
        var genre: String?
        
        // 🔑 修复：改进时长获取方法，特别针对FLAC文件
        do {
            let durationValue = try await asset.load(.duration)
            if CMTIME_IS_VALID(durationValue) && !CMTIME_IS_INDEFINITE(durationValue) {
                let durationSeconds = CMTimeGetSeconds(durationValue)
                if durationSeconds.isFinite && !durationSeconds.isNaN && durationSeconds > 0 {
                    duration = durationSeconds
                } else {
                    print("⚠️ 无效的时长值: \(durationSeconds)，文件: \(url.lastPathComponent)")
                    // 🔑 尝试通过文件大小估算时长（仅用于FLAC等特殊格式）
                    duration = await LocalMusicItem.estimateDurationFromFileSize(url: url)
                }
            } else {
                print("⚠️ 时长不可用，文件: \(url.lastPathComponent)")
                duration = await LocalMusicItem.estimateDurationFromFileSize(url: url)
            }
        } catch {
            print("❌ 获取音频时长失败: \(error) - 文件: \(url.lastPathComponent)")
            duration = await LocalMusicItem.estimateDurationFromFileSize(url: url)
        }
        
        // 🔑 修复：改进元数据获取，支持FLAC的Vorbis Comments
        do {
            let metadata = try await asset.load(.commonMetadata)
            
            // 首先尝试commonKey（适用于大部分格式）
            for item in metadata {
                guard let key = item.commonKey?.rawValue else { continue }
                
                let value: Any?
                do {
                    value = try await item.load(.value)
                } catch {
                    print("⚠️ 加载元数据项值失败: \(error) - 键: \(key)")
                    continue
                }
                
                guard let value = value else { continue }
                
                switch key {
                case "title":
                    if let stringValue = value as? String, !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        title = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case "artist":
                    if let stringValue = value as? String, !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        artist = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case "albumName":
                    if let stringValue = value as? String, !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        album = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case "artwork":
                    if let imageData = value as? Data, !imageData.isEmpty {
                        artwork = imageData
                    }
                case "trackNumber":
                    if let numberValue = value as? NSNumber {
                        trackNumber = numberValue.intValue
                    } else if let stringValue = value as? String, let number = Int(stringValue) {
                        trackNumber = number
                    }
                case "creationDate":
                    year = LocalMusicItem.parseYearFromDate(value)
                case "genre":
                    if let stringValue = value as? String, !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        genre = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                default:
                    break
                }
            }
            
            // 🔑 新增：如果commonKey没有获取到信息，尝试使用format-specific keys（特别适用于FLAC）
            if artist == "未知艺术家" || album == "未知专辑" || title == url.deletingPathExtension().lastPathComponent || trackNumber == nil {
                await LocalMusicItem.tryFormatSpecificMetadata(asset: asset, url: url, title: &title, artist: &artist, album: &album, trackNumber: &trackNumber, year: &year, genre: &genre, artwork: &artwork)
            }
            
        } catch {
            print("❌ 获取元数据失败: \(error) - 文件: \(url.lastPathComponent)")
            // 即使获取元数据失败，也使用默认值
        }
        
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artwork = artwork
        self.trackNumber = trackNumber
        self.year = year
        self.genre = genre
        
        // 🔑 添加调试信息
        print("🎵 解析音乐文件: \(url.lastPathComponent)")
        print("   标题: \(title)")
        print("   艺术家: \(artist)")
        print("   专辑: \(album)")
        print("   时长: \(duration)秒")
        print("   音轨号: \(trackNumber ?? 0)")
        print("   年份: \(year ?? 0)")
        print("   风格: \(genre ?? "无")")
        print("   封面: \(artwork != nil ? "有" : "无")")
    }
    
    // 🔑 新增：通过文件大小估算时长的方法
    private static func estimateDurationFromFileSize(url: URL) async -> TimeInterval {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = fileAttributes[FileAttributeKey.size] as? Int64 {
                // 根据文件格式和大小粗略估算时长
                let fileExtension = url.pathExtension.lowercased()
                let estimatedBitrate: Double
                
                switch fileExtension {
                case "flac":
                    estimatedBitrate = 1000 * 1024 // FLAC约1000 kbps
                case "wav", "aiff":
                    estimatedBitrate = 1411 * 1024 // 无损CD质量
                case "mp3":
                    estimatedBitrate = 320 * 1024  // 高质量MP3
                case "m4a", "aac":
                    estimatedBitrate = 256 * 1024  // 高质量AAC
                default:
                    estimatedBitrate = 320 * 1024  // 默认值
                }
                
                let estimatedDuration = Double(fileSize * 8) / estimatedBitrate // 转换为秒
                print("⚠️ 通过文件大小估算时长: \(estimatedDuration)秒，文件: \(url.lastPathComponent)")
                return max(1.0, estimatedDuration) // 至少1秒
            }
        } catch {
            print("❌ 获取文件大小失败: \(error)")
        }
        
        // 如果无法估算，返回默认值3分钟
        return 180.0
    }
    
    // 🔑 新增：尝试使用format-specific metadata keys
    private static func tryFormatSpecificMetadata(asset: AVAsset, url: URL, title: inout String, artist: inout String, album: inout String, trackNumber: inout Int?, year: inout Int?, genre: inout String?, artwork: inout Data?) async {
        do {
            // 获取所有可用的metadata
            let allMetadata = try await asset.load(.metadata)
            
            for item in allMetadata {
                // 尝试获取key标识符
                let key: String?
                if let commonKey = item.commonKey?.rawValue {
                    key = commonKey
                } else if let identifierKey = item.identifier?.rawValue {
                    key = identifierKey
                } else if let keySpace = item.keySpace?.rawValue,
                          let keyString = item.key as? String {
                    key = "\(keySpace)/\(keyString)"
                } else {
                    continue
                }
                
                guard let metadataKey = key else { continue }
                
                // 加载值
                let value: Any?
                do {
                    value = try await item.load(.value)
                } catch {
                    continue
                }
                
                guard let metadataValue = value else { continue }
                
                // 🔑 扩展的key匹配（支持FLAC/Vorbis Comments的常见字段）
                let lowercaseKey = metadataKey.lowercased()
                
                if (lowercaseKey.contains("title") || lowercaseKey.contains("tit2")) && title == url.deletingPathExtension().lastPathComponent {
                    if let stringValue = metadataValue as? String, !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        title = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                if (lowercaseKey.contains("artist") || lowercaseKey.contains("tpe1") || lowercaseKey.contains("albumartist") || lowercaseKey.contains("tpe2")) && artist == "未知艺术家" {
                    if let stringValue = metadataValue as? String, !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        artist = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                if (lowercaseKey.contains("album") || lowercaseKey.contains("talb")) && album == "未知专辑" {
                    if let stringValue = metadataValue as? String, !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        album = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                // 🔑 增强音轨号识别 - 支持更多格式
                if (lowercaseKey.contains("track") || lowercaseKey.contains("trck") || lowercaseKey.contains("tracknumber") || lowercaseKey == "trkn") && trackNumber == nil {
                    
                    if let numberValue = metadataValue as? NSNumber {
                        trackNumber = numberValue.intValue
                        print("🎵 找到音轨号 (NSNumber): \(trackNumber!) - key: \(metadataKey)")
                    } else if let stringValue = metadataValue as? String {
                        // 处理"3/12"这样的格式
                        let components = stringValue.components(separatedBy: "/")
                        if let number = Int(components.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") {
                            trackNumber = number
                            print("🎵 找到音轨号 (String): \(trackNumber!) - key: \(metadataKey)")
                        }
                    } else if let dataValue = metadataValue as? Data {
                        // 有些格式可能将音轨号存储为二进制数据
                        if dataValue.count == 4 {
                            let trackNum = dataValue.withUnsafeBytes { bytes in
                                return bytes.load(as: UInt32.self).bigEndian
                            }
                            if trackNum > 0 && trackNum < 1000 { // 合理范围内的音轨号
                                trackNumber = Int(trackNum)
                                print("🎵 找到音轨号 (Data): \(trackNumber!) - key: \(metadataKey)")
                            }
                        }
                    }
                }
                
                if (lowercaseKey.contains("date") || lowercaseKey.contains("year") || lowercaseKey.contains("tyer")) && year == nil {
                    year = parseYearFromDate(metadataValue)
                }
                
                if (lowercaseKey.contains("genre") || lowercaseKey.contains("tcon")) && genre == nil {
                    if let stringValue = metadataValue as? String, !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        genre = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                if (lowercaseKey.contains("artwork") || lowercaseKey.contains("apic") || lowercaseKey.contains("covr")) && artwork == nil {
                    if let imageData = metadataValue as? Data, !imageData.isEmpty {
                        artwork = imageData
                    }
                }
                
                // 打印调试信息
                print("📋 发现元数据: \(metadataKey) = \(String(describing: metadataValue).prefix(100))")
            }
            
        } catch {
            print("❌ 尝试格式特定元数据失败: \(error)")
        }
    }
    
    // 🔑 改进：年份解析方法
    private static func parseYearFromDate(_ value: Any) -> Int? {
        if let dateString = value as? String {
            // 尝试解析各种日期格式
            let yearPatterns = [
                "yyyy-MM-dd",
                "yyyy-MM",
                "yyyy"
            ]
            
            let dateFormatter = DateFormatter()
            for pattern in yearPatterns {
                dateFormatter.dateFormat = pattern
                if let date = dateFormatter.date(from: dateString) {
                    return Calendar.current.component(.year, from: date)
                }
            }
            
            // 如果格式不匹配，尝试提取4位数字年份
            if let range = dateString.range(of: "\\b(19|20)\\d{2}\\b", options: .regularExpression),
               let yearInt = Int(String(dateString[range])) {
                return yearInt
            }
            
        } else if let date = value as? Date {
            return Calendar.current.component(.year, from: date)
        } else if let number = value as? NSNumber {
            let yearInt = number.intValue
            if yearInt > 1900 && yearInt < 3000 {
                return yearInt
            }
        }
        
        return nil
    }
}

// MARK: - 🔑 新增：本地歌曲项目（用于删除功能）
struct LocalSongItem: Identifiable, Hashable {
    let id: String
    let title: String
    let artistName: String
    let albumName: String?
    let filePath: String
    let duration: TimeInterval
    let artworkData: Data?
    
    init(from localMusicItem: LocalMusicItem) {
        self.id = localMusicItem.id.uuidString
        self.title = localMusicItem.title
        self.artistName = localMusicItem.artist
        self.albumName = localMusicItem.album
        self.filePath = localMusicItem.url.path // 🔑 修复：使用path而不是absoluteString
        self.duration = localMusicItem.duration
        self.artworkData = localMusicItem.artwork
    }
}

// MARK: - 扩展以符合UniversalSong协议
extension LocalMusicItem {
    /// 转换为UniversalSong以兼容通用播放接口
    func toUniversalSong() -> UniversalSong {
        // 🔑 创建LocalSongItem作为originalData
        let localSongItem = LocalSongItem(from: self)
        
        return UniversalSong(
            id: self.id.uuidString,
            title: self.title,
            artistName: self.artist,
            albumName: self.album,
            duration: self.duration,
            trackNumber: self.trackNumber,
            artworkURL: nil, // 本地文件没有远程URL
            streamURL: self.url, // 本地文件URL作为streamURL
            source: .local,
            originalData: localSongItem // 🔑 使用LocalSongItem作为originalData
        )
    }
}

/// 本地专辑项目
struct LocalAlbumItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let artist: String
    let artworkData: Data?
    let songs: [LocalMusicItem]
    
    var artwork: UIImage? {
        guard let data = artworkData else { return nil }
        return UIImage(data: data)
    }
    
    // 🔑 新增：专辑名称属性（用于删除功能）
    var albumName: String {
        return title
    }
    
    var artistName: String {
        return artist
    }
}

/// 本地音乐服务管理器
class LocalMusicService: NSObject, ObservableObject, NowPlayingDelegate {
    static let shared = LocalMusicService()
    
    // MARK: - 属性
    
    @Published var isConnected: Bool = true // 本地音乐始终连接
    @Published var isAvailable: Bool = true // 本地音乐始终可用
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    // 队列管理
    @Published var currentQueue: [UniversalSong] = []
    @Published var currentIndex: Int = 0
    
    // 播放模式
    @Published var isShuffleEnabled: Bool = false {
        didSet {
            if isShuffleEnabled && !oldValue {
                // 启用随机播放时，保存原始队列并打乱当前队列
                saveOriginalQueue()
                shuffleCurrentQueue()
            } else if !isShuffleEnabled && oldValue {
                // 禁用随机播放时，恢复原始队列
                restoreOriginalQueue()
            }
        }
    }
    
    @Published var repeatMode: LocalRepeatMode = .none
    
    // 私有属性
    private var avPlayer: AVPlayer?
    private var avPlayerObserver: Any?
    internal var currentSong: UniversalSong?
    private var originalQueue: [UniversalSong] = []  // 保存原始队列顺序
    private var originalIndex: Int = 0              // 保存原始播放位置
    
    // 本地音乐文件列表
    @Published var localSongs: [LocalMusicItem] = []
    @Published var localAlbums: [LocalAlbumItem] = []
    @Published var isLoadingLocalMusic = false
    
    // 🔑 新增：用于删除功能的属性
    private var songs: [UniversalSong] {
        return localSongs.map { $0.toUniversalSong() }
    }
    
    private var albums: [UniversalAlbum] = [] 
    private var artists: [UniversalArtist] = []

    // 重复播放模式枚举
    enum LocalRepeatMode {
        case none    // 不重复
        case all     // 重复整个队列
        case one     // 重复当前歌曲
    }
    
    private override init() {
        super.init()
        setupNotifications()
        
        // 音频会话管理已统一移到AudioSessionManager，无需在此设置
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - 初始化和连接
    
    /// 初始化本地音乐服务
    func initialize() async throws {
        // 本地音乐始终可用
        await MainActor.run {
            isConnected = true
            isAvailable = true
        }
    }
    
    /// 检查服务可用性
    func checkAvailability() async -> Bool {
        await MainActor.run {
            isConnected = true
            isAvailable = true
            return true
        }
    }
    
    // MARK: - 本地音乐文件管理
    
    /// 本地文件导入
    func importFiles(from urls: [URL]) async throws {
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "LocalMusicService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "无法访问文档目录"])
        }
        
        // 🔑 创建Music根目录
        let musicDir = docDir.appendingPathComponent("Music")
        if !FileManager.default.fileExists(atPath: musicDir.path) {
            try FileManager.default.createDirectory(at: musicDir, withIntermediateDirectories: true)
            print("📁 创建Music根目录: \(musicDir.path)")
        }
        
        for sourceURL in urls {
            do {
                // 🔑 首先读取文件元数据来确定存放位置
                let tempMusicItem = await LocalMusicItem(url: sourceURL)
                
                // 🔑 创建艺术家文件夹
                let artistName = sanitizeFileName(tempMusicItem.artist)
                let artistDir = musicDir.appendingPathComponent(artistName)
                if !FileManager.default.fileExists(atPath: artistDir.path) {
                    try FileManager.default.createDirectory(at: artistDir, withIntermediateDirectories: true)
                    print("📁 创建艺术家目录: \(artistDir.path)")
                }
                
                // 🔑 创建专辑文件夹
                let albumName = sanitizeFileName(tempMusicItem.album)
                let albumDir = artistDir.appendingPathComponent(albumName)
                if !FileManager.default.fileExists(atPath: albumDir.path) {
                    try FileManager.default.createDirectory(at: albumDir, withIntermediateDirectories: true)
                    print("📁 创建专辑目录: \(albumDir.path)")
                }
                
                // 🔑 生成目标文件名（包含音轨号）
                let fileName = generateFileName(for: tempMusicItem, originalURL: sourceURL)
                let destinationURL = albumDir.appendingPathComponent(fileName)
                
                // 如果目标文件已存在，处理重复文件
                let finalDestinationURL = handleDuplicateFile(destinationURL)
                
                // 复制文件到分层目录结构
                try FileManager.default.copyItem(at: sourceURL, to: finalDestinationURL)
                
                print("📁 文件已导入到: \(finalDestinationURL.path)")
                
            } catch {
                // 记录单个文件的错误但继续处理其他文件
                print("❌ 导入文件失败 \(sourceURL.lastPathComponent): \(error.localizedDescription)")
                
                // 🔑 如果元数据读取失败，使用默认位置
                let fallbackDir = musicDir.appendingPathComponent("未知艺术家").appendingPathComponent("未知专辑")
                try? FileManager.default.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
                let fallbackDestination = fallbackDir.appendingPathComponent(sourceURL.lastPathComponent)
                
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: handleDuplicateFile(fallbackDestination))
                    print("📁 文件导入到默认位置: \(fallbackDestination.path)")
                } catch {
                    print("❌ 无法导入到默认位置: \(error.localizedDescription)")
                    continue
                }
            }
        }
        
        // 文件复制完成后，清除缓存强制重新扫描
        LocalLibraryDataManager.clearSharedCache()
        
//        // MARK: - MusicDataSource 协议实现
//        func checkAvailability() async -> Bool {
//            // 检查本地音乐服务是否可用
//            return true
//        }
//
//        func getRecentAlbums() async throws -> [UniversalAlbum] {
//            // 获取本地音乐专辑
//            return []
//        }
//
//        func getArtists() async throws -> [UniversalArtist] {
//            // 获取本地艺术家
//            return []
//        }
        // 🔑 新增：导入完成后立即扫描本地音乐
        await scanLocalMusic()
    }
    
    /// 🔑 新增：导入单个文件
    func importFile(url: URL) async throws {
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "LocalMusicService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "无法访问文档目录"])
        }
        
        // 🔑 创建Music根目录
        let musicDir = docDir.appendingPathComponent("Music")
        if !FileManager.default.fileExists(atPath: musicDir.path) {
            try FileManager.default.createDirectory(at: musicDir, withIntermediateDirectories: true)
            print("📁 创建Music根目录: \(musicDir.path)")
        }
        
        do {
            // 🔑 首先读取文件元数据来确定存放位置
            let tempMusicItem = await LocalMusicItem(url: url)
            
            // 🔑 创建艺术家文件夹
            let artistName = sanitizeFileName(tempMusicItem.artist)
            let artistDir = musicDir.appendingPathComponent(artistName)
            if !FileManager.default.fileExists(atPath: artistDir.path) {
                try FileManager.default.createDirectory(at: artistDir, withIntermediateDirectories: true)
                print("📁 创建艺术家目录: \(artistDir.path)")
            }
            
            // 🔑 创建专辑文件夹
            let albumName = sanitizeFileName(tempMusicItem.album)
            let albumDir = artistDir.appendingPathComponent(albumName)
            if !FileManager.default.fileExists(atPath: albumDir.path) {
                try FileManager.default.createDirectory(at: albumDir, withIntermediateDirectories: true)
                print("📁 创建专辑目录: \(albumDir.path)")
            }
            
            // 🔑 生成目标文件名（包含音轨号）
            let fileName = generateFileName(for: tempMusicItem, originalURL: url)
            let destinationURL = albumDir.appendingPathComponent(fileName)
            
            // 如果目标文件已存在，处理重复文件
            let finalDestinationURL = handleDuplicateFile(destinationURL)
            
            // 复制文件到分层目录结构
            try FileManager.default.copyItem(at: url, to: finalDestinationURL)
            
            print("📁 文件已导入到: \(finalDestinationURL.path)")
            
        } catch {
            // 记录单个文件的错误
            print("❌ 导入文件失败 \(url.lastPathComponent): \(error.localizedDescription)")
            
            // 🔑 如果元数据读取失败，使用默认位置
            let fallbackDir = musicDir.appendingPathComponent("未知艺术家").appendingPathComponent("未知专辑")
            try? FileManager.default.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
            let fallbackDestination = fallbackDir.appendingPathComponent(url.lastPathComponent)
            
            do {
                try FileManager.default.copyItem(at: url, to: handleDuplicateFile(fallbackDestination))
                print("📁 文件导入到默认位置: \(fallbackDestination.path)")
            } catch {
                print("❌ 无法导入到默认位置: \(error.localizedDescription)")
                throw error
            }
        }
        
        // 🔑 新增：导入完成后清除缓存并重新扫描本地音乐
        LocalLibraryDataManager.clearSharedCache()
        await scanLocalMusic()
    }
    
    /// 扫描本地音乐文件
    func scanLocalMusic() async {
        await MainActor.run { isLoadingLocalMusic = true }
        
        // 扫描文档目录中的音乐文件
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ 无法访问文档目录")
            await MainActor.run {
                self.isLoadingLocalMusic = false
            }
            return
        }
        
        let musicFormats = ["mp3", "m4a", "wav", "aac", "flac", "aiff", "caf"]
        
        do {
            // 🔑 修改：优先扫描Music目录，如果不存在则扫描整个Documents目录
            let musicDir = documentsPath.appendingPathComponent("Music")
            let scanDirectories: [URL] = FileManager.default.fileExists(atPath: musicDir.path) 
                ? [musicDir] 
                : [documentsPath]
            
            print("🎵 扫描目录: \(scanDirectories.map { $0.path })")
            
            var allMusicURLs: [URL] = []
            
            // 🔑 递归扫描所有目录
            for directory in scanDirectories {
                let musicURLs = try await scanDirectoryRecursively(directory: directory, supportedFormats: musicFormats)
                allMusicURLs.append(contentsOf: musicURLs)
            }
            
            print("🎵 发现 \(allMusicURLs.count) 个音乐文件")
            
            // 🔑 修复：并行创建LocalMusicItem对象，但添加播放能力检查
            let foundSongs = await allMusicURLs.concurrentMap { url -> LocalMusicItem? in
                // 检查文件是否可播放
                let isPlayable = await self.checkFilePlayability(url: url)
                if !isPlayable {
                    print("⚠️ 文件不可播放，跳过: \(url.lastPathComponent)")
                    return nil
                }
                
                let musicItem = await LocalMusicItem(url: url)
                print("🎵 成功解析本地音乐: \(musicItem.title) - \(musicItem.artist)")
                return musicItem
            }
            
            // 过滤掉nil值
            let validSongs = foundSongs.compactMap { $0 }
            
            // 按专辑分组
            let groupedByAlbum = Dictionary(grouping: validSongs) { $0.album }
            let albums = groupedByAlbum.compactMap { (albumName, songs) -> LocalAlbumItem? in
                guard !songs.isEmpty, let firstSong = songs.first else {
                    return nil
                }
                
                return LocalAlbumItem(
                    title: albumName,
                    artist: firstSong.artist,
                    artworkData: firstSong.artwork,
                    songs: songs.sorted { 
                        // 首先按音轨号排序，如果没有音轨号则按标题排序
                        if let track1 = $0.trackNumber, let track2 = $1.trackNumber {
                            return track1 < track2
                        }
                        return $0.title < $1.title
                    }
                )
            }.sorted { $0.title < $1.title }
            
            await MainActor.run {
                self.localSongs = validSongs.sorted { 
                    // 首先按专辑排序，然后按音轨号排序，最后按标题排序
                    if $0.album != $1.album {
                        return $0.album < $1.album
                    }
                    if let track1 = $0.trackNumber, let track2 = $1.trackNumber {
                        return track1 < track2
                    }
                    return $0.title < $1.title
                }
                self.localAlbums = albums
                self.isLoadingLocalMusic = false
                print("🎵 扫描完成: 找到 \(validSongs.count) 首可播放歌曲, \(albums.count) 个专辑")
            }
            
        } catch {
            await MainActor.run {
                self.isLoadingLocalMusic = false
            }
            print("🎵 扫描本地音乐失败: \(error)")
        }
    }
    
    // 🔑 新增：递归扫描目录
    private func scanDirectoryRecursively(directory: URL, supportedFormats: [String]) async throws -> [URL] {
        var musicURLs: [URL] = []
        
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory, 
            includingPropertiesForKeys: [.isDirectoryKey], 
            options: [.skipsHiddenFiles]
        )
        
        for url in contents {
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                
                if resourceValues.isDirectory == true {
                    // 递归扫描子目录
                    let subDirectoryURLs = try await scanDirectoryRecursively(directory: url, supportedFormats: supportedFormats)
                    musicURLs.append(contentsOf: subDirectoryURLs)
                } else {
                    // 检查文件扩展名
                    let fileExtension = url.pathExtension.lowercased()
                    if supportedFormats.contains(fileExtension) {
                        musicURLs.append(url)
                    }
                }
            } catch {
                print("⚠️ 扫描文件/目录失败: \(url.lastPathComponent) - \(error)")
                continue
            }
        }
        
        return musicURLs
    }
    
    /// 🔑 移除：音频会话管理已统一移到AudioSessionManager
    /// 现在所有音频会话操作都通过AudioSessionManager进行
    
    
    // MARK: - 数据获取方法
    
    /// 获取最近专辑（扫描文档目录中的音乐文件）
    func getRecentAlbums() async throws -> [UniversalAlbum] {
        await scanLocalMusic()
        
        // 按专辑分组本地歌曲
        let groupedByAlbum = Dictionary(grouping: localSongs) { $0.album }
        let albums = groupedByAlbum.compactMap { (albumName, songs) -> UniversalAlbum? in
            guard !songs.isEmpty, let firstSong = songs.first else {
                return nil
            }
            
            let universalSongs = songs.map { $0.toUniversalSong() }
            
            // 从歌曲中提取年份和流派信息（使用第一首歌曲的信息）
            let year = firstSong.year
            let genre = firstSong.genre
            
            return UniversalAlbum(
                id: albumName, // 🔑 使用专辑名称作为ID，确保与getAlbum方法匹配
                title: albumName,
                artistName: firstSong.artist,
                year: year, // 使用从元数据中提取的年份信息
                genre: genre, // 使用从元数据中提取的流派信息
                songCount: songs.count,
                duration: songs.reduce(0) { $0 + max(0, $1.duration) }, // 确保时长不为负数
                artworkURL: nil, // 本地文件没有远程URL
                songs: universalSongs,
                source: .local,
                originalData: LocalAlbumItem(
                    title: albumName,
                    artist: firstSong.artist,
                    artworkData: firstSong.artwork,
                    songs: songs
                )
            )
        }.sorted { $0.title < $1.title }
        
        return albums
    }
    
    /// 获取艺术家列表
    func getArtists() async throws -> [UniversalArtist] {
        await scanLocalMusic()
        
        // 按艺术家分组
        let groupedByArtist = Dictionary(grouping: localSongs) { $0.artist }
        let artists = groupedByArtist.compactMap { (artistName, songs) -> UniversalArtist? in
            guard !songs.isEmpty else {
                return nil
            }
            
            let albums = Dictionary(grouping: songs) { $0.album }.compactMap { (albumName, albumSongs) -> UniversalAlbum? in
                guard !albumSongs.isEmpty else {
                    return nil
                }
                
                // 从歌曲中提取年份和流派信息
                let year = albumSongs.first?.year
                let genre = albumSongs.first?.genre
                
                return UniversalAlbum(
                    id: albumName, //UUID().uuidString,
                    title: albumName,
                    artistName: artistName,
                    year: year, // 使用从元数据中提取的年份信息
                    genre: genre, // 使用从元数据中提取的流派信息
                    songCount: albumSongs.count,
                    duration: albumSongs.reduce(0) { $0 + max(0, $1.duration) },
                    artworkURL: nil,
                    songs: albumSongs.map { $0.toUniversalSong() },
                    source: .local,
                    originalData: albumSongs
                )
            }
            
            guard !albums.isEmpty else {
                return nil
            }
            
            return UniversalArtist(
                id: artistName, //UUID().uuidString,
                name: artistName,
                albumCount: albums.count,
                albums: albums,
                source: .local,
                originalData: songs
            )
        }.sorted { $0.name < $1.name }
        
        return artists
    }
    
    /// 获取艺术家详情
    func getArtist(id: String) async throws -> UniversalArtist {
        await scanLocalMusic()
        
        // 这里我们假设id实际上是艺术家名称
        let artistSongs = localSongs.filter { $0.artist == id }
        
        // 按专辑分组
        let albums = Dictionary(grouping: artistSongs) { $0.album }.map { (albumName, albumSongs) in
            // 检查专辑是否有歌曲
            guard !albumSongs.isEmpty else {
                return UniversalAlbum(
                    id: albumName,
                    title: albumName,
                    artistName: id,
                    year: nil,
                    genre: nil,
                    songCount: 0,
                    duration: 0,
                    artworkURL: nil,
                    songs: [],
                    source: .local,
                    originalData: LocalAlbumItem(
                        title: albumName,
                        artist: id,
                        artworkData: nil,
                        songs: []
                    )
                )
            }
            
            // 从歌曲中提取年份和流派信息
            let year = albumSongs.first?.year
            let genre = albumSongs.first?.genre
            
            return UniversalAlbum(
                id: albumName,
                title: albumName,
                artistName: id,
                year: year, // 使用从元数据中提取的年份信息
                genre: genre, // 使用从元数据中提取的流派信息
                songCount: albumSongs.count,
                duration: albumSongs.reduce(0) { $0 + $1.duration },
                artworkURL: nil,
                songs: albumSongs.map { $0.toUniversalSong() },
                source: .local,
                // 🔑 修复：确保每个专辑都有正确的LocalAlbumItem数据，包含封面
                originalData: LocalAlbumItem(
                    title: albumName,
                    artist: id,
                    artworkData: albumSongs.first?.artwork, // 使用第一首歌的封面作为专辑封面
                    songs: albumSongs
                )
            )
        }.sorted { $0.title < $1.title }
        
        return UniversalArtist(
            id: id,
            name: id,
            albumCount: albums.count,
            albums: albums,
            source: .local,
            originalData: artistSongs
        )
    }
    
    /// 获取专辑详情
    func getAlbum(id: String) async throws -> UniversalAlbum {
        await scanLocalMusic()
        
        // 🔑 使用专辑名称作为ID进行匹配
        let albumSongs = localSongs.filter { $0.album == id }
        
        // 检查是否有歌曲
        guard !albumSongs.isEmpty, let firstSong = albumSongs.first else {
            // 如果没有找到歌曲，返回一个空的专辑
            return UniversalAlbum(
                id: id,
                title: id,
                artistName: "未知艺术家",
                year: nil,
                genre: nil,
                songCount: 0,
                duration: 0,
                artworkURL: nil,
                songs: [],
                source: .local,
                originalData: LocalAlbumItem(
                    title: id,
                    artist: "未知艺术家",
                    artworkData: nil,
                    songs: []
                )
            )
        }
        
        let universalSongs = albumSongs.map { $0.toUniversalSong() }
        
        // 从歌曲中提取年份和流派信息
        let year = firstSong.year
        let genre = firstSong.genre
        
        return UniversalAlbum(
            id: id,
            title: id,
            artistName: firstSong.artist,
            year: year, // 使用从元数据中提取的年份信息
            genre: genre, // 使用从元数据中提取的流派信息
            songCount: albumSongs.count,
            duration: albumSongs.reduce(0) { $0 + $1.duration },
            artworkURL: nil,
            songs: universalSongs,
            source: .local,
            originalData: LocalAlbumItem(
                title: id,
                artist: firstSong.artist,
                artworkData: firstSong.artwork,
                songs: albumSongs
            )
        )
    }
    
    // MARK: - 播放控制
    
    /// 播放歌曲队列
    func playQueue(_ songs: [UniversalSong], startingAt index: Int = 0) async throws {
        print("🎵 开始播放本地音乐队列，共\(songs.count)首歌，从第\(index + 1)首开始")
        
        // 🔑 修改：只在开始播放时请求一次音频会话控制权
        _ = AudioSessionManager.shared.requestAudioSession(for: .local)
        
        await MainActor.run {
            currentQueue = songs
            currentIndex = index
            
            // 重置播放模式相关状态
            originalQueue = songs
            originalIndex = index
            
            // 如果随机播放已启用，打乱队列
            if isShuffleEnabled {
                shuffleCurrentQueue()
            }
        }
        
        // 🔑 注册为锁屏控制器代理
        NowPlayingManager.shared.setDelegate(self)
        
        try await playCurrentSong()
    }
    
    /// 播放当前歌曲
    private func playCurrentSong() async throws {
        guard currentIndex < currentQueue.count else { return }
        
        let song = currentQueue[currentIndex]
        guard let streamURL = song.streamURL else {
            throw LocalMusicServiceError.noStreamURL
        }
        
        print("🎵 播放本地音乐: \(song.title) - \(song.artistName)")
        print("   文件路径: \(streamURL)")
        
        await MainActor.run {
            currentSong = song
            setupAVPlayer(with: streamURL)
        }
    }
    
    /// 设置AVPlayer
    private func setupAVPlayer(with url: URL) {
        cleanupPlayer()
        
        // 确保在主线程上执行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.avPlayer = AVPlayer(url: url)
            
            // 设置时长
            if let song = self.currentSong {
                self.duration = song.duration
            }
            
            // 重要：先注册播放完成通知
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: self.avPlayer?.currentItem
            )
            
            // 🔑 新增：注册播放失败通知
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.playerDidFailToPlay),
                name: AVPlayerItem.failedToPlayToEndTimeNotification,
                object: self.avPlayer?.currentItem
            )
            
            // 监听播放器状态变化
            self.avPlayer?.addObserver(self, forKeyPath: "timeControlStatus", options: [.new], context: nil)
            self.avPlayer?.currentItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
            
            // 时间观察者
            let timeInterval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            if CMTimeCompare(timeInterval, CMTime.zero) > 0 {
                self.avPlayerObserver = self.avPlayer?.addPeriodicTimeObserver(
                    forInterval: timeInterval,
                    queue: .main
                ) { [weak self] time in
                    guard let self = self else { return }
                    let newTime = CMTimeGetSeconds(time)
                    if newTime.isFinite && !newTime.isNaN {
                        self.currentTime = newTime
                        
                        // 🔑 使用统一管理器更新播放进度
                        NowPlayingManager.shared.updatePlaybackProgress()
                    }
                }
            }
            
            // 🔑 修改：移除重复的音频会话请求，因为在playQueue中已经请求过了
             let _ = AudioSessionManager.shared.requestAudioSession(for: .local)
            
            // 开始播放
            self.avPlayer?.play()
            self.isPlaying = true
            
            print("✅ 本地音乐AVPlayer 设置完成，开始播放")
            
            // 🔑 使用统一管理器更新锁屏信息
            NowPlayingManager.shared.updateNowPlayingInfo()
        }
    }
    
    /// KVO 观察者
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch keyPath {
            case "timeControlStatus":
                if let player = self.avPlayer {
                    print("🎵 本地音乐播放器状态变化: \(player.timeControlStatus.rawValue)")
                    
                    // 🔑 修复：处理所有状态变化，确保播放状态同步
                    switch player.timeControlStatus {
                    case .playing:
                        self.isPlaying = true
                        NowPlayingManager.shared.updateNowPlayingInfo()
                    case .paused:
                        self.isPlaying = false
                        NowPlayingManager.shared.updateNowPlayingInfo()
                    case .waitingToPlayAtSpecifiedRate:
                        print("🎵 本地音乐：等待播放")
                        // 不改变播放状态，等待系统处理
                    @unknown default:
                        break
                    }
                }
            case "status":
                if let status = self.avPlayer?.currentItem?.status {
                    print("🎵 本地音乐播放项状态变化: \(status.rawValue)")
                    
                    // 🔑 修复：处理所有状态变化，特别是失败状态
                    switch status {
                    case .readyToPlay:
                        print("🎵 本地音乐：播放项准备就绪")
                        NowPlayingManager.shared.updateNowPlayingInfo()
                    case .failed:
                        print("❌ 本地音乐：播放项失败")
                        self.isPlaying = false
                        NowPlayingManager.shared.updateNowPlayingInfo()
                        
                        // 🔑 新增：尝试重新播放
                        if let song = self.currentSong {
                            print("🔄 尝试重新播放失败的歌曲: \(song.title)")
                            Task {
                                try? await self.playCurrentSong()
                            }
                        }
                    case .unknown:
                        print("🎵 本地音乐：播放项状态未知")
                    @unknown default:
                        break
                    }
                }
            default:
                break
            }
        }
    }
    
    /// 播放
    func play() async {
        avPlayer?.play()
        await MainActor.run {
            isPlaying = true
            // 更新锁屏播放状态
            // 🔑 使用统一管理器更新播放状态
            NowPlayingManager.shared.updatePlaybackProgress()
        }
    }
    
    /// 暂停
    func pause() async {
        avPlayer?.pause()
        await MainActor.run {
            isPlaying = false
            // 更新锁屏播放状态
            NowPlayingManager.shared.updatePlaybackProgress()
        }
    }
    
    /// 下一首
    func skipToNext() async throws {
        if currentIndex < currentQueue.count - 1 {
            await MainActor.run {
                currentIndex += 1
            }
            try await playCurrentSong()
        } else {
            // 队列播放完毕，根据重复模式处理
            try await handleQueueEnd()
        }
    }
    
    /// 上一首
    func skipToPrevious() async throws {
        if currentIndex > 0 {
            await MainActor.run {
                currentIndex -= 1
            }
            try await playCurrentSong()
        }
    }
    
    /// 快进
    func seekForward(_ seconds: TimeInterval) {
        guard let player = avPlayer else { return }
        let currentTime = player.currentTime().seconds
        let newTime = min(duration, currentTime + seconds)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1))
    }
    
    /// 快退
    func seekBackward(_ seconds: TimeInterval) {
        guard let player = avPlayer else { return }
        let currentTime = player.currentTime().seconds
        let newTime = max(0, currentTime - seconds)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1))
    }
    
    /// 跳转到指定时间
    func seek(to time: TimeInterval) async {
        await MainActor.run {
            avPlayer?.seek(to: CMTime(seconds: time, preferredTimescale: 1))
            currentTime = time
            // 更新锁屏播放进度
            NowPlayingManager.shared.updatePlaybackProgress()
        }
    }
    
    /// 停止播放
    func stop() {
        avPlayer?.pause()
        cleanupPlayer()
        
        currentSong = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        
        // 🔑 清除锁屏控制器代理
        NowPlayingManager.shared.setDelegate(nil)

        // 释放音频会话控制权
        AudioSessionManager.shared.releaseAudioSession(for: .local)
        
        // 🔑 使用统一管理器清除锁屏播放信息
        NowPlayingManager.shared.clearNowPlayingInfo()
    }
    
    // MARK: - 获取当前播放信息
    
    /// 获取当前播放歌曲
    func getCurrentSong() -> UniversalSong? {
        return currentSong
    }
    
    /// 获取播放进度信息
    func getPlaybackInfo() -> (current: TimeInterval, total: TimeInterval, isPlaying: Bool) {
        return (currentTime, duration, isPlaying)
    }
    
    /// 获取队列信息
    func getQueueInfo() -> (queue: [UniversalSong], currentIndex: Int) {
        return (currentQueue, currentIndex)
    }
    
    // MARK: - 播放模式管理
    
    /// 处理队列播放完毕
    private func handleQueueEnd() async throws {
        switch repeatMode {
        case .none:
            // 不重复，停止播放
            await MainActor.run {
                isPlaying = false
            }
            
        case .all:
            // 重复整个队列，从头开始
            await MainActor.run {
                currentIndex = 0
            }
            try await playCurrentSong()
            
        case .one:
            // 重复当前歌曲（这种情况不应该到达这里）
            break
        }
    }
    
    /// 保存原始队列
    private func saveOriginalQueue() {
        originalQueue = currentQueue
        originalIndex = currentIndex
    }
    
    /// 打乱当前队列
    private func shuffleCurrentQueue() {
        guard !currentQueue.isEmpty else { return }
        
        // 保存当前正在播放的歌曲
        let currentSong = currentQueue[currentIndex]
        
        // 打乱队列
        var shuffledQueue = currentQueue
        shuffledQueue.shuffle()
        
        // 确保当前歌曲在第一位
        if let newIndex = shuffledQueue.firstIndex(where: { $0.id == currentSong.id }) {
            shuffledQueue.swapAt(0, newIndex)
            currentQueue = shuffledQueue
            currentIndex = 0
        }
    }
    
    /// 恢复原始队列
    private func restoreOriginalQueue() {
        guard !originalQueue.isEmpty else { return }
        
        // 找到当前播放歌曲在原始队列中的位置
        let currentSong = currentQueue[currentIndex]
        if let originalIndex = originalQueue.firstIndex(where: { $0.id == currentSong.id }) {
            currentQueue = originalQueue
            currentIndex = originalIndex
        } else {
            // 如果找不到，使用保存的原始索引
            currentQueue = originalQueue
            currentIndex = min(self.originalIndex, originalQueue.count - 1)
        }
    }
    
    /// 设置随机播放
    func setShuffleEnabled(_ enabled: Bool) {
        isShuffleEnabled = enabled
    }
    
    /// 设置重复播放模式
    func setRepeatMode(_ mode: LocalRepeatMode) {
        repeatMode = mode
    }
    
    /// 获取播放模式状态
    func getPlaybackModes() -> (shuffle: Bool, repeat: LocalRepeatMode) {
        return (isShuffleEnabled, repeatMode)
    }
    
    // MARK: - 播放时长计算方法

    /// 计算 Local 队列中所有歌曲的总时长
    func calculateLocalQueueTotalDuration(queue: [UniversalSong]) -> TimeInterval {
        let totalDuration = queue.reduce(0) { total, song in
            total + song.duration
        }
        
        // 如果总时长为0，返回默认值
        return totalDuration > 0 ? totalDuration : TimeInterval(queue.count * 180) // 每首歌默认3分钟
    }
    
    /// 计算 Local 队列中已播放的总时长
    func calculateLocalQueueElapsedDuration(queue: [UniversalSong], currentIndex: Int, currentTime: TimeInterval) -> TimeInterval {
        guard currentIndex < queue.count else { return 0 }
        
        var elapsedDuration: TimeInterval = 0
        
        // 计算当前歌曲之前所有歌曲的总时长
        for index in 0..<currentIndex {
            elapsedDuration += queue[index].duration
        }
        
        // 加上当前歌曲的播放时长
        elapsedDuration += currentTime
        
        return elapsedDuration
    }
    
    // MARK: - 私有方法
    
    private func setupNotifications() {
        // 🔑 修复：移除重复的音频会话中断处理，统一由AudioSessionManager管理
        // 现在只监听来自AudioSessionManager的统一通知
        
        // 监听来自AudioSessionManager的停止播放通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShouldStopPlaying),
            name: .localMusicShouldStopPlaying,
            object: nil
        )
        
        // 监听来自AudioSessionManager的恢复播放通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShouldResumePlaying),
            name: .localMusicShouldResumePlaying,
            object: nil
        )
        
        // 🔑 修改：移除重复的应用状态变化监听，因为AudioSessionManager已经统一处理
        // NotificationCenter.default.addObserver(
        //     self,
        //     selector: #selector(handleAppDidEnterBackground),
        //     name: UIApplication.didEnterBackgroundNotification,
        //     object: nil
        // )
        //
        // NotificationCenter.default.addObserver(
        //     self,
        //     selector: #selector(handleAppWillEnterForeground),
        //     name: UIApplication.willEnterForegroundNotification,
        //     object: nil
        // )
    }
    
    @objc private func playerDidFinishPlaying() {
        print("🎵 本地音乐：播放完成")
        Task {
            // 根据重复模式处理播放完成
            switch repeatMode {
            case .one:
                // 重复当前歌曲
                try await playCurrentSong()
                
            case .all, .none:
                // 播放下一首或处理队列结束
                try await skipToNext()
            }
        }
    }
    
    // 🔑 新增：处理播放失败
    @objc private func playerDidFailToPlay() {
        print("❌ 本地音乐：播放失败")
        Task {
            await MainActor.run {
                self.isPlaying = false
                self.currentTime = 0
            }
            
            // 尝试重新播放
            if let song = self.currentSong {
                print("🔄 尝试重新播放失败的歌曲: \(song.title)")
                try? await self.playCurrentSong()
            }
        }
    }
    
    // 🔑 修复：移除重复的音频会话中断处理方法，统一由AudioSessionManager管理
    // 现在通过 handleShouldStopPlaying 和 handleShouldResumePlaying 方法处理中断
    
    // 🔑 新增：处理来自AudioSessionManager的停止播放通知
    @objc private func handleShouldStopPlaying() {
        print("🎵 本地音乐：收到停止播放通知")
        Task {
            await pause()
        }
    }
    
    // 🔑 新增：处理来自AudioSessionManager的恢复播放通知
    @objc private func handleShouldResumePlaying() {
        print("🎵 本地音乐：收到恢复播放通知")
        Task {
            // 重新激活音频会话
            let sessionSuccess = AudioSessionManager.shared.requestAudioSession(for: .local)
            if sessionSuccess {
                print("✅ 本地音乐：音频会话重新激活成功")
                await play()
            } else {
                print("❌ 本地音乐：音频会话重新激活失败")
                // 即使音频会话失败，也尝试播放，让系统处理
                await play()
            }
        }
    }
    
    // 🔑 新增：处理应用进入后台
    @objc private func handleAppDidEnterBackground() {
        print("🎵 本地音乐：应用进入后台")
            // 🔑 修改：移除重复的音频会话请求，因为AudioSessionManager已经统一处理
            // if isPlaying {
            //     _ = AudioSessionManager.shared.requestAudioSession(for: .local)
            // }
    }
    
    // 🔑 新增：处理应用回到前台
    @objc private func handleAppWillEnterForeground() {
        print("🎵 本地音乐：应用回到前台")
            // 🔑 修改：移除重复的音频会话请求，因为AudioSessionManager已经统一处理
            // if isPlaying {
            //     _ = AudioSessionManager.shared.requestAudioSession(for: .local)
            // }
    }
    
    private func cleanupPlayer() {
        // 移除观察者
        avPlayer?.removeObserver(self, forKeyPath: "timeControlStatus")
        avPlayer?.currentItem?.removeObserver(self, forKeyPath: "status")
        
        if let observer = avPlayerObserver {
            avPlayer?.removeTimeObserver(observer)
            avPlayerObserver = nil
        }
        
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer?.currentItem
        )
        
        avPlayer = nil
    }
    
    private func cleanup() {
        cleanupPlayer()
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 删除本地音乐文件
    func deleteSong(_ song: UniversalSong) async throws {
        print("🗑️ 开始删除歌曲: \(song.title)")
        print("🗑️ originalData类型: \(type(of: song.originalData))")

        guard let localSong = song.originalData as? LocalSongItem else {
            print("❌ 无效的song.originalData类型，期望LocalSongItem，实际: \(type(of: song.originalData))")
            throw LocalMusicServiceError.invalidFileURL
        }
        
        print("🗑️ LocalSongItem filePath: \(localSong.filePath)")

        // 🔑 修复：正确处理URL编码的文件路径
        let fileURL: URL
        if localSong.filePath.hasPrefix("file://") {
            // 如果是完整的file URL字符串
            guard let url = URL(string: localSong.filePath) else {
                throw LocalMusicServiceError.invalidFileURL
            }
            fileURL = url
        } else {
            // 如果是普通路径字符串
            fileURL = URL(fileURLWithPath: localSong.filePath)
        }
        
        print("🗑️ 尝试删除文件: \(fileURL.path)")
        print("🗑️ 文件URL: \(fileURL)")
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ 文件不存在: \(fileURL.path)")
            throw LocalMusicServiceError.fileNotFound
        }
        
        do {
            // 删除文件
            try FileManager.default.removeItem(at: fileURL)
            print("✅ 成功删除文件: \(fileURL.lastPathComponent)")
            
            // 从内存中移除
            await MainActor.run {
                // 从localSongs列表中移除
                if let localIndex = self.localSongs.firstIndex(where: { $0.id.uuidString == song.id }) {
                    self.localSongs.remove(at: localIndex)
                    print("✅ 从localSongs中移除: \(song.title)")
                }
                
                // 更新专辑信息
                self.updateAlbumsAfterSongDeletion(deletedSong: song)
                
                // 更新艺术家信息
                self.updateArtistsAfterSongDeletion(deletedSong: song)
            }
            
            print("🗑️ 已删除本地歌曲: \(song.title)")
            
        } catch {
            print("❌ 删除文件时发生错误: \(error)")
            throw LocalMusicServiceError.deletionFailed(error.localizedDescription)
        }
    }
    
    /// 删除整张专辑
    func deleteAlbum(_ album: UniversalAlbum) async throws {
        // 🔑 修复：检查专辑的originalData类型
        print("🗑️ 开始删除专辑: \(album.title)")
        print("🗑️ 专辑数据类型: \(type(of: album.originalData))")
        
        // 🔑 根据专辑中的歌曲来删除，而不是依赖originalData
        let albumSongs = album.songs.filter { song in
            song.source == .local
        }
        
        guard !albumSongs.isEmpty else {
            print("❌ 专辑中没有本地歌曲")
            throw LocalMusicServiceError.invalidAlbumData
        }
        
        print("🗑️ 专辑包含 \(albumSongs.count) 首歌曲")
        
        var deletionErrors: [String] = []
        
        // 删除专辑中的所有歌曲
        for song in albumSongs {
            do {
                try await deleteSong(song)
                print("✅ 成功删除歌曲: \(song.title)")
            } catch {
                let errorMsg = "\(song.title): \(error.localizedDescription)"
                deletionErrors.append(errorMsg)
                print("❌ 删除歌曲失败: \(errorMsg)")
            }
        }
        
        // 如果有删除失败的歌曲，抛出错误
        if !deletionErrors.isEmpty {
            let errorMessage = deletionErrors.joined(separator: ", ")
            throw LocalMusicServiceError.partialDeletionFailed(errorMessage)
        }
        
        print("🗑️ 已删除本地专辑: \(album.title)")
    }
    
//    /// 删除艺术家的所有音乐
//    func deleteArtist(_ artist: UniversalArtist) async throws {
//        let artistSongs = songs.filter { song in
//            song.artistName.localizedCaseInsensitiveCompare(artist.name) == .orderedSame
//        }
//        
//        var deletionErrors: [String] = []
//        
//        // 删除艺术家的所有歌曲
//        for song in artistSongs {
//            do {
//                try await deleteSong(song)
//            } catch {
//                deletionErrors.append("\(song.title): \(error.localizedDescription)")
//            }
//        }
//        
//        // 如果有删除失败的歌曲，抛出错误
//        if !deletionErrors.isEmpty {
//            let errorMessage = deletionErrors.joined(separator: ", ")
//            throw LocalMusicServiceError.partialDeletionFailed(errorMessage)
//        }
//        
//        print("🗑️ 已删除艺术家所有音乐: \(artist.name)")
//    }
    
//    /// 获取本地音乐库存储大小
//    func getLibraryStorageSize() -> Int64 {
//        var totalSize: Int64 = 0
//        
//        for song in songs {
//            if let localSong = song.originalData as? LocalSongItem,
//               let fileURL = URL(string: localSong.filePath),
//               FileManager.default.fileExists(atPath: fileURL.path) {
//                do {
//                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
//                    if let fileSize = attributes[FileAttributeKey.size] as? Int64 {
//                        totalSize += fileSize
//                    }
//                } catch {
//                    // 忽略获取文件大小失败的情况
//                }
//            }
//        }
//        
//        return totalSize
//    }
//    
//    /// 获取本地音乐文件数量统计
//    func getLibraryStatistics() -> (songCount: Int, albumCount: Int, artistCount: Int, storageSize: Int64) {
//        let songCount = songs.count
//        let albumCount = Set(songs.compactMap { song in
//            if let localSong = song.originalData as? LocalSongItem {
//                return "\(localSong.artistName)_\(localSong.albumName ?? "Unknown")"
//            }
//            return nil
//        }).count
//        let artistCount = Set(songs.map { $0.artistName }).count
//        let storageSize = getLibraryStorageSize()
//        
//        return (songCount, albumCount, artistCount, storageSize)
//    }
    
    // MARK: - 私有辅助方法
    
    /// 创建UniversalAlbum的辅助方法
    private func createUniversalAlbum(from localSong: LocalSongItem, songs: [UniversalSong]) -> UniversalAlbum {
        return UniversalAlbum(
            id: localSong.albumName ?? "Unknown Album",
            title: localSong.albumName ?? "Unknown Album",
            artistName: localSong.artistName,
            year: nil,
            genre: nil,
            songCount: songs.count,
            duration: songs.reduce(0) { $0 + $1.duration },
            artworkURL: nil,
            songs: songs,
            source: .local,
            originalData: LocalAlbumItem(
                title: localSong.albumName ?? "Unknown Album",
                artist: localSong.artistName,
                artworkData: localSong.artworkData,
                songs: []
            )
        )
    }
    
    /// 更新专辑信息（删除歌曲后）
    private func updateAlbumsAfterSongDeletion(deletedSong: UniversalSong) {
        // 重新生成专辑列表
        let groupedSongs = Dictionary(grouping: songs) { song -> String in
            guard let localSong = song.originalData as? LocalSongItem else { return "Unknown Album" }
            return "\(localSong.artistName)_\(localSong.albumName ?? "Unknown Album")"
        }
        
        albums = groupedSongs.compactMap { (key, songs) in
            guard let firstSong = songs.first,
                  let localSong = firstSong.originalData as? LocalSongItem else { return nil }
            
            return createUniversalAlbum(from: localSong, songs: songs)
        }.sorted { $0.title < $1.title }
    }
    
    /// 更新艺术家信息（删除歌曲后）
    private func updateArtistsAfterSongDeletion(deletedSong: UniversalSong) {
        // 重新生成艺术家列表
        let groupedSongs = Dictionary(grouping: songs) { $0.artistName }
        
        artists = groupedSongs.compactMap { (artistName, songs) in
            let artistAlbums = Set(songs.compactMap { song -> String? in
                guard let localSong = song.originalData as? LocalSongItem else { return nil }
                return localSong.albumName
            })
            
            return UniversalArtist(
                id: artistName.replacingOccurrences(of: " ", with: "_"),
                name: artistName,
                albumCount: artistAlbums.count,
                albums: [],
                source: .local,
                originalData: artistName
            )
        }.sorted { $0.name < $1.name }
    }
    
    // 🔑 新增：文件名清理函数
    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let sanitized = name.components(separatedBy: invalidChars).joined(separator: "_")
        
        // 限制长度并去除首尾空格
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLength = 100
        
        if trimmed.isEmpty {
            return "Unknown"
        } else if trimmed.count > maxLength {
            return String(trimmed.prefix(maxLength))
        } else {
            return trimmed
        }
    }
    
    // 🔑 新增：生成优化的文件名
    private func generateFileName(for musicItem: LocalMusicItem, originalURL: URL) -> String {
        let fileExtension = originalURL.pathExtension
        var components: [String] = []
        
        // 添加音轨号（如果存在）
        if let trackNumber = musicItem.trackNumber {
            components.append(String(format: "%02d", trackNumber))
        }
        
        // 添加歌曲标题
        let title = sanitizeFileName(musicItem.title)
        if !title.isEmpty && title != "Unknown" {
            components.append(title)
        } else {
            // 如果没有有效标题，使用原始文件名（去除扩展名）
            components.append(originalURL.deletingPathExtension().lastPathComponent)
        }
        
        let finalName = components.joined(separator: " - ")
        return "\(finalName).\(fileExtension)"
    }
    
    // 🔑 新增：处理重复文件
    private func handleDuplicateFile(_ url: URL) -> URL {
        var finalURL = url
        var counter = 1
        
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
            let pathExtension = url.pathExtension
            let directory = url.deletingLastPathComponent()
            
            let newName = "\(nameWithoutExtension) (\(counter)).\(pathExtension)"
            finalURL = directory.appendingPathComponent(newName)
            counter += 1
        }
        
        return finalURL
    }
    
    // 🔑 新增：检查文件是否可播放
    private func checkFilePlayability(url: URL) async -> Bool {
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ 文件不存在: \(url.lastPathComponent)")
            return false
        }
        
        // 检查文件大小
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = fileAttributes[FileAttributeKey.size] as? Int64 {
                if fileSize < 1024 { // 小于1KB可能是损坏文件
                    print("⚠️ 文件过小，可能损坏: \(url.lastPathComponent) (\(fileSize) bytes)")
                    return false
                }
            }
        } catch {
            print("❌ 无法获取文件属性: \(url.lastPathComponent)")
            return false
        }
        
        // 使用AVAsset检查文件是否可读
        let asset = AVAsset(url: url)
        do {
            let isReadable = try await asset.load(.isReadable)
            if !isReadable {
                print("⚠️ 文件不可读: \(url.lastPathComponent)")
                return false
            }
            
            // 检查是否有音频轨道
            let tracks = try await asset.load(.tracks)
            let audioTracks = tracks.filter { track in
                track.mediaType == .audio
            }
            
            if audioTracks.isEmpty {
                print("⚠️ 文件没有音频轨道: \(url.lastPathComponent)")
                return false
            }
            
            // 对于FLAC文件，做额外检查
            let fileExtension = url.pathExtension.lowercased()
            if fileExtension == "flac" {
                // 检查AVPlayer是否支持播放这个FLAC文件
                let playerItem = AVPlayerItem(url: url)
                
                // 等待一小段时间让播放项准备
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                
                if playerItem.status == .failed {
                    print("⚠️ FLAC文件不被AVPlayer支持: \(url.lastPathComponent)")
                    if let error = playerItem.error {
                        print("   错误: \(error.localizedDescription)")
                    }
                    return false
                }
            }
            
            return true
            
        } catch {
            print("❌ 检查文件播放能力失败: \(url.lastPathComponent) - \(error)")
            return false
        }
    }
}

// MARK: - 本地音乐服务错误

enum LocalMusicServiceError: LocalizedError {
    case noMusicFiles
    case scanFailed(String)
    case importFailed(String)
    case metadataError(String)
    case noStreamURL
    case invalidFileURL
    case fileNotFound
    case deletionFailed(String)
    case invalidAlbumData
    case partialDeletionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noMusicFiles:
            return "没有找到音乐文件"
        case .scanFailed(let reason):
            return "扫描音乐文件失败: \(reason)"
        case .importFailed(let reason):
            return "导入音乐文件失败: \(reason)"
        case .metadataError(let reason):
            return "读取音乐元数据失败: \(reason)"
        case .noStreamURL:
            return "无法获取播放链接"
        case .invalidFileURL:
            return "无效的文件路径"
        case .fileNotFound:
            return "文件不存在"
        case .deletionFailed(let reason):
            return "删除文件失败: \(reason)"
        case .invalidAlbumData:
            return "无效的专辑数据"
        case .partialDeletionFailed(let reason):
            return "部分文件删除失败: \(reason)"
        }
    }
}

// MARK: - 扩展以支持并发映射

extension Sequence {
    /// 并发映射函数
    func concurrentMap<T>(
        _ transform: @Sendable @escaping (Element) async -> T
    ) async -> [T] {
        let tasks = map { element in
            Task {
                await transform(element)
            }
        }
        
        return await tasks.asyncMap { task in
            await task.value
        }
    }
}

extension Array {
    /// 异步映射函数
    func asyncMap<T>(
        _ transform: @Sendable @escaping (Element) async -> T
    ) async -> [T] {
        var results: [T] = []
        results.reserveCapacity(count)
        
        for element in self {
            results.append(await transform(element))
        }
        
        return results
    }
}
