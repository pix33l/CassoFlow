import MusicKit
import Combine
import Foundation
import UIKit
import WidgetKit

// MARK: - 磁带封面样式枚举
enum CoverStyle: String, CaseIterable {
    case square = "square"
    case rectangle = "rectangle"
    
    var displayName: String {
        switch self {
        case .square:
            return String(localized: "方形比例")
        case .rectangle:
            return String(localized: "矩形比例")
        }
    }
    
    var description: String {
        switch self {
        case .square:
            return String(localized: "更紧凑的方形比例，封面显示更完整")
        case .rectangle:
            return String(localized: "经典的磁带盒比例，封面更具真实感")
        }
    }
    
    var iconName: String {
        switch self {
        case .square:
            return "square"
        case .rectangle:
            return "rectangle.portrait"
        }
    }
}

/// 音乐服务类
class MusicService: ObservableObject {
    static let shared = MusicService()
    
    private let player = ApplicationMusicPlayer.shared
    private let audioEffectsManager = AudioEffectsManager.shared
    private let storeManager = StoreManager.shared
    
    // Widget更新管理器
    private let widgetUpdateManager = WidgetUpdateManager.shared
    
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
    
    // 新增：后台状态监听Timer
    private var backgroundStatusTimer: Timer?
    
    // 应用状态管理
    private var isAppInBackground = false
    
    // 缓存上次的播放状态，用于后台状态检测
    private var lastPlayingState: Bool = false

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
    
    // MARK: - 磁带封面样式属性
    @Published var currentCoverStyle: CoverStyle = .rectangle
    
    // MARK: - 库视图控制
    @Published var shouldCloseLibrary: Bool = false
    
    // MARK: - 皮肤存储键值
    private static let playerSkinKey = "SelectedPlayerSkin"
    private static let cassetteSkinKey = "SelectedCassetteSkin"
    private static let cassetteEffectKey = "CassetteEffectEnabled"
    private static let hapticFeedbackKey = "HapticFeedbackEnabled"
    private static let screenAlwaysOnKey = "ScreenAlwaysOnEnabled"
    private static let coverStyleKey = "SelectedCoverStyle"
    
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
        
