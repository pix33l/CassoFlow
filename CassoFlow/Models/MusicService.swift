import MusicKit
import Combine
import Foundation
import UIKit

/// 音乐服务类
class MusicService: ObservableObject {
    static let shared = MusicService()
    
    
    
    private let player = ApplicationMusicPlayer.shared
    private let audioEffectsManager = AudioEffectsManager.shared
    
    @Published var currentTitle: String = ""
    @Published var currentArtist: String = ""
    @Published var currentDuration: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var isPlaying: Bool = false
    @Published var currentTrackID: MusicItemID?
    @Published var currentPlayerSkin: PlayerSkin
    @Published var currentCassetteSkin: CassetteSkin
    @Published var currentTrackIndex: Int? = nil
    @Published var totalTracksInQueue: Int = 0
    
    @Published var queueTotalDuration: TimeInterval = 0
    @Published var queueElapsedDuration: TimeInterval = 0
    
    @Published var isFastForwarding: Bool = false
    @Published var isFastRewinding: Bool = false
    private var seekTimer: Timer?
    
    // MARK: - 磁带音效属性
    @Published var isCassetteEffectEnabled: Bool = false {
        didSet {
            audioEffectsManager.setCassetteEffect(enabled: isCassetteEffectEnabled)
        }
    }
    
    @Published var isHapticFeedbackEnabled: Bool = false

