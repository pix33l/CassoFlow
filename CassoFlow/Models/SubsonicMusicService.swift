import Foundation
import AVFoundation
import Combine
import MediaPlayer

/// Subsonic音乐服务管理器
class SubsonicMusicService: NSObject, ObservableObject {
    static let shared = SubsonicMusicService()
    
    // MARK: - 属性
    
    @Published var isConnected: Bool = false
    @Published var isAvailable: Bool = false
    
    private let apiClient = SubsonicAPIClient()
    private var avPlayer: AVPlayer?
    private var avPlayerObserver: Any?
    private var currentSong: UniversalSong?
    
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
        
        // 🔑 延迟设置音频会话和远程控制
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupAudioSession()
            self.setupRemoteCommandCenter()
        }
    }
    
    deinit {
        cleanup()
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
    
    /// 检查服务可用性
    func checkAvailability() async -> Bool {
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
    
    // MARK: - 🔑 新增：音频会话和锁屏播放器配置
    
    /// 设置音频会话
    private func setupAudioSession() {
        // 🔑 在主线程上配置音频会话
        DispatchQueue.main.async {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                
                // 🔑 iOS 18 要求：更严格的音频会话配置
                try audioSession.setCategory(.playback, 
                                           mode: .default, 
                                           options: [.allowAirPlay, .allowBluetooth, .interruptSpokenAudioAndMixWithOthers])
                print("✅ 音频会话类别设置成功")
                
                // 🔑 重要：先停用再激活音频会话
                try audioSession.setActive(false)
                try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                print("✅ 音频会话激活成功")
                
                // 🔑 立即开始接收远程控制事件
                UIApplication.shared.beginReceivingRemoteControlEvents()
                print("✅ 开始接收远程控制事件")
                
            } catch {
                print("❌ Subsonic 音频会话配置失败: \(error)")
            }
        }
    }
    
    /// 激活音频会话（简化版本）
    private func activateAudioSession() {
        // 🔑 简化，只确保会话是激活的
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ 音频会话激活确认")
        } catch {
            print("⚠️ 音频会话激活失败: \(error)")
        }
    }
    
    /// 设置远程控制命令中心（iOS 18 优化版本）
    private func setupRemoteCommandCenter() {
        DispatchQueue.main.async {
            let commandCenter = MPRemoteCommandCenter.shared()
            
            // 🔑 iOS 18：更完整的命令配置
            
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
                print("🎵 锁屏播放命令")
                Task { await self?.play() }
                return .success
            }
            
            // 暂停命令
            commandCenter.pauseCommand.addTarget { [weak self] _ in
                print("⏸️ 锁屏暂停命令")
                Task { await self?.pause() }
                return .success
            }
            
            // 🔑 新增：播放/暂停切换命令
            commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
                print("⏯️ 锁屏播放/暂停切换命令")
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
                print("⏭️ 锁屏下一首命令")
                Task { try? await self?.skipToNext() }
                return .success
            }
            
            // 上一首命令
            commandCenter.previousTrackCommand.addTarget { [weak self] _ in
                print("⏮️ 锁屏上一首命令")
                Task { try? await self?.skipToPrevious() }
                return .success
            }
            
            // 🔑 重要：跳转命令
            commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
                if let event = event as? MPChangePlaybackPositionCommandEvent {
                    let time = event.positionTime
                    print("⏩ 锁屏跳转命令: \(time)秒")
                    Task {
                        await self?.seek(to: time)
                    }
                    return .success
                }
                return .commandFailed
            }
            
            print("✅ 远程控制命令中心配置完成")
        }
    }
    
    /// 更新锁屏播放信息（iOS 18 优化版本）
    private func updateNowPlayingInfo() {
        // 🔑 确保在主线程上执行
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let song = self.currentSong else {
                // 🔑 iOS 18：使用空字典而不是 nil
                MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
                print("🔄 清除锁屏播放信息")
                return
            }
            
            // 🔑 重要：验证播放器状态
            guard let player = self.avPlayer else {
                print("❌ 播放器为空，跳过锁屏信息更新")
                return
            }
            
            var nowPlayingInfo = [String: Any]()
            
            // 🔑 基本信息（必需）
            nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = song.artistName
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.albumName ?? ""
            
            // 🔑 时间信息（关键）- iOS 18 对这些值更敏感
            let safeDuration = self.duration > 0 ? self.duration : song.duration
            let validDuration = max(1.0, safeDuration) // 确保时长至少为1秒
            let validCurrentTime = max(0.0, min(self.currentTime, validDuration)) // 确保当前时间不超过总时长
            
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = validDuration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = validCurrentTime
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.isPlaying ? 1.0 : 0.0
            
            // 🔑 iOS 18 重要：明确设置所有相关属性
            nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
            nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false
            nowPlayingInfo[MPNowPlayingInfoPropertyAvailableLanguageOptions] = []
            nowPlayingInfo[MPNowPlayingInfoPropertyCurrentLanguageOptions] = []
            
            // 🔑 队列信息（如果有的话）
            if !self.currentQueue.isEmpty {
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = self.currentIndex
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = self.currentQueue.count
            }
            
            // 🔑 封面艺术 - 使用更标准的尺寸
            let artworkSize = CGSize(width: 600, height: 600)
            if let defaultImage = UIImage(systemName: "music.note") {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artworkSize) { _ in
                    return defaultImage
                }
            }
            
            // 🔑 iOS 18：一次性设置，不要清除再设置
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            
            print("🔄 设置锁屏播放信息:")
            print("   标题: \(song.title)")
            print("   艺术家: \(song.artistName)")
            print("   时长: \(validDuration)秒")
            print("   当前时间: \(validCurrentTime)秒")
            print("   播放速率: \(self.isPlaying ? 1.0 : 0.0)")
            print("   播放器控制状态: \(player.timeControlStatus.rawValue)")
            
            // 🔑 验证设置结果
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                    print("✅ 锁屏播放信息验证成功，包含 \(info.keys.count) 个字段")
                    print("   字段: \(info.keys.map { $0 })")
                } else {
                    print("❌ 锁屏播放信息验证失败 - 信息为空")
                }
            }
        }
    }
    
    /// 异步加载专辑封面
    private func loadAndSetArtwork(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                    return image
                }
                
                await MainActor.run {
                    var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    updatedInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                    print("🖼️ 专辑封面加载完成")
                }
            }
        } catch {
            print("❌ 加载专辑封面失败: \(error)")
        }
    }
    
    /// 更新播放进度信息（用于定期更新）
    private func updatePlaybackProgress() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
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
        
        // 🔑 激活音频会话
        activateAudioSession()
        
        await MainActor.run {
            currentQueue = songs
            currentIndex = index
            
            // 🔑 重置播放模式相关状态
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
            
            self.avPlayer = AVPlayer(url: url)
            
            // 🔑 设置时长
            if let song = self.currentSong {
                self.duration = song.duration
            }
            
            // 🔑 监听播放器状态变化
            self.avPlayer?.addObserver(self, forKeyPath: "timeControlStatus", options: [.new], context: nil)
            self.avPlayer?.currentItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
            
            // 🔑 修复：时间观察者
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
                        
                        // 🔑 iOS 18：实时更新播放进度
                        if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = newTime
                            info[MPNowPlayingInfoPropertyPlaybackRate] = self.isPlaying ? 1.0 : 0.0
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                        }
                    }
                }
            }
            
            // 🔑 重要：先激活音频会话
            self.activateAudioSession()
            
            // 🔑 开始播放
            self.avPlayer?.play()
            self.isPlaying = true
            
            print("✅ AVPlayer 设置完成，开始播放")
            
            // 🔑 延迟设置播放信息，等待播放器完全准备就绪
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateNowPlayingInfo()
            }
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
                    if player.timeControlStatus == .playing {
                        self?.updateNowPlayingInfo()
                    }
                }
            case "status":
                if let status = self?.avPlayer?.currentItem?.status {
                    print("🎵 播放项状态变化: \(status.rawValue)")
                    if status == .readyToPlay {
                        self?.updateNowPlayingInfo()
                    }
                }
            default:
                break
            }
        }
    }
    
    /// 强制刷新当前播放信息
    private func forceRefreshNowPlaying() {
        // 🔑 强制刷新的方法：先清除再设置
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateNowPlayingInfo()
            print("🔄 强制刷新锁屏播放信息")
        }
    }
    
    /// 刷新远程控制中心
    private func refreshRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // 强制刷新命令状态
        commandCenter.playCommand.isEnabled = !isPlaying
        commandCenter.pauseCommand.isEnabled = isPlaying
        commandCenter.nextTrackCommand.isEnabled = currentIndex < currentQueue.count - 1
        commandCenter.previousTrackCommand.isEnabled = currentIndex > 0
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        
        print("🔄 刷新远程控制中心状态")
    }
    
    /// 监听播放器项目状态变化
    @objc private func playerItemStatusChanged() {
        guard let playerItem = avPlayer?.currentItem else { return }
        
        switch playerItem.status {
        case .readyToPlay:
            print("✅ 播放器准备就绪")
            updateNowPlayingInfo()
        case .failed:
            print("❌ 播放器播放失败: \(playerItem.error?.localizedDescription ?? "未知错误")")
        case .unknown:
            print("⏳ 播放器状态未知")
        @unknown default:
            break
        }
    }
    
    /// 播放
    func play() async {
        avPlayer?.play()
        await MainActor.run {
            isPlaying = true
            // 🔑 更新锁屏播放状态
            updatePlaybackProgress()
        }
    }
    
    /// 暂停
    func pause() async {
        avPlayer?.pause()
        await MainActor.run {
            isPlaying = false
            // 🔑 更新锁屏播放状态
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
            // 🔑 更新锁屏播放进度
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
        
        // 🔑 清除锁屏播放信息
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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
    
    /// 获取播放进度信息
    func getPlaybackInfo() -> (current: TimeInterval, total: TimeInterval, isPlaying: Bool) {
        return (currentTime, duration, isPlaying)
    }
    
    /// 获取队列信息
    func getQueueInfo() -> (queue: [UniversalSong], currentIndex: Int) {
        return (currentQueue, currentIndex)
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
        }
    }
}
