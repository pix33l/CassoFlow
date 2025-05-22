import MusicKit
import Combine
import Foundation

/// 音乐服务类
final class MusicService: ObservableObject {
    static let shared = MusicService()
    
    private let player = SystemMusicPlayer.shared
    
    @Published var currentSong: Song? = nil
    @Published var currentPlaybackTime: TimeInterval = 0
    @Published var songDuration: TimeInterval = 0
    @Published var currentSkin: Skin = .defaultSkin
    @Published var isPlaying: Bool = false
    
    var repeatMode: MusicPlayer.RepeatMode {
        get { player.state.repeatMode ?? .none }
        set { player.state.repeatMode = newValue }
    }
    
    var shuffleMode: MusicPlayer.ShuffleMode {
        get { player.state.shuffleMode ?? .off }
        set { player.state.shuffleMode = newValue }
    }
    
    private init() {
        Task {
            for await _ in player.state.objectWillChange.values {
                let newSong = player.queue.currentEntry?.item as? Song
                let newTime = player.playbackTime
                let newDuration = (player.queue.currentEntry?.item as? Song)?.duration ?? 0
                
                await MainActor.run {
                    currentSong = newSong
                    currentPlaybackTime = newTime
                    songDuration = newDuration
                }
            }
        }
    }
    
    /// 请求音乐授权
    func requestAuthorization() async -> MusicAuthorization.Status {
        await MusicAuthorization.request()
    }
    
    /// 搜索专辑
    func searchAlbums(term: String) async throws -> MusicItemCollection<Album> {
        var request = MusicCatalogSearchRequest(term: term, types: [Album.self])
        request.limit = 25
        return try await request.response().albums
    }
    
    /// 播放专辑
    func playAlbum(_ album: Album) async throws {
        let songs = try await album.with([.tracks]).tracks ?? []
        try await player.queue = .init(for: songs, startingAt: nil)
        try await player.play()
    }
    
    /// 播放控制
    func play() async throws {
        try await player.play()
        await MainActor.run {
            isPlaying = true
        }
    }
    
    func pause() async throws {
        try await player.pause()
        await MainActor.run {
            isPlaying = false
        }
    }
    
    func skipToNext() async throws {
        try await player.skipToNextEntry()
    }
    
    func skipToPrevious() async throws {
        try await player.skipToPreviousEntry()
    }
    
    /// 获取用户媒体库专辑
    func fetchUserLibraryAlbums() async throws -> MusicItemCollection<Album> {
        var request = MusicLibraryRequest<Album>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 100 // 设置合理的限制
        return try await request.response().items
    }

    /// 获取用户媒体库播放列表
    func fetchUserLibraryPlaylists() async throws -> MusicItemCollection<Playlist> {
        var request = MusicLibraryRequest<Playlist>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 100
        return try await request.response().items
    }
    
    func updateCurrentSong() {
        let newSong = player.queue.currentEntry?.item as? Song
        let newTime = player.playbackTime
        let newDuration = (player.queue.currentEntry?.item as? Song)?.duration ?? 0
        
        DispatchQueue.main.async {
            self.currentSong = newSong
            self.currentPlaybackTime = newTime
            self.songDuration = newDuration
        }
    }
}
