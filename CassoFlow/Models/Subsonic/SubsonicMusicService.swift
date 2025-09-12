import Foundation
import AVFoundation
import Combine
import MediaPlayer

/// Subsonic音乐服务管理器
class SubsonicMusicService: NSObject, ObservableObject, NowPlayingDelegate {
    static let shared = SubsonicMusicService()
    
    // MARK: - 属性
    
    @Published var isConnected: Bool = false
    @Published var isAvailable: Bool = false
    
    private let apiClient = SubsonicAPIClient()
    private var avPlayer: AVPlayer?
    private var avPlayerObserver: Any?
    internal var currentSong: UniversalSong?
    private var currentlyLoadingArtwork: Set<String> = []
    
    // MARK: - 播放状态
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    // MARK: - 队列管理
    @Published var currentQueue: [UniversalSong] = []
    @Published var currentIndex: Int = 0
    
    // 🔑 新增：播放模式管理（客户端实现）
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
    
    @Published var repeatMode: SubsonicRepeatMode = .none
    
    // 🔑 新增：队列管理相关属性
    private var originalQueue: [UniversalSong] = []  // 保存原始队列顺序
    private var originalIndex: Int = 0              // 保存原始播放位置
    
    // 🔑 新增：重复播放模式枚举
    enum SubsonicRepeatMode {
        case none    // 不重复
        case all     // 重复整个队列
        case one     // 重复当前歌曲
    }
    
