
import MusicKit

/// 音乐服务类
final class MusicService {
    static let shared = MusicService()
    
    private let player: MusicPlayer = AppleMusicPlayer()
    
    private init() {}
    
    /// 当前播放状态
    var playbackState: MusicPlayer.PlaybackState {
        player.playbackState
    }
    
    /// 当前播放队列
    var queue: MusicPlayer.Queue {
        player.queue
    }
    
    /// 当前播放的歌曲
    var nowPlayingEntry: MusicPlayer.Queue.Entry? {
        player.nowPlayingEntry
    }
    
    /// 请求音乐授权
    func requestAuthorization() async throws -> MusicAuthorization.Status {
        let status = await MusicAuthorization.request()
        return status
    }
    
    /// 搜索音乐
    func searchMusic(term: String) async throws -> MusicItemCollection<Song> {
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = 25
        let response = try await request.response()
        return response.songs
    }
    
    /// 播放指定歌曲
    func play(entry: MusicPlayer.Queue.Entry) async throws {
        try await player.play(entry: entry)
    }
    
    /// 暂停播放
    func pause() async throws {
        try await player.pause()
    }
    
    /// 继续播放
    func resume() async throws {
        try await player.resume()
    }
    
    /// 下一首
    func skipToNext() async throws {
        try await player.skipToNext()
    }
    
    /// 上一首
    func skipToPrevious() async throws {
        try await player.skipToPrevious()
    }
    
    /// 设置播放队列
    func setQueue(with entries: [MusicPlayer.Queue.Entry]) async throws {
        try await player.setQueue(with: entries)
    }
}
