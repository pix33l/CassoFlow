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

/// 音乐服务类 - 专注于播放控制和UI状态管理
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
    @Published var currentTrackID: String?
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
    
    @Published var isHapticFeedbackEnabled: Bool = false
    
    // MARK: - 屏幕常亮属性
    @Published var isScreenAlwaysOn: Bool = false {
        didSet {
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = self.isScreenAlwaysOn
            }
        }
    }
    
    // MARK: - 库视图控制
    @Published var shouldCloseLibrary: Bool = false
    
    // MARK: - 数据源管理
    
    var currentDataSource: MusicDataSourceType {
        get { coordinator.currentDataSource }
        set { coordinator.currentDataSource = newValue }
    }
    
    // MARK: - 存储键值
    
    private static let playerSkinKey = "SelectedPlayerSkin"
    private static let cassetteSkinKey = "SelectedCassetteSkin"
    private static let cassetteEffectKey = "CassetteEffectEnabled"
    private static let hapticFeedbackKey = "HapticFeedbackEnabled"
    private static let screenAlwaysOnKey = "ScreenAlwaysOnEnabled"
    private static let coverStyleKey = "SelectedCoverStyle"
    
    // 缓存上一次的关键值
    private var lastTitle: String = ""
    private var lastArtist: String = ""
    private var lastTrackID: String? = nil
    private var lastTrackIndex: Int? = nil
    private var lastTotalTracks: Int = 0
    
    var repeatMode: MusicPlayer.RepeatMode {
        get { musicKitPlayer.state.repeatMode ?? .none }
        set { musicKitPlayer.state.repeatMode = newValue }
    }
    
    var shuffleMode: MusicPlayer.ShuffleMode {
        get { musicKitPlayer.state.shuffleMode ?? .off }
        set { musicKitPlayer.state.shuffleMode = newValue }
    }
    
    // MARK: - 初始化
    
    init() {
        // 加载皮肤设置
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
        
        // 启动定时器
        startUpdateTimer()
        
        // 监听通知
        setupNotifications()
    }
    
    deinit {
        stopUpdateTimer()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 设置加载
    
    private func loadSettings() {
        isCassetteEffectEnabled = UserDefaults.standard.bool(forKey: Self.cassetteEffectKey)
        
        if UserDefaults.standard.object(forKey: Self.hapticFeedbackKey) == nil {
            isHapticFeedbackEnabled = false
            UserDefaults.standard.set(false, forKey: Self.hapticFeedbackKey)
        } else {
            isHapticFeedbackEnabled = UserDefaults.standard.bool(forKey: Self.hapticFeedbackKey)
        }
        
        isScreenAlwaysOn = UserDefaults.standard.bool(forKey: Self.screenAlwaysOnKey)
        UIApplication.shared.isIdleTimerDisabled = isScreenAlwaysOn
        
        let savedCoverStyle = UserDefaults.standard.string(forKey: Self.coverStyleKey)
        if let styleString = savedCoverStyle,
           let style = CoverStyle(rawValue: styleString) {
            currentCoverStyle = style
        } else {
            currentCoverStyle = .rectangle
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMembershipStatusChanged),
            name: NSNotification.Name("MembershipStatusChanged"),
            object: nil
        )
    }
    
    // MARK: - 播放控制方法
    
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
    
    /// 播放专辑中的特定歌曲（向后兼容）
    func playTrack(_ track: Track, in album: Album) async throws {
        let songs = try await album.with([.tracks]).tracks ?? []
        guard let index = songs.firstIndex(where: { $0.id == track.id }) else { return }
        
        let universalSongs = songs.map { song in
            UniversalSong(
                id: song.id.rawValue,
                title: song.title,
                artistName: song.artistName,
                albumName: song.albumTitle,
                duration: song.duration ?? 0,
                trackNumber: song.trackNumber,
                artworkURL: song.artwork?.url(width: 300, height: 300),
                streamURL: nil,
                source: .musicKit,
                originalData: song
            )
        }
        
        try await playUniversalSongs(universalSongs, startingAt: index)
    }
    
    /// 播放播放列表中的特定歌曲（向后兼容）
    func playTrack(_ track: Track, in playlist: Playlist) async throws {
        let songs = try await playlist.with([.tracks]).tracks ?? []
        guard let index = songs.firstIndex(where: { $0.id == track.id }) else { return }
        
        let universalSongs = songs.map { song in
            UniversalSong(
                id: song.id.rawValue,
                title: song.title,
                artistName: song.artistName,
                albumName: song.albumTitle,
                duration: song.duration ?? 0,
                trackNumber: song.trackNumber,
                artworkURL: song.artwork?.url(width: 300, height: 300),
                streamURL: nil,
                source: .musicKit,
                originalData: song
            )
        }
        
        try await playUniversalSongs(universalSongs, startingAt: index)
    }
    
    /// 播放专辑（向后兼容）
    func playAlbum(_ album: Album, shuffled: Bool = false) async throws {
        let songs = try await album.with([.tracks]).tracks ?? []
        let universalSongs = songs.map { song in
            UniversalSong(
                id: song.id.rawValue,
                title: song.title,
                artistName: song.artistName,
                albumName: song.albumTitle,
                duration: song.duration ?? 0,
                trackNumber: song.trackNumber,
                artworkURL: song.artwork?.url(width: 300, height: 300),
                streamURL: nil,
                source: .musicKit,
                originalData: song
            )
        }
        
        let finalSongs = shuffled ? universalSongs.shuffled() : universalSongs
        try await playUniversalSongs(finalSongs)
    }
    
    /// 播放播放列表（向后兼容）
    func playPlaylist(_ playlist: Playlist, shuffled: Bool = false) async throws {
        let songs = try await playlist.with([.tracks]).tracks ?? []
        let universalSongs = songs.map { song in
            UniversalSong(
                id: song.id.rawValue,
                title: song.title,
                artistName: song.artistName,
                albumName: song.albumTitle,
                duration: song.duration ?? 0,
                trackNumber: song.trackNumber,
                artworkURL: song.artwork?.url(width: 300, height: 300),
                streamURL: nil,
                source: .musicKit,
                originalData: song
            )
        }
        
        let finalSongs = shuffled ? universalSongs.shuffled() : universalSongs
        try await playUniversalSongs(finalSongs)
    }
    
    /// 播放通用专辑
    func playUniversalAlbum(_ album: UniversalAlbum, shuffled: Bool = false) async throws {
        let detailedAlbum = try await coordinator.getAlbum(id: album.id)
        let finalSongs = shuffled ? detailedAlbum.songs.shuffled() : detailedAlbum.songs
        try await playUniversalSongs(finalSongs)
    }
    
    /// 播放通用播放列表
    func playUniversalPlaylist(_ playlist: UniversalPlaylist, shuffled: Bool = false) async throws {
        let detailedPlaylist = try await coordinator.getPlaylist(id: playlist.id)
        let finalSongs = shuffled ? detailedPlaylist.songs.shuffled() : detailedPlaylist.songs
        try await playUniversalSongs(finalSongs)
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
            audioEffectsManager.setMusicPlayingState(true)
        }
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
            audioEffectsManager.setMusicPlayingState(false)
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
    }
    
    /// 播放上一首
    func skipToPrevious() async throws {
        switch currentDataSource {
        case .musicKit:
            try await musicKitPlayer.skipToPreviousEntry()
        case .subsonic:
            try await subsonicService.skipToPrevious()
        }
    }
    
    /// 开始快退
    func startFastRewind() {
        stopSeek()
        isFastRewinding = true
        
        seekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            switch self.currentDataSource {
            case .musicKit:
                let newTime = max(0, self.musicKitPlayer.playbackTime - 5.0)
                self.musicKitPlayer.playbackTime = newTime
            case .subsonic:
                self.subsonicService.seekBackward(5.0)
            }
        }
    }
    
    /// 开始快进
    func startFastForward() {
        stopSeek()
        isFastForwarding = true
        
        seekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            switch self.currentDataSource {
            case .musicKit:
                let newTime = min(self.totalDuration, self.musicKitPlayer.playbackTime + 5.0)
                self.musicKitPlayer.playbackTime = newTime
            case .subsonic:
                self.subsonicService.seekForward(5.0)
            }
        }
    }
    
    /// 停止快速前进或快退
    func stopSeek() {
        seekTimer?.invalidate()
        seekTimer = nil
        isFastForwarding = false
        isFastRewinding = false
    }
    
    /// 重置库视图关闭状态
    func resetLibraryCloseState() {
        shouldCloseLibrary = false
    }
    
    // MARK: - 数据获取方法（委托给协调器）
    
    /// 获取用户媒体库专辑（向后兼容）
    func fetchUserLibraryAlbums() async throws -> MusicItemCollection<Album> {
        var request = MusicLibraryRequest<Album>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 50
        
        let response = try await request.response()
        return response.items
    }
    
    /// 获取用户媒体库播放列表（向后兼容）
    func fetchUserLibraryPlaylists() async throws -> MusicItemCollection<Playlist> {
        var request = MusicLibraryRequest<Playlist>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 50
        
        let response = try await request.response()
        return response.items
    }
    
    /// 获取通用专辑列表
    func fetchUniversalAlbums() async throws -> [UniversalAlbum] {
        return try await coordinator.getRecentAlbums()
    }
    
    /// 获取通用播放列表
    func fetchUniversalPlaylists() async throws -> [UniversalPlaylist] {
        return try await coordinator.getRecentPlaylists()
    }
    
    /// 搜索音乐
    func searchMusic(query: String) async throws -> (artists: [UniversalArtist], albums: [UniversalAlbum], songs: [UniversalSong]) {
        return try await coordinator.search(query: query)
    }
    
    /// 获取Subsonic服务（用于配置）
    func getSubsonicService() -> SubsonicMusicService {
        return subsonicService
    }
    
    /// 获取音乐服务协调器
    func getCoordinator() -> MusicServiceCoordinator {
        return coordinator
    }
    
    // MARK: - 状态更新
    
    @objc private func handleMembershipStatusChanged() {
        Task { @MainActor in
            // 检查皮肤可用性
            if !SkinHelper.isPlayerSkinOwned(currentPlayerSkin.name, storeManager: storeManager) {
                if let defaultSkin = PlayerSkin.playerSkin(named: "CF-DEMO") {
                    currentPlayerSkin = defaultSkin
                    UserDefaults.standard.set(defaultSkin.name, forKey: Self.playerSkinKey)
                }
            }
            
            if !SkinHelper.isCassetteSkinOwned(currentCassetteSkin.name, storeManager: storeManager) {
                if let defaultSkin = CassetteSkin.cassetteSkin(named: "CFT-DEMO") {
                    currentCassetteSkin = defaultSkin
                    UserDefaults.standard.set(defaultSkin.name, forKey: Self.cassetteSkinKey)
                }
            }
        }
    }
    
    // MARK: - 定时器管理
    
    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCurrentSongInfo()
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
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
            resetPlaybackInfo()
            return
        }
        
        let duration: TimeInterval
        var trackID: String? = nil
        
        switch entry.item {
        case .song(let song):
            duration = song.duration ?? 0
            trackID = song.id.rawValue
        case .musicVideo(let musicVideo):
            duration = musicVideo.duration ?? 0
            trackID = musicVideo.id.rawValue
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
        
        updatePlaybackInfo(
            title: entry.title,
            artist: entry.subtitle ?? "",
            duration: duration,
            currentTime: musicKitPlayer.playbackTime,
            trackID: trackID,
            trackIndex: trackIndex.map { $0 + 1 },
            totalTracks: entries.count,
            isPlaying: playbackStatus
        )
    }
    
    private func updateSubsonicInfo() {
        let queueInfo = subsonicService.getQueueInfo()
        let playbackInfo = subsonicService.getPlaybackInfo()
        
        guard let currentSong = subsonicService.getCurrentSong() else {
            resetPlaybackInfo()
            return
        }
        
        updatePlaybackInfo(
            title: currentSong.title,
            artist: currentSong.artistName,
            duration: playbackInfo.total,
            currentTime: playbackInfo.current,
            trackID: currentSong.id,
            trackIndex: queueInfo.currentIndex + 1,
            totalTracks: queueInfo.queue.count,
            isPlaying: playbackInfo.isPlaying
        )
    }
    
    private func updatePlaybackInfo(
        title: String,
        artist: String,
        duration: TimeInterval,
        currentTime: TimeInterval,
        trackID: String?,
        trackIndex: Int?,
        totalTracks: Int,
        isPlaying: Bool
    ) {
        let songInfoChanged = title != lastTitle ||
                             artist != lastArtist ||
                             trackID != lastTrackID ||
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
            }
        }
        
        DispatchQueue.main.async {
            self.isPlaying = isPlaying
            self.currentDuration = currentTime
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
    
    // MARK: - 皮肤和设置方法
    
    func setPlayerSkin(_ skin: PlayerSkin) {
        currentPlayerSkin = skin
        UserDefaults.standard.set(skin.name, forKey: Self.playerSkinKey)
    }
    
    func setCassetteSkin(_ skin: CassetteSkin) {
        currentCassetteSkin = skin
        UserDefaults.standard.set(skin.name, forKey: Self.cassetteSkinKey)
    }
    
    func setCassetteEffect(enabled: Bool) {
        isCassetteEffectEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.cassetteEffectKey)
    }
    
    func setHapticFeedback(enabled: Bool) {
        isHapticFeedbackEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.hapticFeedbackKey)
    }
    
    func setScreenAlwaysOn(enabled: Bool) {
        isScreenAlwaysOn = enabled
        UserDefaults.standard.set(enabled, forKey: Self.screenAlwaysOnKey)
    }
    
    func setCoverStyle(_ style: CoverStyle) {
        currentCoverStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: Self.coverStyleKey)
    }
    
    // MARK: - 工具方法
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// 请求音乐授权（向后兼容）
    func requestMusicAuthorization() async {
        let status = await MusicAuthorization.request()
        // 可以在这里处理授权结果
    }
}