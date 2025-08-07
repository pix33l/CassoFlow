import MusicKit
import Combine
import Foundation
import UIKit

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
    
    // MARK: - 核心组件
    private let musicKitPlayer = ApplicationMusicPlayer.shared
    private let subsonicService = SubsonicMusicService.shared
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
                resetPlaybackStateForDataSourceChange()
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
    
    // 新增：后台状态监听Timer
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
    var repeatMode: MusicPlayer.RepeatMode {
        get { musicKitPlayer.state.repeatMode ?? .none }
        set { musicKitPlayer.state.repeatMode = newValue }
    }
    
    // 随机播放
    var shuffleMode: MusicPlayer.ShuffleMode {
        get { musicKitPlayer.state.shuffleMode ?? .off }
        set { musicKitPlayer.state.shuffleMode = newValue }
    }
    
    /// ？请求音乐授权
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
    
    // ？设置MusicKit
    private func setupMusicKit() async {
        do {
            // 检查订阅状态
            _ = try await MusicSubscription.current
        } catch {
            // 设置失败，静默处理
        }
    }
    
    /// ？重置库视图关闭状态
    func resetLibraryCloseState() {
        shouldCloseLibrary = false
    }
    
    // MARK: - 初始化
    
    init() {
        // ？设置默认的显示状态
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
        updateCurrentSongInfo()
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
        let currentPlayingState = musicKitPlayer.state.playbackStatus == .playing
        
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
    
    // MARK: - 数据获取方法（委托给协调器）
    
    /// 获取Subsonic服务（用于配置）
    func getSubsonicService() -> SubsonicMusicService {
        return subsonicService
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
        switch currentDataSource {
        case .musicKit:
            updateMusicKitInfo()
        case .subsonic:
            updateSubsonicInfo()
        }
    }
    
    private func updateMusicKitInfo() {
        guard let entry = musicKitPlayer.queue.currentEntry else {
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
        
        let entries = musicKitPlayer.queue.entries
        let trackIndex = entries.firstIndex(where: { $0.id == entry.id })
        let playbackStatus = musicKitPlayer.state.playbackStatus == .playing
        
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
            self.currentDuration = self.musicKitPlayer.playbackTime
            
            // 重要：即使在后台也要更新队列累计时长，确保磁带进度正确
            let elapsedQueueDuration = self.calculateQueueElapsedDuration(entries: entries, currentEntryIndex: trackIndex)
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
        let queueTotalDuration = calculateSubsonicQueueTotalDuration(queue: queueInfo.queue)
        let queueElapsedDuration = calculateSubsonicQueueElapsedDuration(
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
    
    // MARK: - 播放时长计算方法

    /// 计算 Subsonic 队列中所有歌曲的总时长
    private func calculateSubsonicQueueTotalDuration(queue: [UniversalSong]) -> TimeInterval {
        let totalDuration = queue.reduce(0) { total, song in
            total + song.duration
        }
        
        // 如果总时长为0，返回默认值
        return totalDuration > 0 ? totalDuration : TimeInterval(queue.count * 180) // 每首歌默认3分钟
    }
    
    /// 计算 Subsonic 队列中已播放的总时长
    private func calculateSubsonicQueueElapsedDuration(queue: [UniversalSong], currentIndex: Int, currentTime: TimeInterval) -> TimeInterval {
        guard currentIndex < queue.count else { return 0 }
        
        var elapsedDuration: TimeInterval = 0
        
        // 计算当前歌曲之前所有歌曲的总时长
        for index in 0..<currentIndex {
            elapsedDuration += queue[index].duration
        }
        
        // 加上当前歌曲的播放时长
        elapsedDuration += currentTime
        
        return elapsedDuration
    }

    /// 计算队列中所有歌曲的总时长（MusicKit）
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

    /// 计算队列中已播放的总时长（MusicKit）
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
        elapsedDuration += musicKitPlayer.playbackTime
        
        return elapsedDuration
    }
    
    // MARK: - 播放控制方法
    
    /// 播放 MusicKit 专辑中的特定歌曲
    func playTrack(_ track: Track, in album: Album) async throws {
        let songs = try await album.with([.tracks]).tracks ?? []
        guard let index = songs.firstIndex(where: { $0.id == track.id }) else { return }
        
        musicKitPlayer.queue = .init(for: songs, startingAt: songs[index])
        try await musicKitPlayer.play()
        
        // 播放成功后触发关闭库视图
        await MainActor.run {
            shouldCloseLibrary = true
        }
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.3秒
        await forceSyncPlaybackStatus()
    }
    
    /// 播放 MusicKit 播放列表中的特定歌曲
    func playTrack(_ track: Track, in playlist: Playlist) async throws {
        let songs = try await playlist.with([.tracks]).tracks ?? []
        guard let index = songs.firstIndex(where: { $0.id == track.id }) else { return }
        
        musicKitPlayer.queue = .init(for: songs, startingAt: songs[index])
        try await musicKitPlayer.play()
        
        // 播放成功后触发关闭库视图
        await MainActor.run {
            shouldCloseLibrary = true
        }
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.3秒
        await forceSyncPlaybackStatus()
    }
    
    /// 播放 MusicKit 播放专辑（可选择随机播放）
    func playAlbum(_ album: Album, shuffled: Bool = false) async throws {
        let songs = try await album.with([.tracks]).tracks ?? []
        if shuffled {
            musicKitPlayer.state.shuffleMode = .songs
        }
        musicKitPlayer.queue = .init(for: songs, startingAt: nil)
        try await musicKitPlayer.play()
        
        // 播放成功后触发关闭库视图
        await MainActor.run {
            shouldCloseLibrary = true
        }
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.3秒
        await forceSyncPlaybackStatus()
    }
    
    /// 播放 MusicKit 播放播放列表（可选择随机播放）
    func playPlaylist(_ playlist: Playlist, shuffled: Bool = false) async throws {
        let songs = try await playlist.with([.tracks]).tracks ?? []
        if shuffled {
            musicKitPlayer.state.shuffleMode = .songs
        }
        musicKitPlayer.queue = .init(for: songs, startingAt: nil)
        try await musicKitPlayer.play()
        
        // 播放成功后触发关闭库视图
        await MainActor.run {
            shouldCloseLibrary = true
        }
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.3秒
        await forceSyncPlaybackStatus()
    }
    
    /// 播放通用歌曲队列
    func playUniversalSongs(_ songs: [UniversalSong], startingAt index: Int = 0) async throws {
        switch currentDataSource {
        case .musicKit:
            try await playMusicKitSongs(songs, startingAt: index)
        case .subsonic:
            try await subsonicService.playQueue(songs, startingAt: index)
        }
        
        await MainActor.run {
            shouldCloseLibrary = true
        }
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.3秒
        await forceSyncPlaybackStatus()
    }
    
    /// 播放MusicKit歌曲
    private func playMusicKitSongs(_ songs: [UniversalSong], startingAt index: Int) async throws {
        let tracks = songs.compactMap { song -> Track? in
            guard let originalTrack = song.originalData as? Track else { return nil }
            return originalTrack
        }
        
        guard index < tracks.count else { return }
        
        musicKitPlayer.queue = .init(for: tracks, startingAt: tracks[index])
        try await musicKitPlayer.play()
    }
    
    /// 播放通用专辑
    func playUniversalAlbum(_ album: UniversalAlbum, shuffled: Bool = false) async throws {
        let detailedAlbum = try await coordinator.getAlbum(id: album.id)
        let finalSongs = shuffled ? detailedAlbum.songs.shuffled() : detailedAlbum.songs
        try await playUniversalSongs(finalSongs)
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.3秒
        await forceSyncPlaybackStatus()
    }
    
    /// 播放通用播放列表
    func playUniversalPlaylist(_ playlist: UniversalPlaylist, shuffled: Bool = false) async throws {
        let detailedPlaylist = try await coordinator.getPlaylist(id: playlist.id)
        let finalSongs = shuffled ? detailedPlaylist.songs.shuffled() : detailedPlaylist.songs
        try await playUniversalSongs(finalSongs)
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.1秒
        await forceSyncPlaybackStatus()
    }

    /// 播放
    func play() async throws {
        switch currentDataSource {
            case .musicKit:
                try await musicKitPlayer.play()
            case .subsonic:
                await subsonicService.play()
        }
        await MainActor.run {
            isPlaying = true
            // 同步播放状态到音频效果管理器
            audioEffectsManager.setMusicPlayingState(true)
            // 🔑 开始播放时启动Timer
            startUpdateTimer()
        }
        
        // 🔑 新增：延迟同步播放状态，解决首次播放显示问题
        try await Task.sleep(nanoseconds: 300_000_000) // 延迟0.1秒
        await forceSyncPlaybackStatus()
    }

    /// 暂停
    func pause() async {
        switch currentDataSource {
            case .musicKit:
                musicKitPlayer.pause()
            case .subsonic:
                await subsonicService.pause()
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
                try await musicKitPlayer.skipToNextEntry()
            case .subsonic:
                try await subsonicService.skipToNext()
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
                try await musicKitPlayer.skipToPreviousEntry()
            case .subsonic:
                try await subsonicService.skipToPrevious()
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
                let newTime = max(0, self.musicKitPlayer.playbackTime - 6.0) // 每0.1秒后退6秒
                self.musicKitPlayer.playbackTime = newTime
            case .subsonic:
                self.subsonicService.seekBackward(6.0)
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
                let newTime = min(self.totalDuration, self.musicKitPlayer.playbackTime + 6.0) // 每0.1秒前进6秒
                self.musicKitPlayer.playbackTime = newTime
            case .subsonic:
                self.subsonicService.seekForward(6.0)
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
        let entries = musicKitPlayer.queue.entries
        let currentEntry = musicKitPlayer.queue.currentEntry
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
    
    // 🔑 新增：切换数据源时重置播放状态
    private func resetPlaybackStateForDataSourceChange() {
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