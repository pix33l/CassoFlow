import MusicKit
import Foundation
//import MediaPlayer

/// MusicKit 服务类 - 专门处理 Apple Music 相关功能
class MusicKitService: ObservableObject {
    static let shared = MusicKitService()
    
    private let musicKitPlayer = ApplicationMusicPlayer.shared
    private lazy var musicService = MusicService.shared
    
    // MARK: - 播放控制方法
    
    /// 播放专辑中的特定歌曲
    func playTrack(_ track: Track, in album: Album) async throws {
        let songs = try await album.with([.tracks]).tracks ?? []
        guard let index = songs.firstIndex(where: { $0.id == track.id }) else { return }
        
        musicKitPlayer.queue = .init(for: songs, startingAt: songs[index])
        try await musicKitPlayer.play()
        
        await MainActor.run {
            musicService.shouldCloseLibrary = true
        }
        
        // 🔑 增加延迟时间，确保MusicKit播放器完全初始化
        try await Task.sleep(nanoseconds: 500_000_000) // 延迟0.5秒
        await musicService.forceSyncPlaybackStatus()
    }
    
    /// 播放播放列表中的特定歌曲
    func playTrack(_ track: Track, in playlist: Playlist) async throws {
        let songs = try await playlist.with([.tracks]).tracks ?? []
        guard let index = songs.firstIndex(where: { $0.id == track.id }) else { return }
        
        musicKitPlayer.queue = .init(for: songs, startingAt: songs[index])
        try await musicKitPlayer.play()
        
        await MainActor.run {
            musicService.shouldCloseLibrary = true
        }
        
        // 🔑 增加延迟时间，确保MusicKit播放器完全初始化
        try await Task.sleep(nanoseconds: 500_000_000) // 延迟0.5秒
        await musicService.forceSyncPlaybackStatus()
    }
    
    /// 播放专辑（可选择随机播放）
    func playAlbum(_ album: Album, shuffled: Bool = false) async throws {
        let songs = try await album.with([.tracks]).tracks ?? []
        if shuffled {
            musicKitPlayer.state.shuffleMode = .songs
        }
        musicKitPlayer.queue = .init(for: songs, startingAt: nil)
        try await musicKitPlayer.play()
        
        await MainActor.run {
            musicService.shouldCloseLibrary = true
        }
        
        // 🔑 增加延迟时间，确保MusicKit播放器完全初始化
        try await Task.sleep(nanoseconds: 500_000_000) // 延迟0.5秒
        await musicService.forceSyncPlaybackStatus()
    }
    
    /// 播放播放列表（可选择随机播放）
    func playPlaylist(_ playlist: Playlist, shuffled: Bool = false) async throws {
        let songs = try await playlist.with([.tracks]).tracks ?? []
        if shuffled {
            musicKitPlayer.state.shuffleMode = .songs
        }
        musicKitPlayer.queue = .init(for: songs, startingAt: nil)
        try await musicKitPlayer.play()
        
        await MainActor.run {
            musicService.shouldCloseLibrary = true
        }
        
        // 🔑 增加延迟时间，确保MusicKit播放器完全初始化
        try await Task.sleep(nanoseconds: 500_000_000) // 延迟0.5秒
        await musicService.forceSyncPlaybackStatus()
    }
    
    /// 播放
    func play() async throws {
        try await musicKitPlayer.play()
    }
    
    /// 暂停
    func pause() {
        musicKitPlayer.pause()
    }
    
    /// 播放下一首
    func skipToNext() async throws {
        try await musicKitPlayer.skipToNextEntry()
    }
    
    /// 播放上一首
    func skipToPrevious() async throws {
        try await musicKitPlayer.skipToPreviousEntry()
    }
    
    /// 停止播放
    func stop() {
        musicKitPlayer.stop()
    }
    
    // MARK: - 播放状态获取
    
    /// 获取当前播放条目
    var currentEntry: ApplicationMusicPlayer.Queue.Entry? {
        return musicKitPlayer.queue.currentEntry
    }
    
    /// 获取播放队列条目
    var queueEntries: ApplicationMusicPlayer.Queue.Entries {
        return musicKitPlayer.queue.entries
    }
    
