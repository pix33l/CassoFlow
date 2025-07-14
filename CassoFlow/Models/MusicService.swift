import MusicKit
import Combine
import Foundation
import UIKit

/// 音乐服务类
class MusicService: ObservableObject {
    static let shared = MusicService()
    
    private let player = ApplicationMusicPlayer.shared
    private let audioEffectsManager = AudioEffectsManager.shared
    private let storeManager = StoreManager.shared
    
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
    private var updateTimer: Timer?
    
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
    
    // 缓存上一次的关键值，只对不需要频繁更新的属性使用
    private var lastTitle: String = ""
    private var lastArtist: String = ""
    private var lastTrackID: MusicItemID? = nil
    private var lastTrackIndex: Int? = nil
    private var lastTotalTracks: Int = 0
    
    var repeatMode: MusicPlayer.RepeatMode {
        get { player.state.repeatMode ?? .none }
        set { player.state.repeatMode = newValue }
    }
    
    var shuffleMode: MusicPlayer.ShuffleMode {
        get { player.state.shuffleMode ?? .off }
        set { player.state.shuffleMode = newValue }
    }
    
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
    
    // 设置MusicKit
    private func setupMusicKit() async {
        do {
            // 检查订阅状态
            _ = try await MusicSubscription.current
        } catch {
            // 设置失败，静默处理
        }
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
            currentPlayerSkin = skin
        } else {
            let defaultSkin = PlayerSkin.playerSkin(named: "CF-DEMO") ?? PlayerSkin.playerSkins[0]
            currentPlayerSkin = defaultSkin
        }
        
        let savedCassetteSkinName = UserDefaults.standard.string(forKey: Self.cassetteSkinKey)
        if let skinName = savedCassetteSkinName,
           let skin = CassetteSkin.cassetteSkin(named: skinName) {
            currentCassetteSkin = skin
        } else {
            let defaultSkin = CassetteSkin.cassetteSkin(named: "CFT-DEMO") ?? CassetteSkin.cassetteSkins[0]
            currentCassetteSkin = defaultSkin
        }
        
        // 加载磁带音效设置
        isCassetteEffectEnabled = UserDefaults.standard.bool(forKey: Self.cassetteEffectKey)
        
        // 加载触觉反馈设置
        if UserDefaults.standard.object(forKey: Self.hapticFeedbackKey) == nil {
            // 首次启动时设置默认值为false
            isHapticFeedbackEnabled = false
            UserDefaults.standard.set(false, forKey: Self.hapticFeedbackKey)
        } else {
            isHapticFeedbackEnabled = UserDefaults.standard.bool(forKey: Self.hapticFeedbackKey)
        }
        
        // 加载屏幕常亮设置
        isScreenAlwaysOn = UserDefaults.standard.bool(forKey: Self.screenAlwaysOnKey)
        // 应用屏幕常亮设置
        UIApplication.shared.isIdleTimerDisabled = isScreenAlwaysOn
        
        // 启动定时器
        startUpdateTimer()
        
