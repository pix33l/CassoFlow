import MusicKit
import Combine
import Foundation
import UIKit
import MediaPlayer

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

/// 音乐服务类 - 通用音乐服务协调器
class MusicService: ObservableObject {
    static let shared = MusicService()
    
    // MARK: - 核心组件
    private let musicKitService = MusicKitService.shared
    private let subsonicService = SubsonicMusicService.shared
    private let audioStationService = AudioStationMusicService.shared
    private let localService = LocalMusicService.shared
    private let coordinator = MusicServiceCoordinator()
    private let audioEffectsManager = AudioEffectsManager.shared
    private let storeManager = StoreManager.shared
    
    // MARK: - 播放状态
    @Published var currentTitle: String = ""
    @Published var currentArtist: String = ""
    @Published var currentDuration: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var isPlaying: Bool = false
    @Published var currentTrackID: MusicItemID?
    @Published var currentTrackIndex: Int? = nil
    @Published var totalTracksInQueue: Int = 0
    
    @Published var queueTotalDuration: TimeInterval = 0
    @Published var queueElapsedDuration: TimeInterval = 0
    
    @Published var isFastForwarding: Bool = false
    @Published var isFastRewinding: Bool = false
    private var seekTimer: Timer?
    private var updateTimer: Timer?
    
    // MARK: - 皮肤和设置
    @Published var currentPlayerSkin: PlayerSkin
    @Published var currentCassetteSkin: CassetteSkin
    @Published var currentCoverStyle: CoverStyle = .rectangle

    // MARK: - 磁带音效属性
    @Published var isCassetteEffectEnabled: Bool = false {
        didSet {
            audioEffectsManager.setCassetteEffect(enabled: isCassetteEffectEnabled)
        }
    }
    
    // MARK: - 触觉反馈属性
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
    
    // MARK: - 库视图控制
    @Published var shouldCloseLibrary: Bool = false
    
    // MARK: - 数据源管理
    
    @Published var currentDataSource: MusicDataSourceType = .musicKit {
        didSet {
            UserDefaults.standard.set(currentDataSource.rawValue, forKey: "SelectedDataSource")
            coordinator.currentDataSource = currentDataSource
            
            // 🔑 切换数据源时重置播放状态
            Task { @MainActor in
                await resetPlaybackStateForDataSourceChange()
            }
        }
    }
    
    // MARK: - 存储键值
    private static let playerSkinKey = "SelectedPlayerSkin"
    private static let cassetteSkinKey = "SelectedCassetteSkin"
    private static let cassetteEffectKey = "CassetteEffectEnabled"
    private static let hapticFeedbackKey = "HapticFeedbackEnabled"
    private static let screenAlwaysOnKey = "ScreenAlwaysOnEnabled"
    private static let coverStyleKey = "SelectedCoverStyle"
    
    // 后台状态监听Timer
    private var backgroundStatusTimer: Timer?
    
    // 应用状态管理
    private var isAppInBackground = false
    
    // 缓存上次的播放状态，用于后台状态检测
    private var lastPlayingState: Bool = false
    
    // 缓存上一次的关键值，只对不需要频繁更新的属性使用
    private var lastTitle: String = ""
    private var lastArtist: String = ""
    private var lastTrackID: MusicItemID? = nil
    private var lastTrackIndex: Int? = nil
    private var lastTotalTracks: Int = 0
    
    // 循环播放
//    var repeatMode: MusicKit.MusicPlayer.RepeatMode {
//        get { 
//            switch currentDataSource {
//            case .musicKit:
//                return musicKitService.repeatMode
//            default:
//                return .none
//            }
//        }
//        set { 
//            switch currentDataSource {
//            case .musicKit:
//                musicKitService.repeatMode = newValue
//            default:
//                break
//            }
//        }
//    }
    
    // 随机播放
//    var shuffleMode: MusicKit.MusicPlayer.ShuffleMode {
//        get { 
//            switch currentDataSource {
//            case .musicKit:
//                return musicKitService.shuffleMode
//            default:
//                return .off
//            }
//        }
//        set { 
//            switch currentDataSource {
//            case .musicKit:
//                musicKitService.shuffleMode = newValue
//            default:
//                break
//            }
//        }
//    }
    
