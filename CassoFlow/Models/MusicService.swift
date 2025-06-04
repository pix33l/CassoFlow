import MusicKit
import Combine
import Foundation

/// 音乐服务类
class MusicService: ObservableObject {
    static let shared = MusicService()
    
    private let player = SystemMusicPlayer.shared
    
    @Published var currentPlaybackTime: TimeInterval = 0
    @Published var songDuration: TimeInterval = 0
    @Published var currentSkin: Skin = .CFDT1
    @Published var isPlaying: Bool = false
    
    var repeatMode: MusicPlayer.RepeatMode {
        get { player.state.repeatMode ?? .none }
        set { player.state.repeatMode = newValue }
    }
    
    var shuffleMode: MusicPlayer.ShuffleMode {
        get { player.state.shuffleMode ?? .off }
        set { player.state.shuffleMode = newValue }
    }
    
    /// 请求音乐授权
    func requestAuthorization() async -> MusicAuthorization.Status {
        await MusicAuthorization.request()
    }
    
    /// 播放专辑中的特定歌曲
    func playTrack(_ track: Track, in album: Album) async throws {
        let songs = try await album.with([.tracks]).tracks ?? []
        guard let index = songs.firstIndex(where: { $0.id == track.id }) else { return }
        
        player.queue = .init(for: songs, startingAt: songs[index])
        try await player.play()
    }
    
    /// 播放专辑（可选择随机播放）
    func playAlbum(_ album: Album, shuffled: Bool = false) async throws {
        let songs = try await album.with([.tracks]).tracks ?? []
        if shuffled {
            player.state.shuffleMode = .songs
        }
        player.queue = .init(for: songs, startingAt: nil)
        try await player.play()
    }
    
    /// 播放专辑（可选择随机播放）
    func playPlaylist(_ playlist: Playlist, shuffled: Bool = false) async throws {
        let songs = try await playlist.with([.tracks]).tracks ?? []
        if shuffled {
            player.state.shuffleMode = .songs
        }
        player.queue = .init(for: songs, startingAt: nil)
        try await player.play()
    }
    
    /// 播放控制
    func play() async throws {
        try await player.play()
        await MainActor.run {
            isPlaying = true
        }
    }
    
    func pause() async {
        player.pause()
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
}
