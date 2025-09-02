import Foundation
import AVFoundation
import Combine
import MediaPlayer

/// Audio Station 音乐服务
class AudioStationMusicService: ObservableObject {
    static let shared = AudioStationMusicService()
    
    @Published var isConnected: Bool = false
    
    private let apiClient = AudioStationAPIClient
.shared
    private var currentQueue: [UniversalSong] = []
    private var currentIndex: Int = 0
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    
    @Published private var playbackTime: TimeInterval = 0
    @Published private var isPlaying: Bool = false
    
    private var timeObserver: Any?
    private var statusObserver: AnyCancellable?
    
    init() {
        // 监听API客户端的连接状态
        apiClient.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
        
        setupPlayer()
    }
    
    deinit {
        removeTimeObserver()
        statusObserver?.cancel()
        // 🔑 清理锁屏播放信息
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    private func setupPlayer() {
        player = AVPlayer()
        addTimeObserver()
    }
    
    // 🔑 新增：音频会话配置
    private func setupAudioSession() {
        // 🔑 只在初始化时设置一次，不重复激活
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // 🔑 修复：移除 .defaultToSpeaker 选项
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            print("✅ Audio Station 音频会话类别配置成功")
        } catch {
            print("❌ Audio Station 音频会话设置失败: \(error)")
        }
    }
    