    /// 请求音乐授权
//    func requestMusicAuthorization() async {
//        await musicKitService.requestMusicAuthorization()
//    }
    
    /// 重置库视图关闭状态
    func resetLibraryCloseState() {
        shouldCloseLibrary = false
    }
    
    // MARK: - 初始化
    
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
        
        // 🔑 从 UserDefaults 加载保存的数据源设置
        let savedDataSource = UserDefaults.standard.string(forKey: "SelectedDataSource")
        if let sourceString = savedDataSource,
           let source = MusicDataSourceType(rawValue: sourceString) {
            _currentDataSource = Published(initialValue: source)
        }
        
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
        
        // 加载其他设置
        loadSettings()
        
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
    }
    
    deinit {
        stopAllTimers()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 设置加载
    private func loadSettings() {
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
        
        // 🔑 修复：确保锁屏播放信息在后台保持
        if isPlaying && currentTrackID != nil {
            // 强制保持锁屏播放信息
            forceUpdateNowPlayingInfo()
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
        
        // 🔑 修复：回到前台时立即同步并强制更新锁屏信息
        updateCurrentSongInfo()
        
        // 延迟再次确保锁屏信息正确
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isPlaying && self.currentTrackID != nil {
                self.forceUpdateNowPlayingInfo()
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
        let currentPlayingState: Bool
        switch currentDataSource {
        case .musicKit:
            currentPlayingState = musicKitService.isPlaying
        case .subsonic:
            currentPlayingState = subsonicService.getPlaybackInfo().isPlaying
        case .audioStation:
            currentPlayingState = audioStationService.getPlaybackInfo().isPlaying
        case .local:
            currentPlayingState = localService.getPlaybackInfo().isPlaying
        }
        
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
    
    // MARK: - 数据获取方法（委托给协调器）
    
    /// 获取Subsonic服务（用于配置）
    func getSubsonicService() -> SubsonicMusicService {
        return subsonicService
    }
    
    /// 获取Audio Station服务（用于配置）
    func getAudioStationService() -> AudioStationMusicService {
        return audioStationService
    }
    
    /// 获取本地音乐服务（用于配置）
    func getLocalService() -> LocalMusicService {
        return localService
    }
    
    /// 获取音乐服务协调器
    func getCoordinator() -> MusicServiceCoordinator {
        return coordinator
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
        // 🔑 优化Timer启动逻辑，确保在播放状态下才启动
        guard shouldRunDynamicUpdates() else {
            stopUpdateTimer()
            return
        }
        
        stopUpdateTimer() // 确保没有重复的定时器
        
        // 🔑 立即执行一次更新，但不依赖这次更新来判断是否继续
        updateCurrentSongInfo()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.updateCurrentSongInfo()
            
            // 动态检查是否还需要继续运行Timer
            if !self.shouldRunDynamicUpdates() {
                self.stopUpdateTimer()
            }
        }
    }
    
    /// 判断是否需要运行动态更新Timer - 添加更严格的条件检查
    private func shouldRunDynamicUpdates() -> Bool {
        // 快进/快退时必须运行Timer
        if isFastForwarding || isFastRewinding {
            return true
        }
        
        // 正在播放且有有效的歌曲时需要更新进度
        if isPlaying && currentTrackID != nil {
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
        switch currentDataSource {
        case .musicKit:
            updateMusicKitInfo()
        case .subsonic:
            updateSubsonicInfo()
        case .audioStation:
            updateAudioStationInfo()
        case .local:
            updateLocalInfo()
        }
    }
    
    private func updateMusicKitInfo() {
        guard let entry = musicKitService.currentEntry else {
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
        
        let entries = musicKitService.queueEntries
        let trackIndex = entries.firstIndex(where: { $0.id == entry.id })
        let playbackStatus = musicKitService.isPlaying
        
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
            let totalQueueDuration = musicKitService.calculateQueueTotalDuration(entries: entries)
            
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
            self.currentDuration = self.musicKitService.playbackTime
            
            // 重要：即使在后台也要更新队列累计时长，确保磁带进度正确
            let elapsedQueueDuration = self.musicKitService.calculateQueueElapsedDuration(entries: entries, currentEntryIndex: trackIndex)
            self.queueElapsedDuration = elapsedQueueDuration
            
            // 同步播放状态到音频效果管理器
            self.audioEffectsManager.setMusicPlayingState(playbackStatus)
        }
    }
    
    private func updateSubsonicInfo() {
        let queueInfo = subsonicService.getQueueInfo()
        let playbackInfo = subsonicService.getPlaybackInfo()
        
        guard let currentSong = subsonicService.getCurrentSong() else {
            resetPlaybackInfo()
            return
        }
        
        // 计算 Subsonic 队列的总时长和已播放时长
        let queueTotalDuration = subsonicService
            .calculateSubsonicQueueTotalDuration(queue: queueInfo.queue)
        let queueElapsedDuration = subsonicService
            .calculateSubsonicQueueElapsedDuration(
            queue: queueInfo.queue,
            currentIndex: queueInfo.currentIndex,
            currentTime: playbackInfo.current
        )
        
        updatePlaybackInfo(
            title: currentSong.title,
            artist: currentSong.artistName,
            duration: playbackInfo.total,
            currentTime: playbackInfo.current,
            trackID: MusicItemID(rawValue: currentSong.id),
            trackIndex: queueInfo.currentIndex + 1,
            totalTracks: queueInfo.queue.count,
            queueTotalDuration: queueTotalDuration,
            queueElapsedDuration: queueElapsedDuration,
            isPlaying: playbackInfo.isPlaying
        )
    }
    
    private func updateAudioStationInfo() {
        let queueInfo = audioStationService.getQueueInfo()
        let playbackInfo = audioStationService.getPlaybackInfo()
        
        guard let currentSong = audioStationService.getCurrentSong() else {
            resetPlaybackInfo()
            return
        }
        
        // 计算 Audio Station 队列的总时长和已播放时长
        let queueTotalDuration = audioStationService.calculateAudioStationQueueTotalDuration(queue: queueInfo.queue)
        let queueElapsedDuration = audioStationService.calculateAudioStationQueueElapsedDuration(
            queue: queueInfo.queue,
            currentIndex: queueInfo.currentIndex,
            currentTime: playbackInfo.current
        )
        
        updatePlaybackInfo(
            title: currentSong.title,
            artist: currentSong.artistName,
            duration: playbackInfo.total,
            currentTime: playbackInfo.current,
            trackID: MusicItemID(rawValue: currentSong.id),
            trackIndex: queueInfo.currentIndex + 1,
            totalTracks: queueInfo.queue.count,
            queueTotalDuration: queueTotalDuration,
            queueElapsedDuration: queueElapsedDuration,
            isPlaying: playbackInfo.isPlaying
        )
    }
    
    private func updateLocalInfo() {
        let queueInfo = localService.getQueueInfo()
        let playbackInfo = localService.getPlaybackInfo()
        
        guard let currentSong = localService.getCurrentSong() else {
            resetPlaybackInfo()
            return
        }
        
        // 计算 Local 队列的总时长和已播放时长
        let queueTotalDuration = localService.calculateLocalQueueTotalDuration(queue: queueInfo.queue)
        let queueElapsedDuration = localService.calculateLocalQueueElapsedDuration(
            queue: queueInfo.queue,
            currentIndex: queueInfo.currentIndex,
            currentTime: playbackInfo.current
        )
        
        updatePlaybackInfo(
            title: currentSong.title,
            artist: currentSong.artistName,
            duration: playbackInfo.total,
            currentTime: playbackInfo.current,
            trackID: MusicItemID(rawValue: currentSong.id),
            trackIndex: queueInfo.currentIndex + 1,
            totalTracks: queueInfo.queue.count,
            queueTotalDuration: queueTotalDuration,
            queueElapsedDuration: queueElapsedDuration,
            isPlaying: playbackInfo.isPlaying
        )
    }
    
    private func updatePlaybackInfo(
        title: String,
        artist: String,
        duration: TimeInterval,
        currentTime: TimeInterval,
        trackID: MusicItemID?,
        trackIndex: Int?,
        totalTracks: Int,
        queueTotalDuration: TimeInterval = 0, // 新增参数
        queueElapsedDuration: TimeInterval = 0, // 新增参数
        isPlaying: Bool
    ) {
        let songInfoChanged = title != lastTitle ||
                             artist != lastArtist ||
                             trackID?.rawValue != lastTrackID?.rawValue ||
                             trackIndex != lastTrackIndex ||
                             totalTracks != lastTotalTracks
        
        if songInfoChanged {
            lastTitle = title
            lastArtist = artist
            lastTrackID = trackID
            lastTrackIndex = trackIndex
            lastTotalTracks = totalTracks
            
            DispatchQueue.main.async {
                self.currentTitle = title
                self.currentArtist = artist
                self.totalDuration = duration
                self.currentTrackID = trackID
                self.currentTrackIndex = trackIndex
                self.totalTracksInQueue = totalTracks
                self.queueTotalDuration = queueTotalDuration // 更新队列总时长
            }
        }
        
        DispatchQueue.main.async {
            self.isPlaying = isPlaying
            self.currentDuration = currentTime
            self.queueElapsedDuration = queueElapsedDuration // 更新队列已播放时长
            self.audioEffectsManager.setMusicPlayingState(isPlaying)
        }
    }
    
    private func resetPlaybackInfo() {
        DispatchQueue.main.async {
            self.currentTitle = String(localized: "未播放歌曲")
            self.currentArtist = String(localized: "点此选择音乐")
            self.currentDuration = 0
            self.totalDuration = 0
            self.isPlaying = false
            self.currentTrackID = nil
            self.currentTrackIndex = nil
            self.totalTracksInQueue = 0
            self.audioEffectsManager.setMusicPlayingState(false)
            
            self.lastTitle = ""
            self.lastArtist = ""
            self.lastTrackID = nil
            self.lastTrackIndex = nil
            self.lastTotalTracks = 0
        }
    }
    
    // MARK: - 播放控制方法
    
    /// 播放通用歌曲队列
    func playUniversalSongs(_ songs: [UniversalSong], startingAt index: Int = 0) async throws {
        switch currentDataSource {
        case .musicKit:
            fallthrough
        case .subsonic:
            try await subsonicService.playQueue(songs, startingAt: index)
        case .audioStation:
            try await audioStationService.playQueue(songs, startingAt: index)
        case .local:
            try await localService.playQueue(songs, startingAt: index)
        }
        
        await MainActor.run {
            shouldCloseLibrary = true
        }
        
        // 🔑 增加延迟时间，确保播放器完全初始化
        try await Task.sleep(nanoseconds: 500_000_000) // 延迟0.5秒
        await forceSyncPlaybackStatus()
    }
    
    /// 播放通用专辑
    func playUniversalAlbum(_ album: UniversalAlbum, shuffled: Bool = false) async throws {
        let detailedAlbum = try await coordinator.getAlbum(id: album.id)
        let finalSongs = shuffled ? detailedAlbum.songs.shuffled() : detailedAlbum.songs
        try await playUniversalSongs(finalSongs)
        
        // 🔑 增加延迟时间，确保播放器完全初始化
        try await Task.sleep(nanoseconds: 500_000_000) // 延迟0.5秒
        await forceSyncPlaybackStatus()
    }
    
    /// 播放通用播放列表
    func playUniversalPlaylist(_ playlist: UniversalPlaylist, shuffled: Bool = false) async throws {
        let detailedPlaylist = try await coordinator.getPlaylist(id: playlist.id)
        let finalSongs = shuffled ? detailedPlaylist.songs.shuffled() : detailedPlaylist.songs
        try await playUniversalSongs(finalSongs)
        
        // 🔑 增加延迟时间，确保播放器完全初始化
        try await Task.sleep(nanoseconds: 500_000_000) // 延迟0.5秒
        await forceSyncPlaybackStatus()
    }

    /// 播放
    func play() async throws {
        switch currentDataSource {
            case .musicKit:
                try await musicKitService.play()
            case .subsonic:
                await subsonicService.play()
            case .audioStation:
                await audioStationService.play()
            case .local:
                await localService.play()
        }
        await MainActor.run {
            isPlaying = true
            // 同步播放状态到音频效果管理器
            audioEffectsManager.setMusicPlayingState(true)
            // 🔑 暂时不启动Timer，让播放器有时间初始化
        }
        
        // 🔑 增加延迟时间并在延迟后启动Timer
        try await Task.sleep(nanoseconds: 500_000_000) // 延迟0.5秒，给播放器更多初始化时间
        await forceSyncPlaybackStatus()
    }

    /// 暂停
    func pause() async {
        switch currentDataSource {
            case .musicKit:
                musicKitService.pause()
            case .subsonic:
                await subsonicService.pause()
            case .audioStation:
                await audioStationService.pause()
            case .local:
                await localService.pause()
        }
        await MainActor.run {
            isPlaying = false
            // 同步播放状态到音频效果管理器
            audioEffectsManager.setMusicPlayingState(false)
            // 🔑 暂停时直接停止Timer，不重新启动
            stopUpdateTimer()
        }
    }

    /// 播放下一首
    func skipToNext() async throws {
        switch currentDataSource {
            case .musicKit:
                try await musicKitService.skipToNext()
            case .subsonic:
                try await subsonicService.skipToNext()
            case .audioStation:
                try await audioStationService.skipToNext()
            case .local:
                try await localService.skipToNext()
        }
        // 🔑 切歌后立即同步状态，确保UI更新（特别是暂停状态下）
        Task {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒延迟
            await MainActor.run {
                self.updateCurrentSongInfo()
            }
        }
    }

    /// 播放上一首
    func skipToPrevious() async throws {
        switch currentDataSource {
            case .musicKit:
                try await musicKitService.skipToPrevious()
            case .subsonic:
                try await subsonicService.skipToPrevious()
            case .audioStation:
                try await audioStationService.skipToPrevious()
            case .local:
                try await localService.skipToPrevious()
        }
        // 🔑 切歌后立即同步状态，确保UI更新（特别是暂停状态下）
        Task {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒延迟
            await MainActor.run {
                self.updateCurrentSongInfo()
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
            
            switch self.currentDataSource {
            case .musicKit:
                let newTime = max(0, self.musicKitService.playbackTime - 6.0) // 每0.1秒后退6秒
                self.musicKitService.setPlaybackTime(newTime)
            case .subsonic:
                self.subsonicService.seekBackward(6.0)
            case .audioStation:
                self.audioStationService.seekBackward(6.0)
            case .local:
                self.localService.seekBackward(6.0)
            }
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
            
            switch self.currentDataSource {
            case .musicKit:
                let newTime = min(self.totalDuration, self.musicKitService.playbackTime + 6.0) // 每0.1秒前进6秒
                self.musicKitService.setPlaybackTime(newTime)
            case .subsonic:
                self.subsonicService.seekForward(6.0)
            case .audioStation:
                self.audioStationService.seekForward(6.0)
            case .local:
                self.localService.seekForward(6.0)
            }
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
        switch currentDataSource {
        case .musicKit:
            let elapsedDuration = musicKitService.updateQueueElapsedDuration()
            self.queueElapsedDuration = elapsedDuration
        case .subsonic:
            let queueInfo = subsonicService.getQueueInfo()
            let playbackInfo = subsonicService.getPlaybackInfo()
            let elapsedDuration = subsonicService.calculateSubsonicQueueElapsedDuration(
                queue: queueInfo.queue,
                currentIndex: queueInfo.currentIndex,
                currentTime: playbackInfo.current
            )
            self.queueElapsedDuration = elapsedDuration
        case .audioStation:
            let queueInfo = audioStationService.getQueueInfo()
            let playbackInfo = audioStationService.getPlaybackInfo()
            let elapsedDuration = audioStationService.calculateAudioStationQueueElapsedDuration(
                queue: queueInfo.queue,
                currentIndex: queueInfo.currentIndex,
                currentTime: playbackInfo.current
            )
            self.queueElapsedDuration = elapsedDuration
        case .local:
            let queueInfo = localService.getQueueInfo()
            let playbackInfo = localService.getPlaybackInfo()
            let elapsedDuration = localService.calculateLocalQueueElapsedDuration(
                queue: queueInfo.queue,
                currentIndex: queueInfo.currentIndex,
                currentTime: playbackInfo.current
            )
            self.queueElapsedDuration = elapsedDuration
        }
    }
    
    // 格式化时间显示
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // 🔑 修改：切换数据源时重置播放状态（异步版本）
    private func resetPlaybackStateForDataSourceChange() async {
        // 🔑 首先停止所有数据源的音乐播放
        await stopAllDataSourcesPlayback()
        
        // 🔑 确保在主线程上更新 @Published 属性
        await MainActor.run {
            // 重置播放信息显示
            currentTitle = String(localized: "未播放歌曲")
            currentArtist = String(localized: "点此选择音乐")
            currentDuration = 0
            totalDuration = 0
            isPlaying = false
            currentTrackID = nil
            currentTrackIndex = nil
            totalTracksInQueue = 0
            queueTotalDuration = 0
            queueElapsedDuration = 0
            
            // 重置缓存值
            lastTitle = ""
            lastArtist = ""
            lastTrackID = nil
            lastTrackIndex = nil
            lastTotalTracks = 0
            
            // 停止相关Timer
            stopUpdateTimer()
            
            // 通知音频效果管理器停止播放
            audioEffectsManager.setMusicPlayingState(false)
        }
    }
    
    // 🔑 修改：停止所有数据源的音乐播放（异步版本）
    private func stopAllDataSourcesPlayback() async {
        print("🛑 停止所有数据源的播放")
        
        // 停止MusicKit播放
        await MainActor.run {
            musicKitService.stop()
            print("🛑 已停止 MusicKit 播放")
        }
        
        // 并行停止其他服务的播放
        async let subsonicStop: Void = {
            await subsonicService.pause()
            print("🛑 已停止 Subsonic 播放")
        }()
        
        async let audioStationStop: Void = {
            await audioStationService.pause()
            print("🛑 已停止 Audio Station 播放")
        }()
        
        // 等待所有停止操作完成
        let _ = await (subsonicStop, audioStationStop)
        
        // 🔑 清除锁屏播放信息
        await MainActor.run {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            print("🛑 已清除锁屏播放信息")
        }
    }
    
    // 🔑 新增：强制同步播放状态（解决首次播放显示问题）
    func forceSyncPlaybackStatus() async {
        await MainActor.run {
            // 强制更新一次播放信息
            updateCurrentSongInfo()
            
            // 确保Timer在有播放状态时运行
            if isPlaying {
                startUpdateTimer()
            }
        }
        
        // 🔑 添加额外的验证机制，如果播放时间仍然是0，再次尝试同步
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 额外延迟1秒
        await MainActor.run {
            if isPlaying && currentDuration == 0 {
                // 播放时间仍然是0，再次更新并启动Timer
                updateCurrentSongInfo()
                startUpdateTimer()
            }
        }
    }
    
    // 🔑 新增：强制更新锁屏播放信息的方法
    private func forceUpdateNowPlayingInfo() {
        switch currentDataSource {
        case .subsonic:
            subsonicService.forceUpdateNowPlayingInfo()
        case .audioStation:
            audioStationService.forceUpdateNowPlayingInfo() // 如需要可添加
            break
        case .local:
            localService.forceUpdateNowPlayingInfo() // 如需要可添加
            break
        case .musicKit:
            // MusicKit自动处理锁屏信息
            break
        }
    }
}
