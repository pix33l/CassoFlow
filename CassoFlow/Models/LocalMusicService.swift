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
        
        // 获取音频时长 (使用新API)
        do {
            let durationValue = try await asset.load(.duration)
            duration = CMTimeGetSeconds(durationValue)
        } catch {
            print("获取音频时长失败: \(error) - 文件: \(url.lastPathComponent)")
            // 即使获取时长失败，也继续处理其他元数据
        }
        
        // 获取元数据 (使用新API)
        do {
            let metadata = try await asset.load(.commonMetadata)
            for item in metadata {
                // 先尝试获取键
                guard let key = item.commonKey?.rawValue else { continue }
                
                // 尝试加载值
                let value: Any?
                do {
                    value = try await item.load(.value)
                } catch {
                    print("加载元数据项值失败: \(error) - 键: \(key)")
                    continue
                }
                
                guard let value = value else { continue }
                
                switch key {
                case "title":
                    if let stringValue = value as? String, !stringValue.isEmpty {
                        title = stringValue
                    }
                case "artist":
                    if let stringValue = value as? String, !stringValue.isEmpty {
                        artist = stringValue
                    }
                case "albumName":
                    if let stringValue = value as? String, !stringValue.isEmpty {
                        album = stringValue
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
                default:
                    break
                }
            }
        } catch {
            print("获取元数据失败: \(error) - 文件: \(url.lastPathComponent)")
            // 即使获取元数据失败，也使用默认值
        }
        
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artwork = artwork
        self.trackNumber = trackNumber
    }
}

// MARK: - 扩展以符合UniversalSong协议
extension LocalMusicItem {
    /// 转换为UniversalSong以兼容通用播放接口
    func toUniversalSong() -> UniversalSong {
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
            originalData: self
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
}

/// 本地音乐服务管理器
class LocalMusicService: NSObject, ObservableObject {
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
    private var currentSong: UniversalSong?
    private var originalQueue: [UniversalSong] = []  // 保存原始队列顺序
    private var originalIndex: Int = 0              // 保存原始播放位置
    
    // 本地音乐文件列表
    @Published var localSongs: [LocalMusicItem] = []
    @Published var localAlbums: [LocalAlbumItem] = []
    @Published var isLoadingLocalMusic = false
    
    // 重复播放模式枚举
    enum LocalRepeatMode {
        case none    // 不重复
        case all     // 重复整个队列
        case one     // 重复当前歌曲
    }
    
    private override init() {
        super.init()
        setupNotifications()
        
        // 延迟设置音频会话和远程控制
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupAudioSession()
            self.setupRemoteCommandCenter()
        }
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
        
        for sourceURL in urls {
            do {
                let destinationURL = docDir.appendingPathComponent(sourceURL.lastPathComponent)
                
                // 如果目标文件已存在，先删除
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // 复制文件到文档目录
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            } catch {
                // 记录单个文件的错误但继续处理其他文件
                print("导入文件失败 \(sourceURL.lastPathComponent): \(error.localizedDescription)")
                continue
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
            let contents = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            
            // 收集所有音乐文件URL
            let musicURLs = contents.filter { url in
                let fileExtension = url.pathExtension.lowercased()
                return musicFormats.contains(fileExtension)
            }
            
            print("🎵 发现 \(musicURLs.count) 个音乐文件")
            
            // 并行创建LocalMusicItem对象
            let foundSongs = await musicURLs.concurrentMap { url -> LocalMusicItem in
                let musicItem = await LocalMusicItem(url: url)
                print("🎵 发现本地音乐: \(musicItem.title)")
                return musicItem
            }
            
            // 按专辑分组
            let groupedByAlbum = Dictionary(grouping: foundSongs) { $0.album }
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
                self.localSongs = foundSongs.sorted { 
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
                print("🎵 扫描完成: 找到 \(foundSongs.count) 首歌曲, \(albums.count) 个专辑")
            }
            
        } catch {
            await MainActor.run {
                self.isLoadingLocalMusic = false
            }
            print("🎵 扫描本地音乐失败: \(error)")
        }
    }
    
    // MARK: - 音频会话和锁屏播放器配置
    
    /// 设置音频会话
    private func setupAudioSession() {
        // 使用统一音频会话管理器
        let success = AudioSessionManager.shared.requestAudioSession(for: .local)
        if success {
            print("✅ 本地音乐音频会话设置成功")
        } else {
            print("❌ 本地音乐音频会话设置失败")
        }
    }
    
