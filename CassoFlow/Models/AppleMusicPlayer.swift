
import MusicKit

/// Apple Music播放器实现
final class AppleMusicPlayer: MusicPlayer {
    private let systemPlayer = SystemMusicPlayer.shared
    
    var playbackState: MusicPlayer.PlaybackState {
        switch systemPlayer.state.playbackStatus {
        case .playing: return .playing
        case .paused: return .paused
        case .stopped: return .stopped
        case .interrupted: return .interrupted
        case .seeking: return .seeking
        @unknown default: return .stopped
        }
    }
    
    var queue: MusicPlayer.Queue {
        let entries = systemPlayer.queue.entries.map { entry in
            MusicPlayer.Queue.Entry(
                item: entry.item,
                startTime: entry.startTime,
                endTime: entry.endTime
            )
        }
        return MusicPlayer.Queue(
            entries: entries,
            startingEntry: systemPlayer.queue.startingEntry.map { entry in
                MusicPlayer.Queue.Entry(
                    item: entry.item,
                    startTime: entry.startTime,
                    endTime: entry.endTime
                )
            }
        )
    }
    
    var nowPlayingEntry: MusicPlayer.Queue.Entry? {
        guard let entry = systemPlayer.queue.currentEntry else { return nil }
        return MusicPlayer.Queue.Entry(
            item: entry.item,
            startTime: entry.startTime,
            endTime: entry.endTime
        )
    }
    
    func play(entry: MusicPlayer.Queue.Entry) async throws {
        let systemEntry = SystemMusicPlayer.Queue.Entry(
            item: entry.item,
            startTime: entry.startTime,
            endTime: entry.endTime
        )
        try await systemPlayer.play(entry: systemEntry)
    }
    
    func pause() async throws {
        try await systemPlayer.pause()
    }
    
    func resume() async throws {
        try await systemPlayer.play()
    }
    
    func skipToNext() async throws {
        try await systemPlayer.skipToNextEntry()
    }
    
    func skipToPrevious() async throws {
        try await systemPlayer.skipToPreviousEntry()
    }
    
    func setQueue(with entries: [MusicPlayer.Queue.Entry]) async throws {
        let systemEntries = entries.map { entry in
            SystemMusicPlayer.Queue.Entry(
                item: entry.item,
                startTime: entry.startTime,
                endTime: entry.endTime
            )
        }
        try await systemPlayer.queue = .init(for: systemEntries)
    }
}
