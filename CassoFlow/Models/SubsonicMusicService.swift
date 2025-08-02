import Foundation
import AVFoundation
import Combine

/// Subsonic音乐服务管理器
class SubsonicMusicService: ObservableObject {
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
    
    private init() {
        setupNotifications()
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
    
    // MARK: - 数据获取方法
    
    /// 获取最近专辑
    func getRecentAlbums() async throws -> [UniversalAlbum] {
        // 使用getAlbumList2获取最新专辑
        // 这里简化实现，实际可以调用具体的Subsonic API
        return []
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
        await MainActor.run {
            currentQueue = songs
            currentIndex = index
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
        
        await MainActor.run {
            currentSong = song
            setupAVPlayer(with: streamURL)
        }
    }
    
    /// 设置AVPlayer
    private func setupAVPlayer(with url: URL) {
        cleanupPlayer()
        
        avPlayer = AVPlayer(url: url)
        
        // 添加时间观察者
        avPlayerObserver = avPlayer?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            let currentTime = CMTimeGetSeconds(time)
            self?.currentTime = currentTime
        }
        
        // 监听播放完成
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer?.currentItem
        )
        
        // 开始播放
        avPlayer?.play()
        isPlaying = true
        
        // 更新时长
        if let duration = avPlayer?.currentItem?.duration.seconds, !duration.isNaN {
            self.duration = duration
        }
    }
    
    /// 播放
    func play() async {
        avPlayer?.play()
        await MainActor.run {
            isPlaying = true
        }
    }
    
    /// 暂停
    func pause() async {
        avPlayer?.pause()
        await MainActor.run {
            isPlaying = false
        }
    }
    
    /// 下一首
    func skipToNext() async throws {
        if currentIndex < currentQueue.count - 1 {
            await MainActor.run {
                currentIndex += 1
            }
            try await playCurrentSong()
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
    func seek(to time: TimeInterval) {
        avPlayer?.seek(to: CMTime(seconds: time, preferredTimescale: 1))
    }
    
    /// 停止播放
    func stop() {
        avPlayer?.pause()
        cleanupPlayer()
        
        currentSong = nil
        isPlaying = false
        currentTime = 0
        duration = 0
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
    
    @objc private func playerDidFinishPlaying() {
        Task {
            try await skipToNext()
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