        // 监听会员状态变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMembershipStatusChanged),
            name: NSNotification.Name("MembershipStatusChanged"),
            object: nil
        )
    }
    
    deinit {
        stopUpdateTimer()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 会员状态变化处理
    @objc private func handleMembershipStatusChanged() {
        Task { @MainActor in
            // 检查当前播放器皮肤是否仍然可用
            if !SkinHelper.isPlayerSkinOwned(currentPlayerSkin.name, storeManager: storeManager) {
                // 如果当前皮肤不再可用，恢复到默认皮肤
                if let defaultSkin = PlayerSkin.playerSkin(named: "CF-DEMO") {
                    currentPlayerSkin = defaultSkin
                    UserDefaults.standard.set(defaultSkin.name, forKey: Self.playerSkinKey)
                }
            }
            
            // 检查当前磁带皮肤是否仍然可用
            if !SkinHelper.isCassetteSkinOwned(currentCassetteSkin.name, storeManager: storeManager) {
                // 如果当前皮肤不再可用，恢复到默认皮肤
                if let defaultSkin = CassetteSkin.cassetteSkin(named: "CFT-DEMO") {
                    currentCassetteSkin = defaultSkin
                    UserDefaults.standard.set(defaultSkin.name, forKey: Self.cassetteSkinKey)
                }
            }
        }
    }
    
    // MARK: - 定时器管理
    
    private func startUpdateTimer() {
        stopUpdateTimer() // 确保没有重复的定时器
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCurrentSongInfo()
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - 皮肤持久化方法
    
    /// 设置并保存播放器皮肤
    func setPlayerSkin(_ skin: PlayerSkin) {
        currentPlayerSkin = skin
        UserDefaults.standard.set(skin.name, forKey: Self.playerSkinKey)
    }
    
    /// 设置并保存磁带皮肤
    func setCassetteSkin(_ skin: CassetteSkin) {
        currentCassetteSkin = skin
        UserDefaults.standard.set(skin.name, forKey: Self.cassetteSkinKey)
    }
    
    /// 设置磁带音效开关
    func setCassetteEffect(enabled: Bool) {
        isCassetteEffectEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.cassetteEffectKey)
    }
    
    /// 设置触觉反馈开关
    func setHapticFeedback(enabled: Bool) {
        isHapticFeedbackEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.hapticFeedbackKey)
    }
    
    /// 设置屏幕常亮开关
    func setScreenAlwaysOn(enabled: Bool) {
        isScreenAlwaysOn = enabled
        UserDefaults.standard.set(enabled, forKey: Self.screenAlwaysOnKey)
    }

    private func updateCurrentSongInfo() {
        guard let entry = player.queue.currentEntry else {
            DispatchQueue.main.async {
                self.currentTitle = String(localized: "未播放歌曲")
                self.currentArtist = String(localized: "点此选择音乐")
                self.currentDuration = 0
                self.totalDuration = 0
                self.isPlaying = false
                self.currentTrackID = nil
                self.currentTrackIndex = nil
                self.totalTracksInQueue = 0
                self.queueTotalDuration = 0
                self.queueElapsedDuration = 0
                // 同步播放状态到音频效果管理器
                self.audioEffectsManager.setMusicPlayingState(false)
                
                // 重置缓存值
                self.lastTitle = ""
                self.lastArtist = ""
                self.lastTrackID = nil
                self.lastTrackIndex = nil
                self.lastTotalTracks = 0
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
        let playbackStatus = player.state.playbackStatus == .playing
        
        let newTitle = entry.title
        let newArtist = entry.subtitle ?? ""
        let newTrackIndex = trackIndex.map { $0 + 1 }
        let newTotalTracks = entries.count
        
        // 检查是否需要更新歌曲基本信息（只对不经常变化的信息做缓存检查）
        let songInfoChanged = newTitle != lastTitle ||
                             newArtist != lastArtist ||
                             trackID != lastTrackID ||
                             newTrackIndex != lastTrackIndex ||
                             newTotalTracks != lastTotalTracks
        
        if songInfoChanged {
            let totalQueueDuration = calculateQueueTotalDuration(entries: entries)
            
            // 更新缓存值
            lastTitle = newTitle
            lastArtist = newArtist
            lastTrackID = trackID
            lastTrackIndex = newTrackIndex
            lastTotalTracks = newTotalTracks
            
            DispatchQueue.main.async {
                self.currentTitle = newTitle
                self.currentArtist = newArtist
                self.totalDuration = duration
                self.currentTrackID = trackID
                self.currentTrackIndex = newTrackIndex
                self.totalTracksInQueue = newTotalTracks
                self.queueTotalDuration = totalQueueDuration
            }
        }
        
        // 这些需要持续更新以保证磁带转动和快进/快退功能正常
        DispatchQueue.main.async {
            // 播放状态和时间需要实时更新
            self.isPlaying = playbackStatus
            self.currentDuration = self.player.playbackTime
            
            // 更新队列累计时长
            let elapsedQueueDuration = self.calculateQueueElapsedDuration(entries: entries, currentEntryIndex: trackIndex)
            self.queueElapsedDuration = elapsedQueueDuration
            
            // 同步播放状态到音频效果管理器
            self.audioEffectsManager.setMusicPlayingState(playbackStatus)
        }
    }
/// 计算队列中所有歌曲的总时长
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
        
        // 如果总时长为0，返回默认值
        return totalDuration > 0 ? totalDuration : 180.0
    }
/// 计算队列中已播放的总时长
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
        
        return elapsedDuration
    }

    /// 播放
    func play() async throws {
        try await player.play()
        await MainActor.run {
            isPlaying = true
            // 同步播放状态到音频效果管理器
            audioEffectsManager.setMusicPlayingState(true)
        }
    }

    /// 暂停
    func pause() async {
        player.pause()
        await MainActor.run {
            isPlaying = false
            // 同步播放状态到音频效果管理器
            audioEffectsManager.setMusicPlayingState(false)
        }
    }

    /// 播放下一首
    func skipToNext() async throws {
        try await player.skipToNextEntry()
    }

    /// 播放上一首
    func skipToPrevious() async throws {
        try await player.skipToPreviousEntry()
    }

    /// 开始快退
    func startFastRewind() {
        stopSeek() // 停止任何现有的快进/快退
        isFastRewinding = true
        
        seekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let newTime = max(0, self.player.playbackTime - 5.0) // 每0.1秒后退5秒
            self.player.playbackTime = newTime
        }
    }

    /// 开始快进
    func startFastForward() {
        stopSeek() // 停止任何现有的快进/快退
        isFastForwarding = true
        
        seekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let newTime = min(self.totalDuration, self.player.playbackTime + 5.0) // 每0.1秒前进5秒
            self.player.playbackTime = newTime
        }
    }

    /// 停止快速前进或快退
    func stopSeek() {
        seekTimer?.invalidate()
        seekTimer = nil
        isFastForwarding = false
        isFastRewinding = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateQueueElapsedDuration()
        }
    }

    // MARK: - 队列管理
    private func updateQueueElapsedDuration() {
        let entries = player.queue.entries
        let currentEntry = player.queue.currentEntry
        let trackIndex = entries.firstIndex(where: { $0.id == currentEntry?.id })
        let elapsedDuration = calculateQueueElapsedDuration(entries: entries, currentEntryIndex: trackIndex)
        
        self.queueElapsedDuration = elapsedDuration
    }

    /// 获取用户媒体库专辑
    func fetchUserLibraryAlbums() async throws -> MusicItemCollection<Album> {
        var request = MusicLibraryRequest<Album>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 50 // 设置合理的限制
        
        let response = try await request.response()
        return response.items
    }

    /// 获取用户媒体库播放列表
    func fetchUserLibraryPlaylists() async throws -> MusicItemCollection<Playlist> {
        var request = MusicLibraryRequest<Playlist>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 50
        
        let response = try await request.response()
        return response.items
    }
    
    // 格式化时间显示
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}