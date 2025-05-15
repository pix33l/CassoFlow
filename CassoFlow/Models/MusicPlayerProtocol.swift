
import MusicKit

/// 音乐播放器协议
protocol MusicPlayer {
    /// 当前播放状态
    var playbackState: MusicPlayer.PlaybackState { get }
    /// 当前播放队列
    var queue: MusicPlayer.Queue { get }
    /// 当前播放的歌曲
    var nowPlayingEntry: MusicPlayer.Queue.Entry? { get }
    
    /// 播放指定歌曲
    func play(entry: MusicPlayer.Queue.Entry) async throws
    /// 暂停播放
    func pause() async throws
    /// 继续播放
    func resume() async throws
    /// 下一首
    func skipToNext() async throws
    /// 上一首
    func skipToPrevious() async throws
    /// 设置播放队列
    func setQueue(with entries: [MusicPlayer.Queue.Entry]) async throws
}

extension MusicPlayer {
    /// 播放状态枚举
    enum PlaybackState {
        case playing
        case paused
        case stopped
        case interrupted
        case seeking
    }
    
    /// 播放队列相关
    struct Queue {
        /// 队列条目
        struct Entry: Equatable, Hashable {
            let item: MusicItem
            let startTime: TimeInterval?
            let endTime: TimeInterval?
        }
        
        let entries: [Entry]
        let startingEntry: Entry?
    }
}