    /// 激活音频会话
    private func activateAudioSession() {
        // 通过统一管理器激活
        let success = AudioSessionManager.shared.requestAudioSession(for: .local)
        if success {
            print("✅ 本地音乐音频会话激活成功")
        } else {
            print("⚠️ 本地音乐音频会话激活失败")
        }
    }
    
    /// 设置远程控制命令中心
    private func setupRemoteCommandCenter() {
        DispatchQueue.main.async {
            let commandCenter = MPRemoteCommandCenter.shared()
            
            // 清除所有现有目标
            commandCenter.playCommand.removeTarget(nil)
            commandCenter.pauseCommand.removeTarget(nil)
            commandCenter.nextTrackCommand.removeTarget(nil)
            commandCenter.previousTrackCommand.removeTarget(nil)
            commandCenter.changePlaybackPositionCommand.removeTarget(nil)
            commandCenter.togglePlayPauseCommand.removeTarget(nil)
            
            // 启用命令
            commandCenter.playCommand.isEnabled = true
            commandCenter.pauseCommand.isEnabled = true
            commandCenter.nextTrackCommand.isEnabled = true
            commandCenter.previousTrackCommand.isEnabled = true
            commandCenter.changePlaybackPositionCommand.isEnabled = true
            commandCenter.togglePlayPauseCommand.isEnabled = true
            
            // 播放命令
            commandCenter.playCommand.addTarget { [weak self] _ in
                print("🎵 本地音乐锁屏播放命令")
                Task { await self?.play() }
                return .success
            }
            
            // 暂停命令
            commandCenter.pauseCommand.addTarget { [weak self] _ in
                print("⏸️ 本地音乐锁屏暂停命令")
                Task { await self?.pause() }
                return .success
            }
            
            // 播放/暂停切换命令
            commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
                print("⏯️ 本地音乐锁屏播放/暂停切换命令")
                Task {
                    if self?.isPlaying == true {
                        await self?.pause()
                    } else {
                        await self?.play()
                    }
                }
                return .success
            }
            
            // 下一首命令
            commandCenter.nextTrackCommand.addTarget { [weak self] _ in
                print("⏭️ 本地音乐锁屏下一首命令")
                Task { try? await self?.skipToNext() }
                return .success
            }
            
            // 上一首命令
            commandCenter.previousTrackCommand.addTarget { [weak self] _ in
                print("⏮️ 本地音乐锁屏上一首命令")
                Task { try? await self?.skipToPrevious() }
                return .success
            }
            
            // 跳转命令
            commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
                if let event = event as? MPChangePlaybackPositionCommandEvent {
                    let time = event.positionTime
                    print("⏩ 本地音乐锁屏跳转命令: \(time)秒")
                    Task {
                        await self?.seek(to: time)
                    }
                    return .success
                }
                return .commandFailed
            }
            