    /// 激活音频会话（在播放前调用）
    private func activateAudioSession() {
        // 🔑 只在真正需要播放时才激活，避免冲突
        guard !isPlaying else { 
            print("🔄 Audio Station 音频会话已经激活，跳过重复激活")
            return 
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // 🔑 检查当前会话状态
            if audioSession.category != .playback {
                try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            }
            
            // 🔑 只在非活动状态时才激活
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true)
                print("✅ Audio Station 音频会话已激活")
            } else {
                print("🔄 其他音频正在播放，使用现有会话")
            }
        } catch {
            print("⚠️ Audio Station 音频会话激活失败: \(error)")
            // 不抛出错误，继续播放
        }
    }
    
    // 🔑 新增：远程控制命令中心配置
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // 播放命令
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task {
                await self?.play()
            }
            return .success
        }
        
        // 暂停命令
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task {
                await self?.pause()
            }
            return .success
        }
        
        // 下一首命令
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task {
                try? await self?.skipToNext()
            }
            return .success
        }
        
        // 上一首命令
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task {
                try? await self?.skipToPrevious()
            }
            return .success
        }
        
        // 跳转命令
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                let time = event.positionTime
                Task {
                    await self?.seek(to: time)
                }
                return .success
            }
            return .commandFailed
        }
    }
    
    // 🔑 新增：更新锁屏播放信息
    private func updateNowPlayingInfo() {
        guard currentIndex < currentQueue.count else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        let song = currentQueue[currentIndex]
        var nowPlayingInfo = [String: Any]()
        
        // 基本信息
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artistName
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.albumName ?? ""
        
        // 播放时长和当前进度
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = getCurrentDuration()
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playbackTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // 队列信息
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = currentIndex
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = currentQueue.count
        
        // 🔧 专辑封面（使用智能封面获取）
        Task {
            await loadAndSetArtwork(for: song, info: &nowPlayingInfo)
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // 🔧 改进：异步加载专辑封面
    private func loadAndSetArtwork(for song: UniversalSong, info: inout [String: Any]) async {
        // 优先使用歌曲的artworkURL
        var coverURL: URL? = song.artworkURL
        
        // 如果没有，尝试获取智能封面
        if coverURL == nil, let originalSong = song.originalData as? AudioStationSong {
            coverURL = apiClient.getCoverArtURL(for: originalSong)
        }
        
        guard let url = coverURL else {
            // 使用默认封面
            if let defaultImage = UIImage(systemName: "music.note") {
                await MainActor.run {
                    var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    updatedInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: defaultImage.size) { _ in
                        return defaultImage
                    }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                }
            }
            return
        }
        
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
                }
                
                print("✅ 锁屏封面加载成功")
            }
        } catch {
            print("❌ 锁屏封面加载失败: \(error)")
            
            // 使用默认封面
            if let defaultImage = UIImage(systemName: "music.note") {
                await MainActor.run {
                    var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    updatedInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: defaultImage.size) { _ in
                        return defaultImage
                    }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                }
            }
        }
    }
    
    // 🔑 新增：更新播放进度信息
    private func updatePlaybackProgress() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playbackTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func addTimeObserver() {
        // 🔑 修复：确保时间间隔有效
        let timeInterval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        // 🔑 验证时间间隔是否有效
        if CMTimeCompare(timeInterval, CMTime.zero) > 0 {
            timeObserver = player?.addPeriodicTimeObserver(forInterval: timeInterval, queue: .main) { [weak self] time in
                let seconds = time.seconds
                if seconds.isFinite && !seconds.isNaN {
                    self?.playbackTime = seconds
                    // 🔑 定期更新锁屏播放进度
                    self?.updatePlaybackProgress()
                }
            }
        } else {
            print("❌ Audio Station: 无效的时间间隔，跳过观察者设置")
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    // MARK: - 配置方法
    
    func configure(baseURL: String, username: String, password: String) {
        apiClient.configure(baseURL: baseURL, username: username, password: password)
    }
    
    func getConfiguration() -> (baseURL: String, username: String, password: String) {
        return apiClient.getConfiguration()
    }
    
    // MARK: - 连接管理
    
    func connect() async throws -> Bool {
        return try await apiClient.ping()
    }
    
    func disconnect() async throws {
        try await apiClient.logout()
        stopPlayback()
    }
    
    // 🔑 新增：检查可用性方法（用于库视图）
    func checkAvailability() async -> Bool {
        do {
            let connected = try await connect()
            return connected
        } catch {
            print("Audio Station 连接检查失败: \(error)")
            return false
        }
    }
    
    // MARK: - 数据获取方法
    // 🔑 新增：获取最近专辑方法
    func getRecentAlbums() async throws -> [UniversalAlbum] {
        do {
            // 获取所有专辑
            let audioStationAlbums = try await apiClient.getAlbums()
            
            // 转换为 UniversalAlbum 格式
            let universalAlbums = audioStationAlbums.map { album -> UniversalAlbum in
                UniversalAlbum(
                    id: album.id,
                    title: album.displayName,
                    artistName: album.artistName,
                    year: album.year,
                    genre: album.additional?.song_tag?.genre,
                    songCount: 0, // 需要后续获取歌曲数量
                    duration: album.durationTimeInterval,
                    artworkURL: nil, // 🔧 专辑列表暂时不设置封面，将在详情页获取
                    songs: [], // 专辑详情中填充
                    source: .audioStation,
                    originalData: album as Any
                )
            }
            
            return universalAlbums
        } catch {
            print("获取 Audio Station 专辑失败: \(error)")
            throw error
        }
    }
    
    // 🔑 新增：获取播放列表方法
    func getPlaylists() async throws -> [UniversalPlaylist] {
        do {
            // 获取播放列表
            let audioStationPlaylists = try await apiClient.getPlaylists()
            
            // 转换为 UniversalPlaylist 格式
            let universalPlaylists = audioStationPlaylists.map { playlist -> UniversalPlaylist in
                // 🔧 播放列表通常没有直接的封面，我们先设为nil
                // 封面将在播放列表单元格中动态加载（通过第一首歌曲）
                
                return UniversalPlaylist(
                    id: playlist.id,
                    name: playlist.name,
                    curatorName: nil, // Audio Station 播放列表可能没有创建者信息
                    songCount: playlist.additional?.song_tag?.track ?? 0,
                    duration: playlist.durationTimeInterval,
                    artworkURL: nil, // 🔧 播放列表封面将通过其他方式获取
                    songs: [], // 播放列表详情中填充
                    source: .audioStation,
                    originalData: playlist as Any
                )
            }
            
            return universalPlaylists
        } catch {
            print("获取 Audio Station 播放列表失败: \(error)")
            throw error
        }
    }

    // 🔑 新增：获取艺术家方法
    func getArtists() async throws -> [UniversalArtist] {
        do {
            // 获取艺术家
            let audioStationArtists = try await apiClient.getArtists()
            
            // 转换为 UniversalArtist 格式
            let universalArtists = audioStationArtists.map { artist -> UniversalArtist in
                UniversalArtist(
                    id: artist.id,
                    name: artist.name,
                    albumCount: artist.albumCount,
                    albums: [], // 艺术家详情中填充
                    source: .audioStation,
                    originalData: artist as Any
                )
            }
            
            return universalArtists
        } catch {
            print("获取 Audio Station 艺术家失败: \(error)")
            throw error
        }
    }
    
    // 🔑 新增：获取专辑详情方法（用于专辑详情视图）
    func getAlbum(id: String) async throws -> UniversalAlbum {
        do {
            // 获取专辑详情
            let audioStationAlbum = try await apiClient.getAlbum(id: id)
            
            // 获取专辑歌曲
            let audioStationSongs = try await apiClient.getAlbumSongs(albumId: id)
            
            // 转换歌曲为 UniversalSong 格式
            let universalSongs = audioStationSongs.map { song -> UniversalSong in
                UniversalSong(
                    id: song.id,
                    title: song.title,
                    artistName: song.artistName,
                    albumName: song.album,
                    duration: song.durationTimeInterval,
                    trackNumber: song.track,
                    artworkURL: apiClient.getCoverArtURL(for: song), // 🔧 使用新的封面方法
                    streamURL: apiClient.getStreamURL(id: song.id),
                    source: .audioStation,
                    originalData: song as Any
                )
            }
            
            // 🔧 使用专辑封面API
            let albumCoverURL = apiClient.getCoverArtURL(for: audioStationAlbum)
            
            // 创建完整的 UniversalAlbum
            let universalAlbum = UniversalAlbum(
                id: audioStationAlbum.id,
                title: audioStationAlbum.displayName,
                artistName: audioStationAlbum.artistName,
                year: audioStationAlbum.year,
                genre: audioStationAlbum.additional?.song_tag?.genre,
                songCount: universalSongs.count,
                duration: universalSongs.reduce(0) { $0 + $1.duration },
                artworkURL: albumCoverURL, // 🔧 使用专辑封面方法
                songs: universalSongs,
                source: .audioStation,
                originalData: audioStationAlbum as Any
            )
            
            return universalAlbum
        } catch {
            print("获取 Audio Station 专辑详情失败: \(error)")
            throw error
        }
    }
    
    // 🔑 新增：获取播放列表详情方法（用于播放列表详情视图）
    func getPlaylist(id: String) async throws -> UniversalPlaylist {
        do {
            // 🔧 首先从播放列表列表中找到对应的播放列表
            let playlists = try await getPlaylists()
            guard let playlist = playlists.first(where: { $0.id == id }) else {
                throw AudioStationError.apiError("未找到指定播放列表")
            }
            
            // 🔧 尝试获取播放列表中的歌曲
            // 对于AudioStation，我们尝试通过播放列表名称搜索相关歌曲
            print("🎵 尝试获取播放列表歌曲: \(playlist.name)")
            
            var playlistSongs: [UniversalSong] = []
            
            // 方法1: 尝试使用搜索功能查找相关歌曲
            do {
                let searchResult = try await apiClient.search(query: playlist.name)
                
                // 将搜索到的歌曲转换为UniversalSong
                playlistSongs = searchResult.songs.map { song -> UniversalSong in
                    UniversalSong(
                        id: song.id,
                        title: song.title,
                        artistName: song.artistName,
                        albumName: song.album,
                        duration: song.durationTimeInterval,
                        trackNumber: song.track,
                        artworkURL: apiClient.getCoverArtURL(for: song),
                        streamURL: apiClient.getStreamURL(id: song.id),
                        source: .audioStation,
                        originalData: song as Any
                    )
                }
                
                print("✅ 通过搜索获取到播放列表歌曲: \(playlistSongs.count) 首")
            } catch {
                print("❌ 搜索播放列表歌曲失败: \(error)")
                // 如果搜索失败，返回空的播放列表
                playlistSongs = []
            }
            
            // 🔧 获取播放列表封面（使用第一首歌曲的封面）
            var playlistCoverURL: URL?
            if let firstSong = playlistSongs.first,
               let originalSong = firstSong.originalData as? AudioStationSong {
                playlistCoverURL = apiClient.getCoverArtURL(for: originalSong)
            }
            
            let detailedPlaylist = UniversalPlaylist(
                id: playlist.id,
                name: playlist.name,
                curatorName: playlist.curatorName,
                songCount: playlistSongs.count,
                duration: playlistSongs.reduce(0) { $0 + $1.duration },
                artworkURL: playlistCoverURL, // 🔧 使用第一首歌曲的封面
                songs: playlistSongs,
                source: .audioStation,
                originalData: playlist.originalData
            )
            
            return detailedPlaylist
        } catch {
            print("获取 Audio Station 播放列表详情失败: \(error)")
            throw error
        }
    }
    
    // 🔑 新增：获取艺术家详情方法（用于艺术家详情视图）
    func getArtist(id: String) async throws -> UniversalArtist {
        do {
            // 获取艺术家歌曲
            let audioStationSongs = try await apiClient.getArtistSongs(artistId: id)
            
            // 转换歌曲为 UniversalSong 格式
            let universalSongs = audioStationSongs.map { song -> UniversalSong in
                UniversalSong(
                    id: song.id,
                    title: song.title,
                    artistName: song.artistName,
                    albumName: song.album,
                    duration: song.durationTimeInterval,
                    trackNumber: song.track,
                    artworkURL: apiClient.getCoverArtURL(for: song), // 🔧 使用新的封面方法
                    streamURL: apiClient.getStreamURL(id: song.id),
                    source: .audioStation,
                    originalData: song as Any
                )
            }
            
            // 按专辑分组歌曲
            let albumsByTitle = Dictionary(grouping: universalSongs) { song in
                song.albumName ?? "未知专辑"
            }
            
            // 创建专辑列表
            let universalAlbums = albumsByTitle.map { (albumName, songs) -> UniversalAlbum in
                UniversalAlbum(
                    id: "artist_\(id)_album_\(albumName)",
                    title: albumName,
                    artistName: songs.first?.artistName ?? "未知艺术家",
                    year: nil, // UniversalSong没有year属性，使用nil
                    genre: nil, // UniversalSong没有genre属性，使用nil
                    songCount: songs.count,
                    duration: songs.reduce(0) { $0 + $1.duration },
                    artworkURL: songs.first?.artworkURL, // 🔧 使用第一首歌曲的封面
                    songs: songs,
                    source: .audioStation,
                    originalData: Optional<Any>.none as Any // 将nil转换为Any类型
                )
            }
            
            // 获取艺术家信息
            // 注意：这里可能需要通过其他方式获取艺术家信息，因为我们没有直接的 getArtist API
            let artistName = universalSongs.first?.artistName ?? "未知艺术家"
            
            // 创建完整的 UniversalArtist
            let universalArtist = UniversalArtist(
                id: id,
                name: artistName,
                albumCount: universalAlbums.count,
                albums: universalAlbums,
                source: .audioStation,
                originalData: Optional<Any>.none as Any // 将nil转换为Any类型
            )
            
            return universalArtist
        } catch {
            print("获取 Audio Station 艺术家详情失败: \(error)")
            throw error
        }
    }
    
    // MARK: - 播放队列管理
    
    func playQueue(_ songs: [UniversalSong], startingAt index: Int = 0) async throws {
        // 🔑 在首次播放时才初始化连接和音频会话
        if !isConnected {
            let connected = try await connect()
            if !connected {
                throw AudioStationError.authenticationFailed("连接失败")
            }
            // 🔑 只在连接成功后设置音频会话和远程控制
            setupAudioSession()
            setupRemoteCommandCenter()
            // 🔑 开始接收远程控制事件
            DispatchQueue.main.async {
                UIApplication.shared.beginReceivingRemoteControlEvents()
                print("✅ Audio Station 开始接收远程控制事件")
            }
        }
        
        currentQueue = songs
        currentIndex = max(0, min(index, songs.count - 1))
        
        if !songs.isEmpty {
            try await playSongAtCurrentIndex()
        }
    }
    
    private func playSongAtCurrentIndex() async throws {
        guard currentIndex < currentQueue.count else { return }
        
        let song = currentQueue[currentIndex]
        guard let streamURL = song.streamURL else {
            throw AudioStationError.apiError("无法获取歌曲流URL")
        }
        
        print("🎵 准备播放: \(song.title) - URL: \(streamURL)")
        
        // 🔑 激活音频会话
        activateAudioSession()
        
        await MainActor.run {
            playerItem = AVPlayerItem(url: streamURL)
            player?.replaceCurrentItem(with: playerItem)
            
            // 监听播放状态
            statusObserver?.cancel()
            statusObserver = playerItem?.publisher(for: \.status)
                .sink { [weak self] status in
                    switch status {
                    case .readyToPlay:
                        print("✅ 歌曲准备就绪，开始播放")
                        self?.player?.play()
                        self?.isPlaying = true
                        // 🔑 更新锁屏播放信息
                        self?.updateNowPlayingInfo()
                    case .failed:
                        let error = self?.playerItem?.error?.localizedDescription ?? "未知错误"
                        print("❌ 播放失败: \(error)")
                        if let playerError = self?.playerItem?.error {
                            print("❌ 详细错误: \(playerError)")
                        }
                        self?.isPlaying = false
                        // 🔑 清除锁屏播放信息
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                        
                        // 🔧 尝试使用转码后的格式重新播放
                        Task {
                            await self?.retryWithTranscodedFormat()
                        }
                    case .unknown:
                        print("🔄 播放状态未知")
                    @unknown default:
                        print("🔄 播放状态: \(status)")
                    }
                }
        }
    }
    
    // 🔧 新增：使用转码格式重试播放
    private func retryWithTranscodedFormat() async {
        guard currentIndex < currentQueue.count else { return }
        
        let song = currentQueue[currentIndex]
        
        // 🔧 尝试使用转码的MP3格式
        if let transcodedURL = apiClient.getTranscodedStreamURL(id: song.id) {
            print("🔄 尝试使用转码格式播放: \(transcodedURL)")
            
            await MainActor.run {
                let newPlayerItem = AVPlayerItem(url: transcodedURL)
                player?.replaceCurrentItem(with: newPlayerItem)
                playerItem = newPlayerItem
                
                // 重新监听状态
                statusObserver?.cancel()
                statusObserver = newPlayerItem.publisher(for: \.status)
                    .sink { [weak self] status in
                        if status == .readyToPlay {
                            print("✅ 转码格式播放成功")
                            self?.player?.play()
                            self?.isPlaying = true
                            self?.updateNowPlayingInfo()
                        } else if status == .failed {
                            let error = newPlayerItem.error?.localizedDescription ?? "未知错误"
                            print("❌ 转码格式也播放失败: \(error)")
                            self?.isPlaying = false
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                        }
                    }
            }
        }
    }
    
    func play() async {
        // 🔑 激活音频会话
        activateAudioSession()
        
        await MainActor.run {
            player?.play()
            isPlaying = true
            // 🔑 更新锁屏播放状态
            updatePlaybackProgress()
        }
    }
    
    func pause() async {
        await MainActor.run {
            player?.pause()
            isPlaying = false
            // 🔑 更新锁屏播放状态
            updatePlaybackProgress()
        }
    }
    
    func stop() async {
        await MainActor.run {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            isPlaying = false
            playbackTime = 0
            // 🔑 清除锁屏播放信息
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }
    
    func skipToNext() async throws {
        guard currentIndex < currentQueue.count - 1 else { return }
        currentIndex += 1
        try await playSongAtCurrentIndex()
    }
    
    func skipToPrevious() async throws {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        try await playSongAtCurrentIndex()
    }
    
    // MARK: - 播放进度控制
    
    func seek(to time: TimeInterval) async {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        await MainActor.run {
            player?.seek(to: cmTime)
            playbackTime = time
            // 🔑 更新锁屏播放进度
            updatePlaybackProgress()
        }
    }
    
    func seekForward(_ interval: TimeInterval) {
        let newTime = min(getCurrentDuration(), playbackTime + interval)
        Task {
            await seek(to: newTime)
        }
    }
    
    func seekBackward(_ interval: TimeInterval) {
        let newTime = max(0, playbackTime - interval)
        Task {
            await seek(to: newTime)
        }
    }
    
    // MARK: - 播放时长计算方法

    /// 计算 Audio Station 队列中所有歌曲的总时长
    func calculateAudioStationQueueTotalDuration(queue: [UniversalSong]) -> TimeInterval {
        let totalDuration = queue.reduce(0) { total, song in
            total + song.duration
        }
        
        // 如果总时长为0，返回默认值
        return totalDuration > 0 ? totalDuration : TimeInterval(queue.count * 180) // 每首歌默认3分钟
    }
    
    /// 计算 Audio Station 队列中已播放的总时长
    func calculateAudioStationQueueElapsedDuration(queue: [UniversalSong], currentIndex: Int, currentTime: TimeInterval) -> TimeInterval {
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
    
    // MARK: - 状态获取
    
    func getCurrentSong() -> UniversalSong? {
        guard currentIndex < currentQueue.count else { return nil }
        return currentQueue[currentIndex]
    }
    
    func getQueueInfo() -> (queue: [UniversalSong], currentIndex: Int, totalCount: Int) {
        return (currentQueue, currentIndex, currentQueue.count)
    }
    
    func getPlaybackInfo() -> (current: TimeInterval, total: TimeInterval, isPlaying: Bool) {
        return (playbackTime, getCurrentDuration(), isPlaying)
    }
    
    private func getCurrentDuration() -> TimeInterval {
        guard let duration = playerItem?.duration, duration.isValid else { return 0 }
        return duration.seconds
    }
    
    private func stopPlayback() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        currentQueue.removeAll()
        currentIndex = 0
        isPlaying = false
        playbackTime = 0
        // 🔑 清除锁屏播放信息
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
