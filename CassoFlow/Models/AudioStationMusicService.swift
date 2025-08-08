import Foundation
import AVFoundation
import Combine
import MediaPlayer

/// Audio Station 音乐服务
class AudioStationMusicService: ObservableObject {
    static let shared = AudioStationMusicService()
    
    @Published var isConnected: Bool = false
    
    private let apiClient = AudioStationAPIClient.shared
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
        setupAudioSession()
        setupRemoteCommandCenter()
        
        // 🔑 重要：开始接收远程控制事件
        DispatchQueue.main.async {
            UIApplication.shared.beginReceivingRemoteControlEvents()
            print("✅ Audio Station 开始接收远程控制事件")
        }
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
        
        // 专辑封面（异步加载）
        if let artworkURL = song.artworkURL {
            Task {
                await loadAndSetArtwork(from: artworkURL, info: &nowPlayingInfo)
            }
        } else {
            // 没有封面时使用默认封面
            if let defaultImage = UIImage(systemName: "music.note") {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: defaultImage.size) { _ in
                    return defaultImage
                }
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // 🔑 新增：异步加载专辑封面
    private func loadAndSetArtwork(from url: URL, info: inout [String: Any]) async {
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
            }
        } catch {
            print("加载专辑封面失败: \(error)")
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
    
    // MARK: - 播放队列管理
    
    func playQueue(_ songs: [UniversalSong], startingAt index: Int = 0) async throws {
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
        
        // 🔑 激活音频会话
        activateAudioSession()
        
        await MainActor.run {
            playerItem = AVPlayerItem(url: streamURL)
            player?.replaceCurrentItem(with: playerItem)
            
            // 监听播放状态
            statusObserver?.cancel()
            statusObserver = playerItem?.publisher(for: \.status)
                .sink { [weak self] status in
                    if status == .readyToPlay {
                        self?.player?.play()
                        self?.isPlaying = true
                        // 🔑 更新锁屏播放信息
                        self?.updateNowPlayingInfo()
                    } else if status == .failed {
                        print("播放失败: \(self?.playerItem?.error?.localizedDescription ?? "未知错误")")
                        self?.isPlaying = false
                        // 🔑 清除锁屏播放信息
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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