    // MARK: - 屏幕常亮属性
    @Published var isScreenAlwaysOn: Bool = false {
        didSet {
            // 设置屏幕常亮状态
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = self.isScreenAlwaysOn
            }
        }
    }
    
    // MARK: - 皮肤存储键值
    private static let playerSkinKey = "SelectedPlayerSkin"
    private static let cassetteSkinKey = "SelectedCassetteSkin"
    private static let cassetteEffectKey = "CassetteEffectEnabled"
    private static let hapticFeedbackKey = "HapticFeedbackEnabled"
    private static let screenAlwaysOnKey = "ScreenAlwaysOnEnabled"
    
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
    
    /// 播放播放列表中的特定歌曲
    func playTrack(_ track: Track, in playlist: Playlist) async throws {
        let songs = try await playlist.with([.tracks]).tracks ?? []
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
    
    init() {
        // 从 UserDefaults 加载保存的皮肤，如果没有则使用默认值
        let savedPlayerSkinName = UserDefaults.standard.string(forKey: Self.playerSkinKey)
        if let skinName = savedPlayerSkinName,
           let skin = PlayerSkin.playerSkin(named: skinName) {
            print("🎨 加载已保存的播放器皮肤: \(skinName)")
            currentPlayerSkin = skin
        } else {
            let defaultSkin = PlayerSkin.playerSkin(named: "CF-DEMO") ?? PlayerSkin.playerSkins[0]
            print("🎨 使用默认播放器皮肤: \(defaultSkin.name)")
            currentPlayerSkin = defaultSkin
        }
        
        let savedCassetteSkinName = UserDefaults.standard.string(forKey: Self.cassetteSkinKey)
        if let skinName = savedCassetteSkinName,
           let skin = CassetteSkin.cassetteSkin(named: skinName) {
            print("🎨 加载已保存的磁带皮肤: \(skinName)")
            currentCassetteSkin = skin
        } else {
            let defaultSkin = CassetteSkin.cassetteSkin(named: "CFT-DEMO") ?? CassetteSkin.cassetteSkins[0]
            print("🎨 使用默认磁带皮肤: \(defaultSkin.name)")
            currentCassetteSkin = defaultSkin
        }
        
        // 加载磁带音效设置
        isCassetteEffectEnabled = UserDefaults.standard.bool(forKey: Self.cassetteEffectKey)
        print("🎵 加载磁带音效设置: \(isCassetteEffectEnabled)")
        
        // 加载触觉反馈设置
        if UserDefaults.standard.object(forKey: Self.hapticFeedbackKey) == nil {
            // 首次启动时设置默认值为false
            isHapticFeedbackEnabled = false
            UserDefaults.standard.set(false, forKey: Self.hapticFeedbackKey)
        } else {
            isHapticFeedbackEnabled = UserDefaults.standard.bool(forKey: Self.hapticFeedbackKey)
        }
        print("📳 加载触觉反馈设置: \(isHapticFeedbackEnabled)")
        
        // 加载屏幕常亮设置
        isScreenAlwaysOn = UserDefaults.standard.bool(forKey: Self.screenAlwaysOnKey)
        print("🔆 加载屏幕常亮设置: \(isScreenAlwaysOn)")
        // 应用屏幕常亮设置
        UIApplication.shared.isIdleTimerDisabled = isScreenAlwaysOn
        
        // 监听播放器队列变化
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCurrentSongInfo()
        }
    }
    
    // MARK: - 皮肤持久化方法
    
    /// 设置并保存播放器皮肤
    func setPlayerSkin(_ skin: PlayerSkin) {
        currentPlayerSkin = skin
        UserDefaults.standard.set(skin.name, forKey: Self.playerSkinKey)
        print("🎨 保存播放器皮肤: \(skin.name)")
    }
    
    /// 设置并保存磁带皮肤
    func setCassetteSkin(_ skin: CassetteSkin) {
        currentCassetteSkin = skin
        UserDefaults.standard.set(skin.name, forKey: Self.cassetteSkinKey)
        print("🎨 保存磁带皮肤: \(skin.name)")
    }
    
    /// 设置磁带音效开关
    func setCassetteEffect(enabled: Bool) {
        isCassetteEffectEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.cassetteEffectKey)
        print("🎵 保存磁带音效设置: \(enabled)")
    }
    
    /// 设置触觉反馈开关
    func setHapticFeedback(enabled: Bool) {
        isHapticFeedbackEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.hapticFeedbackKey)
        print("📳 保存触觉反馈设置: \(enabled)")
    }
    
    /// 设置屏幕常亮开关
    func setScreenAlwaysOn(enabled: Bool) {
        isScreenAlwaysOn = enabled
        UserDefaults.standard.set(enabled, forKey: Self.screenAlwaysOnKey)
        print("📱 保存屏幕常亮设置: \(enabled)")
    }

    private func updateCurrentSongInfo() {
        
        guard let entry = player.queue.currentEntry else {
            DispatchQueue.main.async {
                self.currentTitle = "未播放歌曲"
                self.currentArtist = "点此选择音乐"
                self.currentDuration = 0
                self.totalDuration = 0
                self.isPlaying = false  // 添加播放状态重置
                self.currentTrackID = nil
                self.currentTrackIndex = nil
                self.totalTracksInQueue = 0
                self.queueTotalDuration = 0
                self.queueElapsedDuration = 0
                // 同步播放状态到音频效果管理器
                self.audioEffectsManager.setMusicPlayingState(false)
            }
            return
        }
        
        let duration: TimeInterval
        var trackID: MusicItemID? = nil
        
        // 更精确的类型处理
        switch entry.item {
        case .song(let song):
            duration = song.duration ?? 0
            trackID = song.id
        case .musicVideo(let musicVideo):
            duration = musicVideo.duration ?? 0
            trackID = musicVideo.id
        case .none:
            duration = 0
            trackID = nil
        @unknown default:
            duration = 0
            trackID = nil
        }
        
        let entries = player.queue.entries
        let trackIndex = entries.firstIndex(where: { $0.id == entry.id })
        
        let totalQueueDuration = calculateQueueTotalDuration(entries: entries)
        let elapsedQueueDuration = calculateQueueElapsedDuration(entries: entries, currentEntryIndex: trackIndex)
        
        let playbackStatus = player.state.playbackStatus == .playing
        
        DispatchQueue.main.async {
            self.currentTitle = entry.title
            self.currentArtist = entry.subtitle ?? ""
            self.currentDuration = self.player.playbackTime
            self.totalDuration = duration
            self.isPlaying = playbackStatus  // 同步播放状态
            self.currentTrackID = trackID
            self.currentTrackIndex = trackIndex.map { $0 + 1 } // 转换为1-based索引
            self.totalTracksInQueue = entries.count
            self.queueTotalDuration = totalQueueDuration
            self.queueElapsedDuration = elapsedQueueDuration
            // 同步播放状态到音频效果管理器
            self.audioEffectsManager.setMusicPlayingState(playbackStatus)
        }
    }
    
    private func calculateQueueTotalDuration(entries: ApplicationMusicPlayer.Queue.Entries) -> TimeInterval {
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
        
        print("🎵 队列总时长计算: \(totalDuration)秒, 条目数量: \(entries.count)")
        
        // 如果总时长为0，返回默认值
        return totalDuration > 0 ? totalDuration : 180.0
    }

    private func calculateQueueElapsedDuration(entries: ApplicationMusicPlayer.Queue.Entries, currentEntryIndex: Int?) -> TimeInterval {
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
        elapsedDuration += player.playbackTime
        
        print("🎵 队列累计播放时长: \(elapsedDuration)秒, 当前歌曲索引: \(currentIndex)")
        
        return elapsedDuration
    }

    /// 播放控制
    func play() async throws {
        try await player.play()
        await MainActor.run {
            isPlaying = true
            // 同步播放状态到音频效果管理器
            audioEffectsManager.setMusicPlayingState(true)
        }
    }
    
    func pause() async {
        player.pause()
        await MainActor.run {
            isPlaying = false
            // 同步播放状态到音频效果管理器
            audioEffectsManager.setMusicPlayingState(false)
        }
    }
    
    func skipToNext() async throws {
        try await player.skipToNextEntry()
    }
    
    func skipToPrevious() async throws {
        try await player.skipToPreviousEntry()
    }
    
    func startFastRewind() {
        print("🎵 开始快退")
        stopSeek() // 停止任何现有的快进/快退
        isFastRewinding = true
        
        seekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let newTime = max(0, self.player.playbackTime - 5.0) // 每0.1秒后退5秒
            self.player.playbackTime = newTime
            print("🎵 快退中 - 当前时间: \(newTime)秒")
        }
    }
    
    func startFastForward() {
        print("🎵 开始快进")
        stopSeek() // 停止任何现有的快进/快退
        isFastForwarding = true
        
        seekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let newTime = min(self.totalDuration, self.player.playbackTime + 5.0) // 每0.1秒前进5秒
            self.player.playbackTime = newTime
            print("🎵 快进中 - 当前时间: \(newTime)秒")
        }
    }
    
    func stopSeek() {
        print("🎵 停止快进/快退")
        seekTimer?.invalidate()
        seekTimer = nil
        isFastForwarding = false
        isFastRewinding = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateQueueElapsedDuration()
        }
    }
    
    private func updateQueueElapsedDuration() {
        let entries = player.queue.entries
        let currentEntry = player.queue.currentEntry
        let trackIndex = entries.firstIndex(where: { $0.id == currentEntry?.id })
        let elapsedDuration = calculateQueueElapsedDuration(entries: entries, currentEntryIndex: trackIndex)
        
        // 只有当值发生变化时才更新，避免不必要的更新
        if abs(self.queueElapsedDuration - elapsedDuration) > 0.5 { // 0.5秒的阈值
            self.queueElapsedDuration = elapsedDuration
            print("🎵 延迟更新队列累计时长: \(elapsedDuration)秒")
        }
    }

    /// 获取用户媒体库专辑
    func fetchUserLibraryAlbums() async throws -> MusicItemCollection<Album> {
        print("🔍 开始获取用户媒体库专辑...")
        
        var request = MusicLibraryRequest<Album>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 100 // 设置合理的限制
        
        do {
            let response = try await request.response()
            let albums = response.items
            print("✅ 成功获取到 \(albums.count) 张专辑")
            return albums
        } catch {
            print("❌ 获取专辑失败: \(error)")
            print("❌ 错误详情: \(error.localizedDescription)")
            throw error
        }
    }

    /// 获取用户媒体库播放列表
    func fetchUserLibraryPlaylists() async throws -> MusicItemCollection<Playlist> {
        print("🔍 开始获取用户媒体库播放列表...")
        
        var request = MusicLibraryRequest<Playlist>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 100
        
        do {
            let response = try await request.response()
            let playlists = response.items
            print("✅ 成功获取到 \(playlists.count) 个播放列表")
            return playlists
        } catch {
            print("❌ 获取播放列表失败: \(error)")
            print("❌ 错误详情: \(error.localizedDescription)")
            throw error
        }
    }
    
    // 格式化时间显示
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