    /// 获取播放时间
    var playbackTime: TimeInterval {
        return musicKitPlayer.playbackTime
    }
    
    /// 设置播放时间
    func setPlaybackTime(_ time: TimeInterval) {
        musicKitPlayer.playbackTime = time
    }
    
    /// 获取播放状态
    var isPlaying: Bool {
        return musicKitPlayer.state.playbackStatus == .playing
    }
    
    /// 获取循环模式
    var repeatMode: MusicKit.MusicPlayer.RepeatMode {
        get { musicKitPlayer.state.repeatMode ?? .none }
        set { musicKitPlayer.state.repeatMode = newValue }
    }
    
    /// 获取随机播放模式
    var shuffleMode: MusicKit.MusicPlayer.ShuffleMode {
        get { musicKitPlayer.state.shuffleMode ?? .off }
        set { musicKitPlayer.state.shuffleMode = newValue }
    }
    
    // MARK: - 队列时长计算
    
    /// 计算队列中所有歌曲的总时长
    func calculateQueueTotalDuration(entries: ApplicationMusicPlayer.Queue.Entries) -> TimeInterval {
        var totalDuration: TimeInterval = 0
        
        for entry in entries {
            switch entry.item {
            case .song(let song):
                totalDuration += song.duration ?? 0
            case .musicVideo(let musicVideo):
                totalDuration += musicVideo.duration ?? 0
            default:
                // 对于其他类型，使用默认时长3分钟
                totalDuration += 180.0
            }
        }
        
        // 如果总时长为0，返回默认值
        return totalDuration > 0 ? totalDuration : 180.0
    }
    
    /// 计算队列中已播放的总时长
    func calculateQueueElapsedDuration(entries: ApplicationMusicPlayer.Queue.Entries, currentEntryIndex: Int?) -> TimeInterval {
        guard let currentIndex = currentEntryIndex else { return 0 }
        
        var elapsedDuration: TimeInterval = 0
        
        // 计算当前歌曲之前所有歌曲的总时长
        for (index, entry) in entries.enumerated() {
            if index < currentIndex {
                switch entry.item {
                case .song(let song):
                    elapsedDuration += song.duration ?? 0
                case .musicVideo(let musicVideo):
                    elapsedDuration += musicVideo.duration ?? 0
                default:
                    elapsedDuration += 180.0 // 默认3分钟
                }
            } else {
                break
            }
        }
        
        // 加上当前歌曲的播放时长
        elapsedDuration += musicKitPlayer.playbackTime
        
        return elapsedDuration
    }
    
    /// 更新队列已播放时长
    func updateQueueElapsedDuration() -> TimeInterval {
        let entries = musicKitPlayer.queue.entries
        let currentEntry = musicKitPlayer.queue.currentEntry
        let trackIndex = entries.firstIndex(where: { $0.id == currentEntry?.id })
        return calculateQueueElapsedDuration(entries: entries, currentEntryIndex: trackIndex)
    }
    
    // MARK: - 用户库相关
    
    /// 获取用户媒体库专辑
    func fetchUserLibraryAlbums() async throws -> MusicItemCollection<Album> {
        var request = MusicLibraryRequest<Album>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 200 // 设置合理的限制
        
        let response = try await request.response()
        return response.items
    }
    
    /// 获取用户媒体库播放列表
    func fetchUserLibraryPlaylists() async throws -> MusicItemCollection<Playlist> {
        var request = MusicLibraryRequest<Playlist>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 200
        
        let response = try await request.response()
        return response.items
    }
    
    // MARK: - 授权相关
    
    /// 请求音乐授权
    func requestMusicAuthorization() async {
        let status = await MusicAuthorization.request()
        
        switch status {
        case .authorized:
            await setupMusicKit()
        case .denied, .notDetermined, .restricted:
            break
        @unknown default:
            break
        }
    }
    
    /// 设置MusicKit
    private func setupMusicKit() async {
        do {
            // 检查订阅状态
            _ = try await MusicSubscription.current
        } catch {
            // 设置失败，静默处理
        }
    }
}
