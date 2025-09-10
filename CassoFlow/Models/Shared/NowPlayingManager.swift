import Foundation
import AVFoundation
import MediaPlayer
import UIKit

/// 统一的锁屏控制器和"正在播放"信息管理器
class NowPlayingManager {
    
    // MARK: - 单例
    static let shared = NowPlayingManager()
    
    // MARK: - 属性
    private var currentDelegate: NowPlayingDelegate?
    private var hasSetupRemoteCommands = false
    // 🔑 910新增
    private var isAppInBackground = false
    private var backgroundUpdateTimer: Timer?
    private var lastBackgroundUpdateTime: Date?
    private var hasConfiguredForBackground = false

    // MARK: - 初始化
    private init() {
        setupRemoteCommandCenter()
        setupAppStateNotifications()
    }

    deinit {
        clearRemoteCommandCenter()
        NotificationCenter.default.removeObserver(self)
    }
    
    // 设置应用状态通知监听
    private func setupAppStateNotifications() {
        // 应用变为活跃
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidBecomeActive()
        }
        
        // 应用即将失去活跃
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillResignActive()
        }
        
        // 🔑 910新增：应用进入后台
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppEnterBackground()
        }
        
        // 🔑 910新增：应用回到前台
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillEnterForeground()
        }
        
        // 🔑 910新增：应用即将终止
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillTerminate()
        }
    }
    
    // 处理应用变为活跃状态
    private func handleAppDidBecomeActive() {
        // 重新设置远程控制命令中心
        setupRemoteCommandCenter()
        
        // 如果有代理且正在播放，立即更新锁屏信息
        if let delegate = currentDelegate, delegate.isPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateNowPlayingInfo()
            }
        }
    }
    
    // 处理应用即将失去活跃状态
    private func handleAppWillResignActive() {
        // 确保锁屏信息被正确设置
        if currentDelegate != nil {
            updateNowPlayingInfo()
        }
    }
    
    // MARK: - 公共方法
    
    /// 设置当前的播放代理
    func setDelegate(_ delegate: NowPlayingDelegate?) {
        currentDelegate = delegate
        print("🎵 设置锁屏控制器代理: \(delegate != nil ? String(describing: type(of: delegate!)) : "nil")")
        
        // 🔑 当设置新的代理时，确保对应的音频会话处于活跃状态
        if let delegate = delegate {
            // 根据代理类型请求相应的音频会话
            let serviceType = mapDelegateToAudioService(delegate)
            let _ = AudioSessionManager.shared.requestAudioSession(for: serviceType)
        }
        
        // 重新设置远程控制命令中心以确保激活
        setupRemoteCommandCenter()
        
        // 如果有代理且正在播放，立即更新锁屏信息
        if let delegate = delegate, delegate.isPlaying {
            updateNowPlayingInfo()
        } else if delegate == nil {
            // 清除锁屏信息
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
            print("🔄 清除锁屏播放信息（无代理）")
        }
    }
    
    // 🔑 新增：将代理映射到音频服务类型
    private func mapDelegateToAudioService(_ delegate: NowPlayingDelegate) -> AudioSessionManager.ActiveMusicService {
        // 根据代理的类型名称判断服务类型
        let delegateTypeName = String(describing: type(of: delegate))
        
        if delegateTypeName.contains("Subsonic") {
            return .subsonic
        } else if delegateTypeName.contains("AudioStation") {
            return .audioStation
        } else if delegateTypeName.contains("Local") {
            return .local
        } else {
            return .musicKit // 默认
        }
    }
    
    /// 更新锁屏播放信息
    func updateNowPlayingInfo() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let delegate = self.currentDelegate,
                  let song = delegate.currentSong else {
                // 使用空字典而不是 nil
                MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
                print("🔄 清除锁屏播放信息（无有效状态）")
                return
            }
            
            var nowPlayingInfo = [String: Any]()
            
            // 基本信息
            nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = song.artistName
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.albumName ?? ""
            
            // 时间信息
            let playbackInfo = delegate.getPlaybackInfo()
            let validDuration = max(1.0, playbackInfo.total) // 确保时长至少为1秒
            let validCurrentTime = max(0.0, min(playbackInfo.current, validDuration)) // 确保当前时间不超过总时长
            
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = validDuration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = validCurrentTime
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = delegate.isPlaying ? 1.0 : 0.0
            
            // iOS 18+ 重要属性
            nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
            nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false
            nowPlayingInfo[MPNowPlayingInfoPropertyAvailableLanguageOptions] = []
            nowPlayingInfo[MPNowPlayingInfoPropertyCurrentLanguageOptions] = []
            
            // 队列信息
            let queueInfo = delegate.getQueueInfo()
            if !queueInfo.queue.isEmpty {
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = queueInfo.currentIndex
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = queueInfo.queue.count
            }
            
            // 专辑封面处理
            let artworkSize = CGSize(width: 600, height: 600)
            let artwork = self.createArtwork(for: song, delegate: delegate, size: artworkSize)
            if let artwork = artwork {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
            
            // 设置播放信息
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            
            // 确保远程控制命令启用
            self.ensureRemoteCommandsEnabled()
            
            print("🔄 设置锁屏播放信息:")
            print("   标题: \(song.title)")
            print("   艺术家: \(song.artistName)")
            print("   时长: \(validDuration)秒")
            print("   当前时间: \(validCurrentTime)秒")
            print("   播放速率: \(delegate.isPlaying ? 1.0 : 0.0)")
            
            // 如果没有封面，尝试异步加载
            if artwork == nil, let artworkURL = song.artworkURL {
                Task {
                    await self.loadAndUpdateArtwork(from: artworkURL, for: song)
                }
            }
        }
    }
    
    /// 更新播放进度信息
    func updatePlaybackProgress() {
        guard let delegate = currentDelegate else { return }
        
        let playbackInfo = delegate.getPlaybackInfo()
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playbackInfo.current
        info[MPNowPlayingInfoPropertyPlaybackRate] = delegate.isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    /// 强制更新锁屏播放信息
    func forceUpdateNowPlayingInfo() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("🔧 强制更新锁屏播放信息")
            
            // 重新设置远程控制命令中心
            self.setupRemoteCommandCenter()
            
            // 先清除现有信息
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
            
            // 短暂延迟后重新设置
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateNowPlayingInfo()
            }
        }
    }
    
    /// 清除锁屏播放信息
    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
        print("🔄 清除锁屏播放信息")
    }
    
    // MARK: - 私有方法
    
    /// 设置远程控制命令中心
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // 清除所有现有目标
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        
        // 启用命令
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        
        // 播放命令
        commandCenter.playCommand.addTarget { [weak self] _ in
            print("🎵 锁屏播放命令")
            Task {
                await self?.currentDelegate?.play()
            }
            return .success
        }
        
        // 暂停命令
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            print("⏸️ 锁屏暂停命令")
            Task {
                await self?.currentDelegate?.pause()
            }
            return .success
        }
        
        // 播放/暂停切换命令
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            print("⏯️ 锁屏播放/暂停切换命令")
            Task {
                guard let delegate = self?.currentDelegate else { return }
                if delegate.isPlaying {
                    await delegate.pause()
                } else {
                    await delegate.play()
                }
            }
            return .success
        }
        
        // 下一首命令
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            print("⏭️ 锁屏下一首命令")
            Task {
                try? await self?.currentDelegate?.skipToNext()
            }
            return .success
        }
        
        // 上一首命令
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            print("⏮️ 锁屏上一首命令")
            Task {
                try? await self?.currentDelegate?.skipToPrevious()
            }
            return .success
        }
        
        // 跳转命令
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                let time = event.positionTime
                print("⏩ 锁屏跳转命令: \(time)秒")
                Task {
                    await self?.currentDelegate?.seek(to: time)
                }
                return .success
            }
            return .commandFailed
        }
        
        hasSetupRemoteCommands = true
        print("✅ 统一远程控制命令中心配置完成")
    }
    
    /// 确保远程控制命令启用
    private func ensureRemoteCommandsEnabled() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // 强制启用所有需要的命令
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
    }
    
    /// 清除远程控制命令中心
    private func clearRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // 移除所有目标
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        
        // 禁用命令
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        
        hasSetupRemoteCommands = false
        print("🧹 统一远程控制命令中心已清除")
    }
    
    /// 创建专辑封面
    @MainActor private func createArtwork(for song: UniversalSong, delegate: NowPlayingDelegate, size: CGSize) -> MPMediaItemArtwork? {
        // 根据不同的音乐源处理封面
        switch song.source {
        case .local:
            // 本地音乐封面处理
            if let localSongItem = song.originalData as? LocalSongItem,
               let artworkData = localSongItem.artworkData,
               let image = UIImage(data: artworkData) {
                print("🎨 使用本地音乐封面")
                return MPMediaItemArtwork(boundsSize: size) { _ in image }
            }
            
        case .subsonic:
            // Subsonic音乐封面处理 - 优先使用缓存
            if let artworkURL = song.artworkURL,
               let cachedImage = ImageCacheManager.shared.getCachedImage(for: artworkURL) {
                print("🎨 使用缓存的Subsonic音乐封面")
                return MPMediaItemArtwork(boundsSize: size) { _ in cachedImage }
            }
            
        case .audioStation:
            // AudioStation音乐封面处理 - 需要特殊处理
            // 首先尝试使用歌曲自带的封面URL
            if let artworkURL = song.artworkURL,
               let cachedImage = ImageCacheManager.shared.getCachedImage(for: artworkURL) {
                print("🎨 使用缓存的AudioStation音乐封面（歌曲URL）")
                return MPMediaItemArtwork(boundsSize: size) { _ in cachedImage }
            }
            
        case .musicKit:
            break
        }
        
        // 使用自定义默认封面作为兜底方案
        let defaultImage = createDefaultArtwork(size: size)
        print("🎨 使用自定义默认音乐图标作为封面")
        return MPMediaItemArtwork(boundsSize: size) { _ in defaultImage }
    }
    
    /// 创建自定义默认封面
    private func createDefaultArtwork(size: CGSize) -> UIImage {
            // 创建一个带背景的自定义图像
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // 设置背景色
            UIColor.systemYellow.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 绘制音乐符号
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: size.width * 0.5, weight: .bold)
            if let symbolImage = UIImage(systemName: "music.note", withConfiguration: symbolConfig)?.withTintColor(.black, renderingMode: .alwaysOriginal) {
                let symbolSize = symbolImage.size
                let symbolRect = CGRect(
                    x: (size.width - symbolSize.width) / 2,
                    y: (size.height - symbolSize.height) / 2,
                    width: symbolSize.width,
                    height: symbolSize.height
                )
                symbolImage.draw(in: symbolRect)
            }
        }
        
        return image
    }
    
    /// 异步加载并更新专辑封面
    private func loadAndUpdateArtwork(from url: URL, for song: UniversalSong) async {
        // 检查当前歌曲是否还是我们要加载封面的歌曲
        guard let delegate = currentDelegate,
              let currentSong = delegate.currentSong,
              currentSong.id == song.id else {
            print("⚠️ 歌曲已切换，取消封面加载")
            return
        }
        
        print("🖼️ 开始异步加载封面: \(url)")
        
        // 使用ImageCacheManager加载封面
        let imageCache = await ImageCacheManager.shared
        
        // 先检查缓存
        if let cachedImage = await imageCache.getCachedImage(for: url) {
            await updateArtworkInNowPlaying(image: cachedImage)
            return
        }
        
        // 如果正在下载，等待下载完成
        if await imageCache.isDownloading(url) {
            await waitForImageDownload(url: url, targetSongId: song.id)
            return
        }
        
        // 开始下载
        await imageCache.preloadImage(from: url)
        await waitForImageDownload(url: url, targetSongId: song.id)
        
    }
    
    /// 等待图片下载完成
    private func waitForImageDownload(url: URL, targetSongId: String) async {
        let imageCache = await ImageCacheManager.shared
        let maxWaitTime = 10.0
        let startTime = Date()
        let checkInterval: UInt64 = 200_000_000 // 0.2秒
        
        while Date().timeIntervalSince(startTime) < maxWaitTime {
            // 检查当前歌曲是否还匹配
            guard let delegate = currentDelegate,
                  let currentSong = delegate.currentSong,
                  currentSong.id == targetSongId else {
                print("⚠️ 歌曲已切换，停止等待封面下载")
                return
            }
            
            // 检查是否下载完成
            if let cachedImage = await imageCache.getCachedImage(for: url) {
                print("✅ 封面下载完成，更新锁屏信息")
                await updateArtworkInNowPlaying(image: cachedImage)
                return
            }
            
            // 如果不再下载中，说明下载失败
            if await !imageCache.isDownloading(url) {
                print("❌ 封面下载失败")
                return
            }
            
            try? await Task.sleep(nanoseconds: checkInterval)
        }
        
        print("⏱️ 封面下载超时")
    }
    
    /// 更新锁屏信息中的封面
    private func updateArtworkInNowPlaying(image: UIImage) async {
        await MainActor.run {
            var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            let artworkSize = CGSize(width: 600, height: 600)
            let artwork = MPMediaItemArtwork(boundsSize: artworkSize) { _ in image }
            updatedInfo[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
            
            print("🖼️ 专辑封面已更新到锁屏控制中心")
        }
    }
    
    // 🔑 910新增：处理应用进入后台
    private func handleAppEnterBackground() {
        isAppInBackground = true
        hasConfiguredForBackground = true
        print("📱 NowPlayingManager: 应用进入后台")
        
        // 🔑 确保在后台时锁屏信息仍然有效
        if let delegate = currentDelegate, delegate.isPlaying {
            // 立即更新一次锁屏信息
            updateNowPlayingInfo()
            
            // 🔑 启动后台定时器，定期更新锁屏信息
            startBackgroundUpdateTimer()
            
            // 延迟再次更新，确保稳定性
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.updateNowPlayingInfo()
            }
            
            // 额外延迟确保完全稳定
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.updateNowPlayingInfo()
            }
        }
    }
    
    // 🔑 新增：处理应用回到前台
    private func handleAppWillEnterForeground() {
        isAppInBackground = false
        print("📱 NowPlayingManager: 应用回到前台")
        
        // 🔑 停止后台定时器
        stopBackgroundUpdateTimer()
        
        // 🔑 重新激活并更新锁屏信息
        if currentDelegate != nil {
            setupRemoteCommandCenter()
            updateNowPlayingInfo()
            
            // 延迟再次更新确保正确显示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.updateNowPlayingInfo()
            }
            
            // 额外延迟确保完全稳定
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateNowPlayingInfo()
            }
        }
    }
    
    // 🔑 新增：处理应用即将终止
    private func handleAppWillTerminate() {
        print("📱 NowPlayingManager: 应用即将终止")
        // 保持锁屏信息直到应用完全终止
        if currentDelegate != nil {
            updateNowPlayingInfo()
        }
    }
    
    // 🔑 新增：启动后台更新定时器
    private func startBackgroundUpdateTimer() {
        guard currentDelegate?.isPlaying == true else { return }
        
        stopBackgroundUpdateTimer() // 确保没有重复的定时器
        
        // 每3秒更新一次锁屏信息，保持活跃状态
        backgroundUpdateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 检查是否仍在后台
            if self.isAppInBackground {
                // 更新锁屏信息
                self.updateNowPlayingInfo()
                
                // 记录最后一次更新时间
                self.lastBackgroundUpdateTime = Date()
            } else {
                // 如果已经回到前台，停止定时器
                self.stopBackgroundUpdateTimer()
            }
        }
    }
    
    // 🔑 新增：停止后台更新定时器
    private func stopBackgroundUpdateTimer() {
        backgroundUpdateTimer?.invalidate()
        backgroundUpdateTimer = nil
    }
}

// MARK: - 代理协议

/// 锁屏控制器代理协议
protocol NowPlayingDelegate: AnyObject {
    /// 当前播放的歌曲
    var currentSong: UniversalSong? { get }
    
    /// 是否正在播放
    var isPlaying: Bool { get }
    
    /// 获取播放进度信息
    func getPlaybackInfo() -> (current: TimeInterval, total: TimeInterval, isPlaying: Bool)
    
    /// 获取队列信息
    func getQueueInfo() -> (queue: [UniversalSong], currentIndex: Int)
    
    /// 播放
    func play() async
    
    /// 暂停
    func pause() async
    
    /// 下一首
    func skipToNext() async throws
    
    /// 上一首
    func skipToPrevious() async throws
    
    /// 跳转到指定时间
    func seek(to time: TimeInterval) async
}