        // 播放成功后触发关闭库视图
        await MainActor.run {
            shouldCloseLibrary = true
        }
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.3秒
        await forceSyncPlaybackStatus()
    }
    
    /// 播放播放列表中的特定歌曲
    func playTrack(_ track: Track, in playlist: Playlist) async throws {
        let songs = try await playlist.with([.tracks]).tracks ?? []
        guard let index = songs.firstIndex(where: { $0.id == track.id }) else { return }
        
        player.queue = .init(for: songs, startingAt: songs[index])
        try await player.play()
        
        // 播放成功后触发关闭库视图
        await MainActor.run {
            shouldCloseLibrary = true
        }
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.3秒
        await forceSyncPlaybackStatus()
    }
    
    /// 播放专辑（可选择随机播放）
    func playAlbum(_ album: Album, shuffled: Bool = false) async throws {
        let songs = try await album.with([.tracks]).tracks ?? []
        if shuffled {
            player.state.shuffleMode = .songs
        }
        player.queue = .init(for: songs, startingAt: nil)
        try await player.play()
        
        // 播放成功后触发关闭库视图
        await MainActor.run {
            shouldCloseLibrary = true
        }
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.3秒
        await forceSyncPlaybackStatus()
    }
    
    /// 播放播放列表（可选择随机播放）
    func playPlaylist(_ playlist: Playlist, shuffled: Bool = false) async throws {
        let songs = try await playlist.with([.tracks]).tracks ?? []
        if shuffled {
            player.state.shuffleMode = .songs
        }
        player.queue = .init(for: songs, startingAt: nil)
        try await player.play()
        
        // 播放成功后触发关闭库视图
        await MainActor.run {
            shouldCloseLibrary = true
        }
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.3秒
        await forceSyncPlaybackStatus()
    }
    
    /// 重置库视图关闭状态
    func resetLibraryCloseState() {
        shouldCloseLibrary = false
    }
    
    init() {
        // 设置默认的显示状态
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
        
        // 加载磁带封面样式设置
        let savedCoverStyle = UserDefaults.standard.string(forKey: Self.coverStyleKey)
        if let styleString = savedCoverStyle,
           let style = CoverStyle(rawValue: styleString) {
            currentCoverStyle = style
        } else {
            currentCoverStyle = .rectangle // 默认矩形样式
        }
        
        // 🔑 智能启动Timer - 只在需要时启动
        startUpdateTimer()
        
        // 监听会员状态变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMembershipStatusChanged),
            name: NSNotification.Name("MembershipStatusChanged"),
            object: nil
        )
        
        // 监听应用状态变化
        setupAppStateNotifications()
        
        // 监听widget控制操作
        setupWidgetControlNotifications()
    }
    
    deinit {
        stopAllTimers()
        NotificationCenter.default.removeObserver(self)
    }
    
    // 设置应用状态通知监听
    private func setupAppStateNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppEnterBackground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppEnterForeground()
        }
    }
    
    // 处理应用进入后台
    private func handleAppEnterBackground() {
        isAppInBackground = true
        lastPlayingState = isPlaying
        
        // 临时关闭屏幕常亮以节省电量
        if isScreenAlwaysOn {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        
        // 智能管理后台Timer：只在播放音乐时启动
        if isPlaying {
            startBackgroundStatusTimer()
        } else {
            stopBackgroundStatusTimer()
        }
    }
    
    // 处理应用回到前台
    private func handleAppEnterForeground() {
        isAppInBackground = false
        
        // 恢复屏幕常亮设置
        UIApplication.shared.isIdleTimerDisabled = isScreenAlwaysOn

        // 停止后台状态监听Timer，恢复前台更新Timer
        stopBackgroundStatusTimer()
        startUpdateTimer()
        
        // 回到前台时立即同步一次播放进度
        syncPlaybackProgress()
        
        // 检查是否有来自widget的控制操作
        checkWidgetControlActions()
    }
    
    // 设置widget控制通知监听
    private func setupWidgetControlNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WidgetMusicControl"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkWidgetControlActions()
        }
    }
    
    // 检查并处理widget控制操作
    private func checkWidgetControlActions() {
        if let action = UserDefaults.getAndClearMusicControlAction() {
            handleWidgetControlAction(action)
        }
    }
    
    // 处理widget控制操作
    private func handleWidgetControlAction(_ action: MusicControlAction) {
        Task {
            switch action {
            case .playPause:
                if isPlaying {
                    await pause()
                } else {
                    try? await play()
                }
            case .nextTrack:
                try? await skipToNext()
            case .previousTrack:
                try? await skipToPrevious()
            }
        }
    }
    
    // 新增：启动后台状态监听Timer
    private func startBackgroundStatusTimer() {
        
        // 只有在后台且音乐播放时才启动
        guard isAppInBackground && isPlaying else {
            return
        }
        
        stopBackgroundStatusTimer() // 确保没有重复的定时器
        
        backgroundStatusTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateBackgroundMusicStatus()
        }
    }
    
    // 新增：停止后台状态监听Timer
    private func stopBackgroundStatusTimer() {
        backgroundStatusTimer?.invalidate()
        backgroundStatusTimer = nil
    }
    
    // 新增：后台状态更新 - 仅检查关键状态变化
    private func updateBackgroundMusicStatus() {
        let currentPlayingState = player.state.playbackStatus == .playing
        
        // 只在播放状态发生变化时才更新和通知
        if currentPlayingState != lastPlayingState {
            DispatchQueue.main.async {
                self.isPlaying = currentPlayingState
                // 立即通知AudioEffectsManager状态变化
                self.audioEffectsManager.setMusicPlayingState(currentPlayingState)
            }
            
            lastPlayingState = currentPlayingState
        }
    }
    
    // 新增：停止所有Timer
    private func stopAllTimers() {
        stopUpdateTimer()
        stopBackgroundStatusTimer()
    }
    
    // 同步播放进度（解决后台播放进度不同步问题）
    private func syncPlaybackProgress() {
        // 强制立即更新一次播放信息，确保磁带进度正确
        updateCurrentSongInfo()
    }
    
    // 🔑 新增：强制同步播放状态（解决首次播放显示问题）
    private func forceSyncPlaybackStatus() async {
        await MainActor.run {
            updateCurrentSongInfo()
            
            // 如果状态同步成功且正在播放，确保Timer运行
            if isPlaying {
                startUpdateTimer()
            }
        }
    }
    
    // 新增：公共方法用于外部强制更新widget数据
    func updateWidgetData() {
        updateCurrentSongInfo()
        // 主动刷新Widget
        widgetUpdateManager.reloadAllWidgets()
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
    
    // MARK: - 定时器管理（优化后台耗电）
    
    private func startUpdateTimer() {
        // 🔑 总是先执行一次更新，确保歌曲信息和磁带显示正确
        updateCurrentSongInfo()
        
        // 只有在需要动态更新时才启动Timer
        guard shouldRunDynamicUpdates() else {
            stopUpdateTimer()
            return
        }
        
        stopUpdateTimer() // 确保没有重复的定时器
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCurrentSongInfo()
            
            // 动态检查是否还需要继续运行Timer
            if !(self?.shouldRunDynamicUpdates() ?? false) {
                self?.stopUpdateTimer()
            }
        }
    }
    
    /// 判断是否需要运行动态更新Timer
    private func shouldRunDynamicUpdates() -> Bool {
        // 快进/快退时必须运行Timer
        if isFastForwarding || isFastRewinding {
            return true
        }
        
        // 正在播放时需要更新进度
        if isPlaying {
            return true
        }
        
        // 其他情况（暂停、停止、无播放队列）不需要Timer
        return false
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
    
    /// 设置磁带封面样式
    func setCoverStyle(_ style: CoverStyle) {
        currentCoverStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: Self.coverStyleKey)
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
                
                // 保存到共享存储供widget使用
                let musicData = SharedMusicData(
                    title: self.currentTitle,
                    artist: self.currentArtist,
                    isPlaying: self.isPlaying,
                    currentDuration: self.currentDuration,
                    totalDuration: self.totalDuration,
                    artworkURL: nil
                )
                UserDefaults.saveMusicData(musicData)
            }
            return
        }
        
        let duration: TimeInterval
        var trackID: MusicItemID? = nil
        
        // 更精确的类型处理
        var artwork: Artwork? = nil
        switch entry.item {
        case .song(let song):
            duration = song.duration ?? 0
            trackID = song.id
            artwork = song.artwork
        case .musicVideo(let musicVideo):
            duration = musicVideo.duration ?? 0
            trackID = musicVideo.id
            artwork = musicVideo.artwork
        case .none:
            duration = 0
            trackID = nil
        @unknown default:
            duration = 0
            trackID = nil
        }
        
        // 获取专辑封面URL
        var artworkURL: String? = nil
        if let artwork = artwork {
            artworkURL = artwork.url(width: 200, height: 200)?.absoluteString
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
                             
        // 检查播放状态是否变化
        let playbackStateChanged = playbackStatus != isPlaying
        
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
                
                // 保存到共享存储供widget使用
                let musicData = SharedMusicData(
                    title: self.currentTitle,
                    artist: self.currentArtist,
                    isPlaying: self.isPlaying,
                    currentDuration: self.currentDuration,
                    totalDuration: self.totalDuration,
                    artworkURL: artwork?.url(width: 200, height: 200)?.absoluteString
                )
                UserDefaults.saveMusicData(musicData)
                
                // 通知Widget更新（歌曲信息变化）
                self.widgetUpdateManager.musicInfoChanged()
            }
        }
        
        // 这些需要持续更新以保证磁带转动和快进/快退功能正常
        DispatchQueue.main.async {
            // 播放状态和时间需要实时更新
            let previousPlayingState = self.isPlaying
            self.isPlaying = playbackStatus
            self.currentDuration = self.player.playbackTime
            
            // 重要：即使在后台也要更新队列累计时长，确保磁带进度正确
            let elapsedQueueDuration = self.calculateQueueElapsedDuration(entries: entries, currentEntryIndex: trackIndex)
            self.queueElapsedDuration = elapsedQueueDuration
            
            // 同步播放状态到音频效果管理器
            self.audioEffectsManager.setMusicPlayingState(playbackStatus)
            
            // 保存到共享存储供widget使用
            let musicData = SharedMusicData(
                title: self.currentTitle,
                artist: self.currentArtist,
                isPlaying: self.isPlaying,
                currentDuration: self.currentDuration,
                totalDuration: self.totalDuration,
                artworkURL: artworkURL
            )
            UserDefaults.saveMusicData(musicData)
            
            // 通知Widget更新
            if playbackStateChanged {
                // 播放状态变化
                self.widgetUpdateManager.musicPlaybackStateChanged(isPlaying: playbackStatus)
            } else if previousPlayingState && playbackStatus {
                // 播放进度变化（仅在播放状态下）
                self.widgetUpdateManager.playbackProgressChanged()
            }
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
            // 🔑 开始播放时启动Timer
            startUpdateTimer()
            
            // 通知Widget更新（播放状态变化）
            self.widgetUpdateManager.musicPlaybackStateChanged(isPlaying: true)
        }
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.3秒
        await forceSyncPlaybackStatus()
    }

    /// 暂停
    func pause() async {
        player.pause()
        await MainActor.run {
            isPlaying = false
            // 同步播放状态到音频效果管理器
            audioEffectsManager.setMusicPlayingState(false)
            // 🔑 暂停时直接停止Timer，不重新启动
            stopUpdateTimer()
            
            // 通知Widget更新（播放状态变化）
            self.widgetUpdateManager.musicPlaybackStateChanged(isPlaying: false)
        }
    }

    /// 播放下一首
    func skipToNext() async throws {
        try await player.skipToNextEntry()
        // 🔑 切歌后立即同步状态，确保UI更新（特别是暂停状态下）
        Task {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒延迟
            await MainActor.run {
                self.updateCurrentSongInfo()
                // 通知Widget更新（歌曲信息变化）
                self.widgetUpdateManager.musicInfoChanged()
            }
        }
    }

    /// 播放上一首
    func skipToPrevious() async throws {
        try await player.skipToPreviousEntry()
        // 🔑 切歌后立即同步状态，确保UI更新（特别是暂停状态下）
        Task {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒延迟
            await MainActor.run {
                self.updateCurrentSongInfo()
                // 通知Widget更新（歌曲信息变化）
                self.widgetUpdateManager.musicInfoChanged()
            }
        }
    }

    /// 开始快退
    func startFastRewind() {
        stopSeek() // 停止任何现有的快进/快退
        isFastRewinding = true
        
        // 🔑 快进/快退时确保Timer运行
        startUpdateTimer()
        
        seekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let newTime = max(0, self.player.playbackTime - 6.0) // 每0.1秒后退6秒
            self.player.playbackTime = newTime
        }
    }

    /// 开始快进
    func startFastForward() {
        stopSeek() // 停止任何现有的快进/快退
        isFastForwarding = true
        
        // 🔑 快进/快退时确保Timer运行
        startUpdateTimer()
        
        seekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let newTime = min(self.totalDuration, self.player.playbackTime + 6.0) // 每0.1秒前进6秒
            self.player.playbackTime = newTime
        }
    }

    /// 停止快速前进或快退
    func stopSeek() {
        seekTimer?.invalidate()
        seekTimer = nil
        isFastRewinding = false
        isFastForwarding = false
        
        // 🔑 停止快进/快退后重新评估Timer需求
        startUpdateTimer()
        
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