    private override init() {
        super.init()
        setupNotifications()
        
        // 🔑 移除自定义缓存设置，直接使用 ImageCacheManager
        // setupArtworkCache()
        
        // 🔑 移除初始化时的音频会话和锁屏控制器设置，交给统一管理器
        // setupAudioSession() 和 setupRemoteCommandCenter() 将在首次播放时调用
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - NowPlayingDelegate 协议实现
    
    /// 获取播放进度信息
    func getPlaybackInfo() -> (current: TimeInterval, total: TimeInterval, isPlaying: Bool) {
        return (currentTime, duration, isPlaying)
    }
    
    /// 获取队列信息
    func getQueueInfo() -> (queue: [UniversalSong], currentIndex: Int) {
        return (currentQueue, currentIndex)
    }
    
    // MARK: - 初始化和连接
    
    /// 初始化Subsonic服务
    func initialize() async throws {
        let connected = try await apiClient.ping()
        await MainActor.run {
            isConnected = connected
            isAvailable = connected
        }
    }
    
    /// 检查服务可用性（不自动连接）
    func checkAvailability() async -> Bool {
        // 🔑 只有在已有配置的情况下才检查连接
        if apiClient.serverURL.isEmpty || apiClient.username.isEmpty || apiClient.password.isEmpty {
            await MainActor.run {
                isConnected = false
                isAvailable = false
            }
            return false
        }
        
        // 🔑 只在有配置信息时才尝试ping
        do {
            let connected = try await apiClient.ping()
            await MainActor.run {
                isConnected = connected
                isAvailable = connected
            }
            return connected
        } catch {
            await MainActor.run {
                isConnected = false
                isAvailable = false
            }
            return false
        }
    }
    
    /// 获取API客户端（用于配置）
    func getAPIClient() -> SubsonicAPIClient {
        return apiClient
    }
    
    // MARK: - 数据获取方法
    
    /// 获取最近专辑
    func getRecentAlbums() async throws -> [UniversalAlbum] {
        // 使用Subsonic API客户端获取最新专辑
        let albums = try await apiClient.getAlbumList2(type: "recent", size: 200)
        return albums.compactMap { album in
            UniversalAlbum(
                id: album.id,
                title: album.name,
                artistName: album.artist ?? "",
//                coverArtId: album.coverArt,
                year: album.year ?? 0,
                genre: album.genre,
                songCount: album.songCount ?? 0,
                duration: album.durationTimeInterval,
                artworkURL: album.coverArt != nil ? apiClient.getCoverArtURL(id: album.coverArt!) : nil,
                songs: [],
                source: .subsonic,
                originalData: album
            )
        }
    }
    
    /// 获取播放列表
    func getPlaylists() async throws -> [UniversalPlaylist] {
        let playlists = try await apiClient.getPlaylists()
        
        return playlists.compactMap { playlist in
            UniversalPlaylist(
                id: playlist.id,
                name: playlist.name,
                curatorName: playlist.owner,
                songCount: playlist.songCount ?? 0,
                duration: playlist.durationTimeInterval,
                artworkURL: playlist.coverArt != nil ? apiClient.getCoverArtURL(id: playlist.coverArt!) : nil,
                songs: [],
                source: .subsonic,
                originalData: playlist
            )
        }
    }
    
    /// 获取艺术家列表
    func getArtists() async throws -> [UniversalArtist] {
        let artists = try await apiClient.getArtists()
        
        return artists.compactMap { artist in
            UniversalArtist(
                id: artist.id,
                name: artist.name,
                albumCount: artist.albumCount ?? 0,
                albums: [],
                source: .subsonic,
                originalData: artist
            )
        }
    }
    
    /// 获取艺术家详情
    func getArtist(id: String) async throws -> UniversalArtist {
        let artist = try await apiClient.getArtist(id: id)
        
        let albums = artist.albums?.compactMap { album in
            UniversalAlbum(
                id: album.id,
                title: album.name,
                artistName: album.artist ?? artist.name,
                year: album.year,
                genre: album.genre,
                songCount: album.songCount ?? 0,
                duration: album.durationTimeInterval,
                artworkURL: album.coverArt != nil ? apiClient.getCoverArtURL(id: album.coverArt!) : nil,
                songs: [],
                source: .subsonic,
                originalData: album
            )
        } ?? []
        
        return UniversalArtist(
            id: artist.id,
            name: artist.name,
            albumCount: artist.albumCount ?? 0,
            albums: albums,
            source: .subsonic,
            originalData: artist
        )
    }
    
    /// 获取专辑详情
    func getAlbum(id: String) async throws -> UniversalAlbum {
        let album = try await apiClient.getAlbum(id: id)
        
        let songs = album.songs?.compactMap { song in
            UniversalSong(
                id: song.id,
                title: song.title,
                artistName: song.artist ?? "",
                albumName: song.album,
                duration: song.durationTimeInterval,
                trackNumber: song.track,
                artworkURL: song.coverArt != nil ? apiClient.getCoverArtURL(id: song.coverArt!) : nil,
                streamURL: apiClient.getStreamURL(id: song.id),
                source: .subsonic,
                originalData: song
            )
        } ?? []
        
        return UniversalAlbum(
            id: album.id,
            title: album.name,
            artistName: album.artist ?? "",
            year: album.year,
            genre: album.genre,
            songCount: songs.count,
            duration: songs.reduce(0) { $0 + $1.duration },
            artworkURL: album.coverArt != nil ? apiClient.getCoverArtURL(id: album.coverArt!) : nil,
            songs: songs,
            source: .subsonic,
            originalData: album
        )
    }
    
    /// 获取播放列表详情
    func getPlaylist(id: String) async throws -> UniversalPlaylist {
        let playlist = try await apiClient.getPlaylist(id: id)
        
        let songs = playlist.songs?.compactMap { song in
            UniversalSong(
                id: song.id,
                title: song.title,
                artistName: song.artist ?? "",
                albumName: song.album,
                duration: song.durationTimeInterval,
                trackNumber: song.track,
                artworkURL: song.coverArt != nil ? apiClient.getCoverArtURL(id: song.coverArt!) : nil,
                streamURL: apiClient.getStreamURL(id: song.id),
                source: .subsonic,
                originalData: song
            )
        } ?? []
        
        return UniversalPlaylist(
            id: playlist.id,
            name: playlist.name,
            curatorName: playlist.owner,
            songCount: songs.count,
            duration: songs.reduce(0) { $0 + $1.duration },
            artworkURL: playlist.coverArt != nil ? apiClient.getCoverArtURL(id: playlist.coverArt!) : nil,
            songs: songs,
            source: .subsonic,
            originalData: playlist
        )
    }
    
    /// 搜索音乐
    func search(query: String) async throws -> (artists: [UniversalArtist], albums: [UniversalAlbum], songs: [UniversalSong]) {
        let searchResult = try await apiClient.search3(query: query)
        
        let artists = searchResult.artist.compactMap { artist in
            UniversalArtist(
                id: artist.id,
                name: artist.name,
                albumCount: artist.albumCount ?? 0,
                albums: [],
                source: .subsonic,
                originalData: artist
            )
        }
        
        let albums = searchResult.album.compactMap { album in
            UniversalAlbum(
                id: album.id,
                title: album.name,
                artistName: album.artist ?? "",
                year: album.year,
                genre: album.genre,
                songCount: album.songCount ?? 0,
                duration: album.durationTimeInterval,
                artworkURL: album.coverArt != nil ? apiClient.getCoverArtURL(id: album.coverArt!) : nil,
                songs: [],
                source: .subsonic,
                originalData: album
            )
        }
        
        let songs = searchResult.song.compactMap { song in
            UniversalSong(
                id: song.id,
                title: song.title,
                artistName: song.artist ?? "",
                albumName: song.album,
                duration: song.durationTimeInterval,
                trackNumber: song.track,
                artworkURL: song.coverArt != nil ? apiClient.getCoverArtURL(id: song.coverArt!) : nil,
                streamURL: apiClient.getStreamURL(id: song.id),
                source: .subsonic,
                originalData: song
            )
        }
        
        return (artists: artists, albums: albums, songs: songs)
    }
    
    // MARK: - 播放控制
    
    /// 播放歌曲队列
    func playQueue(_ songs: [UniversalSong], startingAt index: Int = 0) async throws {
        print("🎵 开始播放Subsonic队列，共\(songs.count)首歌，从第\(index + 1)首开始")
        
        // 🔑 2024最佳实践：立即获取独占音频会话控制权
        print("🎯 获取独占音频会话控制权，将中断其他音乐应用")
        let success = AudioSessionManager.shared.requestAudioSession(for: .subsonic)
        if !success {
            throw SubsonicMusicServiceError.audioSessionFailed
        }
        
        // 检查连接状态
        if !isConnected {
            let connected = try await apiClient.ping()
            if !connected {
                throw SubsonicMusicServiceError.notConnected
            }
        }
        
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
        
        // 🔑 预加载当前歌曲和附近歌曲的封面
        await preloadQueueArtwork()
        
        try await playCurrentSong()
    }
    
    /// 🔑 新增：预加载队列中歌曲的封面
    private func preloadQueueArtwork() async {
        let imageCache = await ImageCacheManager.shared
        
        // 预加载当前歌曲的封面（优先级最高）
        if currentIndex < currentQueue.count,
           let artworkURL = currentQueue[currentIndex].artworkURL {
            await imageCache.preloadImage(from: artworkURL)
            print("🖼️ 预加载当前歌曲封面: \(currentQueue[currentIndex].title)")
        }
        
        // 预加载前后各3首歌的封面
        let preloadRange = max(0, currentIndex - 3)..<min(currentQueue.count, currentIndex + 4)
        
        for i in preloadRange where i != currentIndex {
            if let artworkURL = currentQueue[i].artworkURL {
                await imageCache.preloadImage(from: artworkURL)
            }
        }
        
        print("🖼️ 预加载队列封面完成，范围: \(preloadRange)")
    }
    
    /// 播放当前歌曲
    private func playCurrentSong() async throws {
        guard currentIndex < currentQueue.count else { return }
        
        let song = currentQueue[currentIndex]
        guard let streamURL = song.streamURL else {
            throw SubsonicMusicServiceError.noStreamURL
        }
        
        print("🎵 播放歌曲: \(song.title) - \(song.artistName)")
        print("   流URL: \(streamURL)")
        
        await MainActor.run {
            currentSong = song
            setupAVPlayer(with: streamURL)
        }
    }
    
    /// 设置AVPlayer
    private func setupAVPlayer(with url: URL) {
        cleanupPlayer()
        
        // 🔑 确保在主线程上执行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 🔑 移除远程控制命令中心设置，交给统一管理器处理
            
            // 🔑 创建播放器
            self.avPlayer = AVPlayer(url: url)
            
            // 设置时长
            if let song = self.currentSong {
                self.duration = song.duration
            }
            
            // 注册播放完成通知
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
                        
                        // 🔑 使用统一管理器实时更新播放进度
                        NowPlayingManager.shared.updatePlaybackProgress()
                    }
                }
            }
            
            // 🔑 开始播放
            self.avPlayer?.play()
            self.isPlaying = true
            
            print("✅ AVPlayer开始播放")
            
            // 🔑 验证独占状态
            let session = AVAudioSession.sharedInstance()
            if session.isOtherAudioPlaying {
                print("⚠️ 警告：仍检测到其他音频播放")
            } else {
                print("✅ 确认获得独占音频控制权")
            }
            
            // 🔑 使用统一管理器更新锁屏信息
            NowPlayingManager.shared.updateNowPlayingInfo()
        }
    }
    
    /// KVO 观察者
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }
        
        DispatchQueue.main.async { [weak self] in
            switch keyPath {
            case "timeControlStatus":
                if let player = self?.avPlayer {
                    print("🎵 播放器状态变化: \(player.timeControlStatus.rawValue)")
                    // 🔑 只在状态真正稳定时才更新锁屏信息
                    if player.timeControlStatus == .playing && self?.isPlaying == true {
                        // 播放器确实在播放，且我们的状态也是播放
                        NowPlayingManager.shared.updateNowPlayingInfo()
                    } else if player.timeControlStatus == .paused && self?.isPlaying == false {
                        // 播放器确实暂停，且我们的状态也是暂停
                        NowPlayingManager.shared.updateNowPlayingInfo()
                    }
                    // 🔑 忽略中间的过渡状态，避免闪烁
                }
            case "status":
                if let status = self?.avPlayer?.currentItem?.status {
                    print("🎵 播放项状态变化: \(status.rawValue)")
                    if status == .readyToPlay {
                        // 🔑 播放准备就绪时，确保锁屏状态正确
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NowPlayingManager.shared.updateNowPlayingInfo()
                        }
                    }
                }
            default:
                break
            }
        }
    }
    
    /// 播放
    func play() async {
        // 🔑 修改：移除重复的音频会话请求，因为在playQueue中已经请求过了
         let _ = AudioSessionManager.shared.requestAudioSession(for: .subsonic)
        
        avPlayer?.play()
        await MainActor.run {
            isPlaying = true
            NowPlayingManager.shared.updatePlaybackProgress()
        }
        
        print("▶️ Subsonic继续播放")
    }
    
    /// 暂停
    func pause() async {
        avPlayer?.pause()
        await MainActor.run {
            isPlaying = false
            NowPlayingManager.shared.updatePlaybackProgress()
        }
    }
    
    /// 下一首
    func skipToNext() async throws {
        if currentIndex < currentQueue.count - 1 {
            await MainActor.run {
                currentIndex += 1
            }
            
            // 🔑 预加载新歌曲的封面
            await preloadCurrentAndNearbyArtwork()
            
            try await playCurrentSong()
        } else {
            // 🔑 队列播放完毕，根据重复模式处理
            try await handleQueueEnd()
        }
    }
    
    /// 上一首
    func skipToPrevious() async throws {
        if currentIndex > 0 {
            await MainActor.run {
                currentIndex -= 1
            }
            
            // 🔑 预加载新歌曲的封面
            await preloadCurrentAndNearbyArtwork()
            
            try await playCurrentSong()
        }
    }
    
    /// 🔑 新增：预加载当前歌曲和附近歌曲的封面
    private func preloadCurrentAndNearbyArtwork() async {
        let imageCache = await ImageCacheManager.shared
        
        // 预加载当前歌曲的封面（优先级最高）
        if currentIndex < currentQueue.count,
           let artworkURL = currentQueue[currentIndex].artworkURL {
            await imageCache.preloadImage(from: artworkURL)
        }
        
        // 预加载前后各1首歌的封面
        let preloadRange = max(0, currentIndex - 1)..<min(currentQueue.count, currentIndex + 2)
        
        for i in preloadRange where i != currentIndex {
            if let artworkURL = currentQueue[i].artworkURL {
                await imageCache.preloadImage(from: artworkURL)
            }
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
        let newTime = max(0, currentTime - seconds);
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1))
    }
    
    /// 跳转到指定时间
    func seek(to time: TimeInterval) async {
        await MainActor.run {
            avPlayer?.seek(to: CMTime(seconds: time, preferredTimescale: 1))
            currentTime = time
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
        
        // 🔑 释放音频会话控制权，让其他应用可以恢复播放
        AudioSessionManager.shared.releaseAudioSession(for: .subsonic)
        
        // 🔑 使用统一管理器清除锁屏播放信息
        NowPlayingManager.shared.clearNowPlayingInfo()
        
        print("⏹️ Subsonic停止播放，释放音频会话控制权")
    }
    
    // MARK: - 播放统计
    
    /// 报告播放记录
    func reportPlayback(song: UniversalSong) async throws {
        try await apiClient.scrobble(id: song.id)
    }
    
    // MARK: - 获取当前播放信息
    
    /// 获取当前播放歌曲
    func getCurrentSong() -> UniversalSong? {
        return currentSong
    }
    
    // MARK: - 播放时长计算方法

    /// 计算 Subsonic 队列中所有歌曲的总时长
    func calculateSubsonicQueueTotalDuration(queue: [UniversalSong]) -> TimeInterval {
        let totalDuration = queue.reduce(0) { total, song in
            total + song.duration
        }
        
        // 如果总时长为0，返回默认值
        return totalDuration > 0 ? totalDuration : TimeInterval(queue.count * 180) // 每首歌默认3分钟
    }
    
    /// 计算 Subsonic 队列中已播放的总时长
    func calculateSubsonicQueueElapsedDuration(queue: [UniversalSong], currentIndex: Int, currentTime: TimeInterval) -> TimeInterval {
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
        
        // 🔑 新增：监听音频管理器的停止播放通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStopPlayingNotification),
            name: .subsonicShouldStopPlaying,
            object: nil
        )
        
        // 🔑 新增：监听音频管理器的恢复播放通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResumePlayingNotification),
            name: .subsonicShouldResumePlaying,
            object: nil
        )
    }
    
    // 🔑 新增：处理队列播放完毕
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

    // 🔑 新增：保存原始队列
    private func saveOriginalQueue() {
        originalQueue = currentQueue
        originalIndex = currentIndex
    }

    // 🔑 新增：打乱当前队列
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

    // 🔑 新增：恢复原始队列
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

    // 🔑 新增：设置随机播放
    func setShuffleEnabled(_ enabled: Bool) {
        isShuffleEnabled = enabled
    }

    // 🔑 新增：设置重复播放模式
    func setRepeatMode(_ mode: SubsonicRepeatMode) {
        repeatMode = mode
    }

    // 🔑 新增：获取播放模式状态
    func getPlaybackModes() -> (shuffle: Bool, repeat: SubsonicRepeatMode) {
        return (isShuffleEnabled, repeatMode)
    }

    @objc private func playerDidFinishPlaying() {
        Task {
            // 🔑 根据重复模式处理播放完成
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
    
    // 🔑 修改：移除重复的音频会话中断处理，统一由AudioSessionManager管理
    // @objc private func handleAudioSessionInterruption(notification: Notification) {
    //     guard let userInfo = notification.userInfo,
    //           let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
    //           let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
    //         return
    //     }
    //
    //     switch type {
    //     case .began:
    //         Task {
    //             await pause()
    //         }
    //     case .ended:
    //         if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
    //             let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
    //             if options.contains(.shouldResume) {
    //                 Task {
    //                     await play()
    //                 }
    //             }
    //         }
    //     @unknown default:
    //         break
    //     }
    // }
    
    @objc private func handleStopPlayingNotification() {
        print("🛑 收到停止播放通知（其他音乐应用已启动）")
        // 🔑 简化：直接调用暂停，不使用Task包装
        avPlayer?.pause()
        isPlaying = false
        NowPlayingManager.shared.updatePlaybackProgress()
    }
    
    @objc private func handleResumePlayingNotification() {
        print("🔄 收到恢复播放通知")
        avPlayer?.play()
        isPlaying = true
        NowPlayingManager.shared.updatePlaybackProgress()
    }
    
    private func cleanupPlayer() {
        // 🔑 移除观察者
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

// MARK: - Subsonic音乐服务错误

enum SubsonicMusicServiceError: LocalizedError {
    case notConnected
    case noStreamURL
    case playbackFailed
    case queueEmpty
    case audioSessionFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "未连接到Subsonic服务器"
        case .noStreamURL:
            return "无法获取播放链接"
        case .playbackFailed:
            return "播放失败"
        case .queueEmpty:
            return "播放队列为空"
        case .audioSessionFailed:
            return "音频会话配置失败"
        }
    }
}