            print("✅ 本地音乐远程控制命令中心配置完成")
        }
    }
    
    /// 更新锁屏播放信息
    private func updateNowPlayingInfo() {
        // 确保在主线程上执行
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let song = self.currentSong else {
                // 使用空字典而不是 nil
                MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
                print("🔄 清除本地音乐锁屏播放信息")
                return
            }
            
            // 重要：验证播放器状态
            guard let player = self.avPlayer else {
                print("❌ 本地音乐播放器为空，跳过锁屏信息更新")
                return
            }
            
            var nowPlayingInfo = [String: Any]()
            
            // 基本信息
            nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = song.artistName
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.albumName ?? ""
            
            // 时间信息
            let safeDuration = self.duration > 0 ? self.duration : song.duration
            let validDuration = max(1.0, safeDuration) // 确保时长至少为1秒
            let validCurrentTime = max(0.0, min(self.currentTime, validDuration)) // 确保当前时间不超过总时长
            
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = validDuration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = validCurrentTime
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.isPlaying ? 1.0 : 0.0
            
            // 队列信息
            if !self.currentQueue.isEmpty {
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = self.currentIndex
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = self.currentQueue.count
            }
            
            // 封面艺术
            let artworkSize = CGSize(width: 600, height: 600)
            if let artworkData = (song.originalData as? LocalMusicItem)?.artwork,
               let image = UIImage(data: artworkData) {
                let artwork = MPMediaItemArtwork(boundsSize: artworkSize) { _ in
                    return image
                }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            } else if let defaultImage = UIImage(systemName: "music.note") {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artworkSize) { _ in
                    return defaultImage
                }
            }
            
            // 设置播放信息
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            
            print("🔄 设置本地音乐锁屏播放信息:")
            print("   标题: \(song.title)")
            print("   艺术家: \(song.artistName)")
            print("   时长: \(validDuration)秒")
            print("   当前时间: \(validCurrentTime)秒")
            print("   播放速率: \(self.isPlaying ? 1.0 : 0.0)")
            print("   播放器控制状态: \(player.timeControlStatus.rawValue)")
        }
    }
    
    /// 更新播放进度信息
    private func updatePlaybackProgress() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
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
            
            return UniversalAlbum(
                id: UUID().uuidString,
                title: albumName,
                artistName: firstSong.artist,
                year: nil, // 本地文件通常没有年份信息
                genre: nil, // 本地文件可能没有流派信息
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
                
                return UniversalAlbum(
                    id: UUID().uuidString,
                    title: albumName,
                    artistName: artistName,
                    year: nil,
                    genre: nil,
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
                id: UUID().uuidString,
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
                    id: UUID().uuidString,
                    title: albumName,
                    artistName: id,
                    year: nil,
                    genre: nil,
                    songCount: 0,
                    duration: 0,
                    artworkURL: nil,
                    songs: [],
                    source: .local,
                    originalData: []
                )
            }
            
            return UniversalAlbum(
                id: UUID().uuidString,
                title: albumName,
                artistName: id,
                year: nil,
                genre: nil,
                songCount: albumSongs.count,
                duration: albumSongs.reduce(0) { $0 + $1.duration },
                artworkURL: nil,
                songs: albumSongs.map { $0.toUniversalSong() },
                source: .local,
                originalData: albumSongs
            )
        }
        
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
        
        // 这里我们假设id实际上是专辑名称
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
        
        return UniversalAlbum(
            id: id,
            title: id,
            artistName: firstSong.artist,
            year: nil,
            genre: nil,
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
        
        // 激活音频会话
        activateAudioSession()
        
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
                        
                        // 实时更新播放进度
                        if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = newTime
                            info[MPNowPlayingInfoPropertyPlaybackRate] = self.isPlaying ? 1.0 : 0.0
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                        }
                    }
                }
            }
            
            // 重要：先激活音频会话
            self.activateAudioSession()
            
            // 开始播放
            self.avPlayer?.play()
            self.isPlaying = true
            
            print("✅ 本地音乐AVPlayer 设置完成，开始播放")
            
            // 关键修复：立即设置播放信息
            self.updateNowPlayingInfo()
        }
    }
    
    /// KVO 观察者
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }
        
        DispatchQueue.main.async { [weak self] in
            switch keyPath {
            case "timeControlStatus":
                if let player = self?.avPlayer {
                    print("🎵 本地音乐播放器状态变化: \(player.timeControlStatus.rawValue)")
                    if player.timeControlStatus == .playing {
                        self?.updateNowPlayingInfo()
                    }
                }
            case "status":
                if let status = self?.avPlayer?.currentItem?.status {
                    print("🎵 本地音乐播放项状态变化: \(status.rawValue)")
                    if status == .readyToPlay {
                        self?.updateNowPlayingInfo()
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
            updatePlaybackProgress()
        }
    }
    
    /// 暂停
    func pause() async {
        avPlayer?.pause()
        await MainActor.run {
            isPlaying = false
            // 更新锁屏播放状态
            updatePlaybackProgress()
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
            updatePlaybackProgress()
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
        
        // 释放音频会话控制权
        AudioSessionManager.shared.releaseAudioSession(for: .local)
        
        // 清除锁屏播放信息
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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
    
    // MARK: - 私有方法
    
    private func setupNotifications() {
        // 音频会话中断处理
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func playerDidFinishPlaying() {
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
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            Task {
                await pause()
            }
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    Task {
                        await play()
                    }
                }
            }
        @unknown default:
            break
        }
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
}

// MARK: - 本地音乐服务错误

enum LocalMusicServiceError: LocalizedError {
    case notConnected
    case noStreamURL
    case playbackFailed
    case queueEmpty
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "本地音乐服务未连接"
        case .noStreamURL:
            return "无法获取本地音乐文件路径"
        case .playbackFailed:
            return "本地音乐播放失败"
        case .queueEmpty:
            return "播放队列为空"
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
