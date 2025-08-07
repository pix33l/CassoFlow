import SwiftUI
import MusicKit
import Foundation

// MARK: - 设备适配扩展
extension UIScreen {
    /// 检测是否为小屏设备（iPhone SE系列和iPhone 13 mini等）
    static var isCompactDevice: Bool {
        // iPhone SE (1st gen): 568pt
        // iPhone SE (2nd & 3rd gen): 667pt
        // iPhone 13 mini: 812pt
        // iPhone 12 mini: 812pt
        // 小屏设备通常在812以下
        return UIScreen.main.bounds.height <= 812
    }
}

struct PlayerView: View {
    @EnvironmentObject private var musicService: MusicService
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showLibraryView = false
    @State private var showSettingsView = false
    @State private var showStoreView = false
    @State private var repeatMode: MusicPlayer.RepeatMode = .none
    @State private var isShuffled: MusicPlayer.ShuffleMode = .off
    @State private var rotationAngle: Double = 0
    @State private var rotationTimer: Timer?
    @State private var isRotating = false
    
    @State private var playbackTimer: Timer?
    @State private var accumulatedPlaybackTime: TimeInterval = 0
    @State private var showPaywallForLimit = false
    @State private var showQueueView = false  // 新增：显示播放队列视图
    
    // 新增：应用状态监听
    @Environment(\.scenePhase) private var scenePhase
    
    // 计算属性：当前播放进度
    private var progress: CGFloat {
        guard musicService.totalDuration > 0 else { return 0 }
        return CGFloat(musicService.currentDuration / musicService.totalDuration)
    }
    
    // 格式化剩余时间显示
    private func formatRemainingTime(_ time: TimeInterval) -> String {
        guard time > 0 else { return "-00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "-" + String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            PlayerBackgroundView(rotationAngle: $rotationAngle, showLibraryView: $showLibraryView)
            VStack{
                Spacer()
                PlayerControlsView(
                    showLibraryView: $showLibraryView,
                    showSettingsView: $showSettingsView,
                    showStoreView: $showStoreView,
                    showPaywallForLimit: $showPaywallForLimit,
                    showQueueView: $showQueueView,
                    progress: progress,
                    repeatMode: $repeatMode,
                    isShuffled: $isShuffled
                )
            }
        }
        .onAppear {

            if musicService.isPlaying {
                startRotation()
                startPlaybackTracking()
            }
        }
        .onChange(of: musicService.isPlaying) { _, isPlaying in
            // 合并所有播放状态相关的逻辑
            handlePlayingStateChange(isPlaying)
        }
        .onChange(of: [musicService.isFastForwarding, musicService.isFastRewinding]) { 
            // 快进/快退状态变化时，重新评估旋转需求
            startRotation()
        }
        .onChange(of: storeManager.membershipStatus.isActive) { _, isActive in
            if isActive {
                // 用户升级为会员，重置播放时间限制
                resetPlaybackTimer()
            }
        }
        // 新增：应用状态变化监听
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
            // 同时通知AudioEffectsManager场景变化
            AudioEffectsManager.shared.handleScenePhaseChangeFromPlayerView(newPhase)
        }
        .onDisappear {
            stopRotation()
            stopPlaybackTracking()
        }
        .sheet(isPresented: $showLibraryView) { UniversalLibraryView() }
        .sheet(isPresented: $showSettingsView) { SettingsView() }
        .sheet(isPresented: $showStoreView) { StoreView() }
        .sheet(isPresented: $showQueueView) { UniversalQueueView() }
        .fullScreenCover(isPresented: $showPaywallForLimit) {
            PaywallView()
                .environmentObject(storeManager)
                .environmentObject(musicService)
        }
        .onChange(of: showPaywallForLimit) { _, isPresented in
            if !isPresented {
                // PaywallView被关闭，执行处理逻辑
                handlePaywallDismissed()
            }
        }
        .onChange(of: musicService.shouldCloseLibrary) { _, shouldClose in
            if shouldClose && showLibraryView {
                showLibraryView = false
                // 重置状态
                musicService.resetLibraryCloseState()
            }
        }
    }
    
    // 新增：处理应用状态变化
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // 应用进入前台，根据播放状态智能恢复Timer
            if musicService.isPlaying || musicService.isFastForwarding || musicService.isFastRewinding {
                startRotation()
            }
            
            // 只在需要时启动播放追踪
            if musicService.isPlaying && !storeManager.membershipStatus.isActive {
                startPlaybackTracking()
            }
            
        case .inactive, .background:
            // 应用进入后台，停止所有UI相关Timer
            stopRotation()
            stopPlaybackTracking()
            
        @unknown default:
            break
        }
    }
    
    private func startRotation() {
        // 只有在真正需要旋转时才启动Timer
        guard shouldStartRotation() else {
            stopRotation()
            return
        }
        
        stopRotation()
        isRotating = true
        
        let (interval, angleIncrement) = getRotationParameters()
        
        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            // 动态检查是否还需要继续旋转
            if !self.shouldStartRotation() {
                self.stopRotation()
                return
            }
            
            // 快进快退时移除动画，直接更新角度避免卡顿
            if self.musicService.isFastForwarding || self.musicService.isFastRewinding {
                self.rotationAngle += angleIncrement
            } else {
                // 正常播放时保持平滑动画
                withAnimation(.linear(duration: interval)) {
                    self.rotationAngle += angleIncrement
                }
            }
        }
    }
    
    /// 判断是否需要启动旋转动画
    private func shouldStartRotation() -> Bool {
        // 快进快退时需要旋转
        if musicService.isFastForwarding || musicService.isFastRewinding {
            return true
        }
        
        // 正在播放时需要旋转
        if musicService.isPlaying {
            return true
        }
        
        // 其他情况（暂停、停止）不需要旋转
        return false
    }
    
    private func getRotationParameters() -> (TimeInterval, Double) {
        if musicService.isFastForwarding {
            return (0.03, 20.0) // 提高频率，减少每次角度增量
        } else if musicService.isFastRewinding {
            return (0.03, -20.0) // 提高频率，减少每次角度增量
        } else if musicService.isPlaying {
            return (0.05, 3.0) // 正常播放也稍微提高频率
        } else {
            return (0.05, 3.0)
        }
    }
    
    private func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        isRotating = false
    }
    
    // MARK: - 播放时间追踪方法（优化后台耗电）
    
    /// 开始追踪播放时间（智能化管理）
    private func startPlaybackTracking() {
        // 多重条件检查
        guard !storeManager.membershipStatus.isActive,  // 非会员
              musicService.isPlaying,                    // 正在播放
              scenePhase == .active                      // 应用在前台
        else {
            stopPlaybackTracking()
            return
        }
        
        // 停止现有的计时器
        stopPlaybackTracking()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // 🔑 使用 DispatchQueue.main.async 处理主线程属性访问
            DispatchQueue.main.async {
                // 在Timer运行过程中再次检查条件
                guard !self.storeManager.membershipStatus.isActive,
                      self.musicService.isPlaying,
                      self.scenePhase == .active else {
                    self.stopPlaybackTracking()
                    return
                }
                
                self.accumulatedPlaybackTime += 1.0
                
                // 检查是否达到3分钟限制（180秒）
                if self.accumulatedPlaybackTime >= 180 {
                    self.showPlaybackLimitReached()
                }
            }
        }
    }
    
    /// 停止追踪播放时间
    private func stopPlaybackTracking() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    /// 播放时间限制达到时的处理
    private func showPlaybackLimitReached() {
        guard !storeManager.membershipStatus.isActive else {
            stopPlaybackTracking()
            resetPlaybackTimer()
            return
        }
        
        // 停止计时器
        stopPlaybackTracking()
        
        // 显示升级弹窗
        showPaywallForLimit = true
        
        // 可选：添加触觉反馈
        if musicService.isHapticFeedbackEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
    }
    
    /// 重置播放时间计数器（当用户成为会员后调用）
    private func resetPlaybackTimer() {
        accumulatedPlaybackTime = 0
        stopPlaybackTracking()
    }
    
    /// 处理PaywallView关闭后的逻辑
    private func handlePaywallDismissed() {
        // 检查用户是否已经成为会员
        if storeManager.membershipStatus.isActive {
            // 用户已升级为会员，重置计时器
            resetPlaybackTimer()
        } else {
            // 用户依然是非会员，重置计时器让用户可以继续播放10分钟
            accumulatedPlaybackTime = 0
            
            // 如果音乐正在播放且应用在前台，重新开始追踪
            if musicService.isPlaying && scenePhase == .active {
                startPlaybackTracking()
            }
        }
    }
    
    // 新增：统一处理播放状态变化
    private func handlePlayingStateChange(_ isPlaying: Bool) {
        if isPlaying {
            // 播放时：智能启动旋转Timer
            startRotation()
            // 只在需要时启动播放追踪（后台时不启动）
            if scenePhase == .active && !storeManager.membershipStatus.isActive {
                startPlaybackTracking()
            }
        } else {
            // 暂停时：立即停止旋转Timer
            stopRotation()
            // 停止播放追踪
            stopPlaybackTracking()
        }
    }
}

// MARK: - 背景视图 (提取出来)

struct PlayerBackgroundView: View {
    @EnvironmentObject private var musicService: MusicService
    @EnvironmentObject private var storeManager: StoreManager
    @Binding var rotationAngle: Double
    @Binding var showLibraryView: Bool
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Image(musicService.currentPlayerSkin.cassetteBgImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
                if musicService.currentTrackID != nil {
                    HolesView(rotationAngle: $rotationAngle)
                        .padding(.bottom, 270.0)
                        .padding(.leading, 30.0)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }

                Image(musicService.currentPlayerSkin.playerImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                Button(action: {
                    if musicService.isHapticFeedbackEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    SoundManager.shared.playSound(.eject)
                    showLibraryView = true
                }) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.5)
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.40)
                
                if !storeManager.membershipStatus.isActive && musicService.currentPlayerSkin.name == "CF-DEMO" {
                    PayLabel()
                        .environmentObject(storeManager)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.1)
                }
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
}

// MARK: - 磁带孔视图 (提取出来)

struct HolesView: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var rotationAngle: Double
    
    var body: some View {
        ZStack {
            VStack(spacing: 15) {
                CassetteHole(isRotating: musicService.isPlaying, rotationAngle: $rotationAngle, shouldGrow: true)
                CassetteHole(isRotating: musicService.isPlaying, rotationAngle: $rotationAngle, shouldGrow: false)
            }
            .padding(.leading, 25.0)
            
            Image(musicService.currentCassetteSkin.cassetteImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 400, height:400)
        }
        // 添加对数据源切换的响应
        .onChange(of: musicService.currentDataSource) { _, newDataSource in
            // 当数据源切换时，确保磁带孔状态正确同步
            // 这里不需要特殊处理，因为MusicService会自动更新相关属性
        }
    }
}

// MARK: - 控制器视图 (提取出来)

struct PlayerControlsView: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var showLibraryView: Bool
    @Binding var showSettingsView: Bool
    @Binding var showStoreView: Bool
    @Binding var showPaywallForLimit: Bool
    @Binding var showQueueView: Bool
    let progress: CGFloat
    @Binding var repeatMode: MusicPlayer.RepeatMode
    @Binding var isShuffled: MusicPlayer.ShuffleMode
    
    var body: some View {
        
        let baseButtonHeight = musicService.currentPlayerSkin.buttonHeight
        // 如果是小屏设备，按钮高度减少10
        let buttonHeight = UIScreen.isCompactDevice ? baseButtonHeight - 10 : baseButtonHeight
        
        VStack(spacing: 0) {
            ControlButtonsView(
                showSettingsView: $showSettingsView,
                showStoreView: $showStoreView
            )
            .frame(height: buttonHeight)
            .padding(.horizontal, 10.0)
            .padding(.vertical, 5.0)
            
            SongInfoView(
                showLibraryView: $showLibraryView,
                showPaywallForLimit: $showPaywallForLimit,
                showQueueView: $showQueueView,
                repeatMode: $repeatMode,
                isShuffled: $isShuffled,
                progress: progress
            )
            .padding()
            .background(

                RoundedRectangle(cornerRadius: 8)
                    .inset(by: 4)
                    .fill(Color(musicService.currentPlayerSkin.screenColor))

                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 8))
                
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.4), lineWidth: 8)
                            .blur(radius: 12)
                            .offset(x: 0, y: 0)
                            .mask(RoundedRectangle(cornerRadius: 8))
                    )

                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(musicService.currentPlayerSkin.screenOutlineColor), lineWidth: 4))
            )
            .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(musicService.currentPlayerSkin.panelColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(musicService.currentPlayerSkin.panelOutlineColor), lineWidth: 2)
        )
        .padding()
    }
}

// MARK: - 控制器按钮视图 (进一步提取)

struct ControlButtonsView: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var showSettingsView: Bool
    @Binding var showStoreView: Bool
    
    @State private var libraryTapped = false
    @State private var previousTapped = false
    @State private var playPauseTapped = false
    @State private var nextTapped = false
    @State private var storeTapped = false
    
    var body: some View {
        HStack(spacing: 5) {
            ControlButton(systemName: "recordingtape", action: {
                if musicService.isHapticFeedbackEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
                showStoreView = true
            })
            
            ControlButton(
                systemName: "backward.fill",
                action: {
                    if musicService.isHapticFeedbackEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                    }
                    Task { try await musicService.skipToPrevious() }
                },
                longPressAction: {
                    musicService.startFastRewind()
                },
                longPressEndAction: {
                    musicService.stopSeek()
                }
            )
            
            ControlButton(
                systemName: musicService.isPlaying ? "pause.fill" : "play.fill",
                action: {
                    if musicService.isHapticFeedbackEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                    }
                    Task {
                        if musicService.isPlaying {
                            await musicService.pause()
                        } else {
                            try await musicService.play()
                        }
                    }
                }
            )
            
            ControlButton(
                systemName: "forward.fill",
                action: {
                    if musicService.isHapticFeedbackEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                    }
                    Task { try await musicService.skipToNext() }
                },
                longPressAction: {
                    musicService.startFastForward()
                },
                longPressEndAction: {
                    musicService.stopSeek()
                }
            )
            
            ControlButton(systemName: "gearshape") {
                if musicService.isHapticFeedbackEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
                showSettingsView = true
            }
        }
    }
}

// MARK: - 歌曲信息视图 (进一步提取)

struct SongInfoView: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var showLibraryView: Bool
    @Binding var showPaywallForLimit: Bool
    @Binding var showQueueView: Bool
    @Binding var repeatMode: MusicPlayer.RepeatMode
    @Binding var isShuffled: MusicPlayer.ShuffleMode
    let progress: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: UIScreen.isCompactDevice ? 8 : 5) {
                // 根据屏幕尺寸判断是否显示TrackInfoHeader
                if !UIScreen.isCompactDevice {
                    TrackInfoHeader(showPaywallForLimit: $showPaywallForLimit,
                        showQueueView: $showQueueView
                    )
                }
                
                RepeatAndShuffleView(repeatMode: $repeatMode, isShuffled: $isShuffled, showLibraryView: $showLibraryView)
                PlaybackProgressView(progress: progress)
            }
        }
        .frame(height: UIScreen.isCompactDevice ? 55.0 : 80.0)
    }
}

// MARK: - 追踪信息头部 (进一步提取)

struct TrackInfoHeader: View {
    @EnvironmentObject private var musicService: MusicService
    @EnvironmentObject private var storeManager: StoreManager
    @Binding var showPaywallForLimit: Bool
    @Binding var showQueueView: Bool
    
    var body: some View {
        HStack {
            
            Group {
                Button {
                    showQueueView = true
                    if musicService.isHapticFeedbackEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                            .font(.subheadline)
                        
                        if let index = musicService.currentTrackIndex, musicService.totalTracksInQueue > 0 {
                            Text("PGM NO. \(index)/\(musicService.totalTracksInQueue)")
                        } else {
                            Text("PGM NO. 0/0")
                        }
                    }
                }
            }
            .padding(.leading, 4)
            
            Spacer()
            
            Button {
                if musicService.isHapticFeedbackEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
                
                // 检查会员状态
                if storeManager.membershipStatus.isActive {
                    musicService.setCassetteEffect(enabled: !musicService.isCassetteEffectEnabled)
                } else {
                    // 非会员用户，弹出PaywallView
                    showPaywallForLimit = true
                }

            } label: {
                Text("SOUND EFFECT")
                    .font(.caption)
                    .padding(4)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(
                        (storeManager.membershipStatus.isActive && musicService.isCassetteEffectEnabled) ?
                        Color(musicService.currentPlayerSkin.screenTextColor) :
                        Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                (storeManager.membershipStatus.isActive && musicService.isCassetteEffectEnabled) ?
                                Color(musicService.currentPlayerSkin.screenTextColor) :
                                Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.3),
                                lineWidth: 1
                            )
                    )
            }
        }
        .fontWeight(.bold)
        .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
        // 🔑 监听数据源切换，确保信息更新
        .onChange(of: musicService.currentDataSource) { _, newDataSource in
            // 数据源切换时，TrackInfoHeader会自动重新渲染
            // 因为它依赖的musicService.currentTrackIndex和musicService.totalTracksInQueue会更新
        }
    }
}

// MARK: - 重复和随机播放视图 (进一步提取)

struct RepeatAndShuffleView: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var repeatMode: MusicPlayer.RepeatMode
    @Binding var isShuffled: MusicPlayer.ShuffleMode
    @Binding var showLibraryView: Bool
    
    @State private var repeatTapped = false
    @State private var shuffleTapped = false
    
    // 🔑 新增：Subsonic 播放模式状态
    @State private var subsonicModes: (shuffle: Bool, repeat: SubsonicMusicService.SubsonicRepeatMode) = (false, .none)
    
    var isShuffleEnabled: Bool {
        switch musicService.currentDataSource {
        case .musicKit:
            return isShuffled != .off
        case .subsonic:
            return subsonicModes.shuffle
        }
    }
    
    var currentRepeatMode: SubsonicMusicService.SubsonicRepeatMode {
        switch musicService.currentDataSource {
        case .musicKit:
            switch repeatMode {
            case .none: return .none
            case .all: return .all
            case .one: return .one
            @unknown default: return .none
            }
        case .subsonic:
            return subsonicModes.repeat
        }
    }
    
    var body: some View {
        HStack {
            Button {
                repeatTapped.toggle()
                if musicService.isHapticFeedbackEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                    impactFeedback.impactOccurred()
                }
                
                // 🔑 根据数据源处理重复播放
                switch musicService.currentDataSource {
                case .musicKit:
                    switch repeatMode {
                    case .none: repeatMode = .all
                    case .all: repeatMode = .one
                    case .one: repeatMode = .none
                    @unknown default: repeatMode = .none
                    }
                    musicService.repeatMode = repeatMode
                    
                case .subsonic:
                    let currentMode = subsonicModes.repeat
                    let newMode: SubsonicMusicService.SubsonicRepeatMode
                    switch currentMode {
                    case .none: newMode = .all
                    case .all: newMode = .one
                    case .one: newMode = .none
                    }
                    musicService.getSubsonicService().setRepeatMode(newMode)
                    updateSubsonicModes()
                }
            } label: {
                Group {
                    if currentRepeatMode == .one {
                        Image(systemName: "repeat.1")
                    } else {
                        Image(systemName: "repeat")
                    }
                }
                .font(.system(size: 18))
                .foregroundColor(
                    currentRepeatMode == .none ?
                    Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.3) :
                    Color(musicService.currentPlayerSkin.screenTextColor)
                )
                .padding(4)
            }
            
            Spacer()
            
            SongTitleView(showLibraryView: $showLibraryView)
            
            Spacer()
            
            Button {
                shuffleTapped.toggle()
                if musicService.isHapticFeedbackEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                    impactFeedback.impactOccurred()
                }
                
                // 🔑 根据数据源处理随机播放
                switch musicService.currentDataSource {
                case .musicKit:
                    musicService.shuffleMode = isShuffleEnabled ? .off : .songs
                    isShuffled = musicService.shuffleMode
                    
                case .subsonic:
                    let newShuffleState = !subsonicModes.shuffle
                    musicService.getSubsonicService().setShuffleEnabled(newShuffleState)
                    updateSubsonicModes()
                }
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18))
                    .foregroundColor(
                        isShuffleEnabled ?
                        Color(musicService.currentPlayerSkin.screenTextColor) :
                        Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.3)
                    )
                    .padding(4)
            }
        }
        .onAppear {
            updateSubsonicModes()
        }
        .onChange(of: musicService.currentDataSource) { _, _ in
            updateSubsonicModes()
        }
    }
    
    // 🔑 新增：更新 Subsonic 播放模式状态
    private func updateSubsonicModes() {
        if musicService.currentDataSource == .subsonic {
            subsonicModes = musicService.getSubsonicService().getPlaybackModes()
        }
    }
}

// MARK: - 歌曲标题视图 (进一步提取)

struct SongTitleView: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var showLibraryView: Bool
    
    var body: some View {
        Button {
            if musicService.isHapticFeedbackEnabled {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            SoundManager.shared.playSound(.eject)
            showLibraryView = true
        } label: {
            VStack {
                Text(musicService.currentTitle)
                    .font(.body)
                    .fontWeight(.bold)
                    .lineLimit(1)
                Text(musicService.currentArtist)
                    .font(.callout)
                    .lineLimit(1)
            }
            .frame(height: 35.0)
            .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
        }
        // 🔑 监听数据源切换，确保歌曲信息更新
        .onChange(of: musicService.currentDataSource) { _, _ in
            // SongTitleView会自动更新，因为它绑定了musicService的属性
        }
    }
}

// MARK: - 播放进度视图 (进一步提取)

struct PlaybackProgressView: View {
    @EnvironmentObject private var musicService: MusicService
    let progress: CGFloat
    
    // 确保进度值在有效范围内
    private var clampedProgress: CGFloat {
        return min(max(progress, 0.0), 1.0)
    }
    
    private func formatRemainingTime(_ time: TimeInterval) -> String {
        guard time > 0 else { return "-00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "-" + String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack {
            Text(musicService.formatTime(musicService.currentDuration))
                .font(.caption.monospacedDigit())
                .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
            
            ProgressView(value: clampedProgress)
                .progressViewStyle(
                    CustomProgressViewStyle(
                        tint: Color(musicService.currentPlayerSkin.screenTextColor),
                        background: Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.1)
                    )
                )
            
            Text(formatRemainingTime(musicService.totalDuration - musicService.currentDuration))
                .font(.caption.monospacedDigit())
                .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
        }
    }
}

// 新增ControlButton视图来简化按钮样式
struct ControlButton: View {
    @EnvironmentObject private var musicService: MusicService
    let systemName: String
    let action: () -> Void
    let longPressAction: (() -> Void)?
    let longPressEndAction: (() -> Void)?
    
    @State private var isPressed = false
    
    init(systemName: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.action = action
        self.longPressAction = nil
        self.longPressEndAction = nil
    }
    
    init(systemName: String, action: @escaping () -> Void, longPressAction: @escaping () -> Void, longPressEndAction: @escaping () -> Void) {
        self.systemName = systemName
        self.action = action
        self.longPressAction = longPressAction
        self.longPressEndAction = longPressEndAction
    }
    
    var body: some View {
        Group {
            if longPressAction != nil {
                // 对于需要长按的按钮，使用支持外部按压状态的样式
                Button(action: {}) {
                    Image(systemName: systemName)
                        .font(.title3)
                        .foregroundColor(Color(musicService.currentPlayerSkin.buttonTextColor))
                }
                .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: isPressed))
                .disabled(true)
                .allowsHitTesting(false)
                .overlay(
                    // 在Button上叠加一个透明的手势接收区域
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle()) // 确保整个区域都能接收手势
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isPressed = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isPressed = false
                                }
                            }
                            action()
                        }
                        .onLongPressGesture(
                            minimumDuration: 0.8,
                            maximumDistance: 30,
                            perform: {
                                longPressAction?()
                            },
                            onPressingChanged: { pressing in
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isPressed = pressing
                                }
                                if !pressing {
                                    longPressEndAction?()
                                }
                            }
                        )
                )
            } else {
                // 普通按钮使用支持外部按压状态的样式，但externalIsPressed设为false
                Button(action: action) {
                    Image(systemName: systemName)
                        .font(.title3)
                        .foregroundColor(Color(musicService.currentPlayerSkin.buttonTextColor))
                }
                .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
            }
        }
    }
}

// 改为简单自定义视图
struct CassetteHole: View {
    var isRotating: Bool
    @Binding var rotationAngle: Double
    @EnvironmentObject private var musicService: MusicService
    
    var shouldGrow: Bool
    
    @State private var circleSize: CGFloat = 150
    @State private var animationStarted = false
    @State private var currentRotationAngle: Double = 0
    
    // 新增：用于检测歌曲切换
    @State private var lastTrackID: String? = nil
    @State private var isTrackChanging = false
    
    // 使用播放队列的总时长
    private var queueTotalDuration: TimeInterval {
        let duration = musicService.queueTotalDuration > 0 ? musicService.queueTotalDuration : 180.0
        return duration
    }
    
    // 计算当前播放进度对应的Circle尺寸
    private var currentProgressSize: CGFloat {
        guard queueTotalDuration > 0 else { return shouldGrow ? 100 : 200 }
        
        // 🔑 切歌时保持当前尺寸，避免突然跳变
        if isTrackChanging {
            return circleSize
        }
        
        // 使用队列累计播放时长计算整体进度
        let progress = musicService.queueElapsedDuration / queueTotalDuration
        let clampedProgress = min(max(progress, 0.0), 1.0) // 确保进度在0-1之间
        
        if shouldGrow {
            // 从200变到100
            return 200 - CGFloat(clampedProgress) * 100
        } else {
            // 从100变到200
            return 100 + CGFloat(clampedProgress) * 100
        }
    }
    
    // 计算当前旋转状态
    private var rotationState: String {
        if musicService.isFastForwarding {
            return "快进"
        } else if musicService.isFastRewinding {
            return "快退"
        } else if musicService.isPlaying {
            return "播放"
        } else {
            return "暂停"
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(musicService.currentCassetteSkin.cassetteColor))
                .frame(width: circleSize, height: circleSize)
            Image(musicService.currentCassetteSkin.cassetteHole)
                .resizable()
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(currentRotationAngle))
        }
        .frame(width: 200, height: 200)
        .onChange(of: rotationAngle) { _, newValue in
            // 根据当前状态决定是否更新旋转角度
            if musicService.isPlaying || musicService.isFastForwarding || musicService.isFastRewinding {
                // 直接使用原始角度，不进行标准化
                currentRotationAngle = newValue
            }
        }
        .onChange(of: isRotating) { _, newValue in
            if newValue && !animationStarted {
                startSizeAnimation()
            }
        }
        .onChange(of: musicService.queueTotalDuration) { oldValue, newValue in
            if oldValue != newValue && isRotating {
                animationStarted = false
                startSizeAnimation()
            }
        }
        // 🔑 监听歌曲切换
        .onChange(of: musicService.currentTrackID?.rawValue) { _, newTrackID in
            handleTrackChange(newTrackID: newTrackID)
        }
        // 监听队列累计播放时长变化
        .onChange(of: musicService.queueElapsedDuration) { oldValue, newValue in
            // 🔑 如果正在切歌，暂时忽略这个变化
            guard !isTrackChanging else { return }
            
            // 只有当变化超过阈值时才更新
            guard abs(oldValue - newValue) > 1.0 else { return }
            
            let newSize = currentProgressSize
            
            withAnimation(.easeInOut(duration: 0.3)) {
                circleSize = newSize
            }
        }
        .onChange(of: musicService.isFastForwarding) { oldValue, newValue in
            if oldValue != newValue && oldValue && !newValue {
                let newSize = currentProgressSize
                withAnimation(.easeInOut(duration: 0.5)) {
                    circleSize = newSize
                }
            }
        }
        .onChange(of: musicService.isFastRewinding) { oldValue, newValue in
            if oldValue != newValue && oldValue && !newValue {
                let newSize = currentProgressSize
                withAnimation(.easeInOut(duration: 0.5)) {
                    circleSize = newSize
                }
            }
        }
        // 添加对数据源切换的响应
        .onChange(of: musicService.currentDataSource) { _, newDataSource in
            // 当数据源切换时，重新设置磁带孔尺寸和动画状态
            setupInitialSize()
            animationStarted = false
            if isRotating && musicService.isPlaying {
                startSizeAnimation()
            }
        }
        .onAppear {
            setupInitialSize()
            currentRotationAngle = rotationAngle
            lastTrackID = musicService.currentTrackID?.rawValue
            if isRotating && musicService.isPlaying && !animationStarted {
                startSizeAnimation()
            }
        }
    }
    
    // 🔑 新增：处理歌曲切换
    private func handleTrackChange(newTrackID: String?) {
        let hasTrackChanged = newTrackID != lastTrackID && lastTrackID != nil
        
        if hasTrackChanged {
            // 标记正在切歌
            isTrackChanging = true
            
            // 短暂延迟后重新计算尺寸，给MusicService时间更新数据
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                isTrackChanging = false
                
                // 重新设置尺寸和动画
                setupInitialSize()
                animationStarted = false
                
                if isRotating && musicService.isPlaying {
                    startSizeAnimation()
                }
            }
        }
        
        lastTrackID = newTrackID
    }
    
    // 设置初始尺寸的方法
    private func setupInitialSize() {
        // 使用当前播放进度来设置初始尺寸
        circleSize = currentProgressSize
        animationStarted = false
    }
    
    // 修正尺寸动画逻辑
    private func startSizeAnimation() {
        guard !animationStarted else {
            return
        }
        
        animationStarted = true
        
        // 从当前队列进度对应的尺寸开始，动画到最终尺寸
        let startSize = currentProgressSize
        let endSize: CGFloat = shouldGrow ? 200 : 100
        let remainingDuration = queueTotalDuration - musicService.queueElapsedDuration
        
        circleSize = startSize
        
        // 确保剩余时长为正数，避免负数或零值导致的问题
        if remainingDuration > 0 {
            withAnimation(.linear(duration: remainingDuration)) {
                circleSize = endSize
            }
        } else {
            // 如果没有剩余时长，直接设置为结束尺寸
            circleSize = endSize
        }
    }
}

//#Preview {
//    let musicService = MusicService.shared
//    
//    return PlayerView()
//        .environmentObject(musicService)
//}
//
//#Preview("正在播放") {
//    let musicService = MusicService.shared
//    
//    // 简单的静态预览视图，显示磁带和磁带孔
//    ZStack {
//        GeometryReader { geometry in
//            // 背景
//            Image(musicService.currentPlayerSkin.cassetteBgImage)
//                .resizable()
//                .aspectRatio(contentMode: .fill)
//                .frame(width: geometry.size.width, height: geometry.size.height)
//                .clipped()
//                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
//            
//            // 磁带孔区域
//            ZStack {
//                VStack(spacing: 15) {
//                    // 上磁带孔
//                    ZStack {
//                        Circle()
//                            .fill(Color(musicService.currentCassetteSkin.cassetteColor))
//                            .frame(width: 110, height: 110)
//                        Image(musicService.currentCassetteSkin.cassetteHole)
//                            .resizable()
//                            .frame(width: 70, height: 70)
//                    }
//                    .frame(width: 200, height: 200)
//                    
//                    // 下磁带孔
//                    ZStack {
//                        Circle()
//                            .fill(Color(musicService.currentCassetteSkin.cassetteColor))
//                            .frame(width: 200, height: 200)
//                        Image(musicService.currentCassetteSkin.cassetteHole)
//                            .resizable()
//                            .frame(width: 70, height: 70)
//                    }
//                    .frame(width: 200, height: 200)
//                }
//                .padding(.leading, 25.0)
//                
//                // 磁带图片
//                Image(musicService.currentCassetteSkin.cassetteImage)
//                    .resizable()
//                    .aspectRatio(contentMode: .fill)
//                    .frame(width: 400, height:400)
//                    
//            }
//            .padding(.bottom, 270.0)
//            .padding(.leading, 25.0)
//            .frame(width: geometry.size.width, height: geometry.size.height)
//            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
//
//            // 播放器面板
//            Image("player-CF-504")
//                .resizable()
//                .aspectRatio(contentMode: .fill)
//                .frame(width: geometry.size.width, height: geometry.size.height)
//                .clipped()
//                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
//
//        }
//        .edgesIgnoringSafeArea(.all)
//        
//        VStack {
//            Spacer()
//            
//            // 控制面板
//            VStack(spacing: 0) {
//                let baseButtonHeight = musicService.currentPlayerSkin.buttonHeight
//                let buttonHeight = UIScreen.isCompactDevice ? baseButtonHeight - 10 : baseButtonHeight
//                
//                HStack(spacing: 5) {
//                    // 磁带按钮
//                    Button(action: {}) {
//                        Image(systemName: "recordingtape")
//                            .font(.title3)
//                            .foregroundColor(Color(musicService.currentPlayerSkin.buttonTextColor))
//                    }
//                    .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
//                    
//                    // 上一首按钮
//                    Button(action: {}) {
//                        Image(systemName: "backward.fill")
//                            .font(.title3)
//                            .foregroundColor(Color(musicService.currentPlayerSkin.buttonTextColor))
//                    }
//                    .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
//                    
//                    // 播放按钮
//                    Button(action: {}) {
//                        Image(systemName: "play.fill")
//                            .font(.title3)
//                            .foregroundColor(Color(musicService.currentPlayerSkin.buttonTextColor))
//                    }
//                    .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
//                    
//                    // 下一首按钮
//                    Button(action: {}) {
//                        Image(systemName: "forward.fill")
//                            .font(.title3)
//                            .foregroundColor(Color(musicService.currentPlayerSkin.buttonTextColor))
//                    }
//                    .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
//                    
//                    // 设置按钮
//                    Button(action: {}) {
//                        Image(systemName: "gearshape")
//                            .font(.title3)
//                            .foregroundColor(Color(musicService.currentPlayerSkin.buttonTextColor))
//                    }
//                    .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
//                }
//                .frame(height: buttonHeight)
//                .padding(.horizontal, 10.0)
//                .padding(.vertical, 5.0)
//                
//                VStack(spacing: UIScreen.isCompactDevice ? 8 : 5) {
//                    if !UIScreen.isCompactDevice {
//                        Group {
//                            if let index = musicService.currentTrackIndex, musicService.totalTracksInQueue > 0 {
//                                Button {
//                                    showQueueView = true
//                                    if musicService.isHapticFeedbackEnabled {
//                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
//                                        impactFeedback.impactOccurred()
//                                    }
//                                } label: {
//                                    Text("PGM NO. \(index)/\(musicService.totalTracksInQueue)")
//                                        .foregroundColor(.primary)
//                                }
//                            } else {
//                                Text("PGM NO. 0/0")
//                                    .foregroundColor(.secondary)
//                            }
//                        }
//                        
//                        Spacer()
//                        
//                        Text("SOUND EFFECT")
//                            .font(.caption)
//                            .padding(4)
//                            .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 4)
//                                    .strokeBorder(Color(musicService.currentPlayerSkin.screenTextColor), lineWidth: 1)
//                            )
//                    }
//                    
//                    // 播放控制和歌曲信息
//                    HStack {
//                        Image(systemName: "repeat")
//                            .font(.system(size: 18))
//                            .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.3))
//                            .padding(4)
//                        
//                        Spacer()
//                        
//                        VStack {
//                            Text("Love Story")
//                                .font(.body)
//                                .fontWeight(.bold)
//                                .lineLimit(1)
//                            Text("Taylor Swift")
//                                .font(.callout)
//                                .lineLimit(1)
//                        }
//                        .frame(height: 35.0)
//                        .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
//                        
//                        Spacer()
//                        
//                        Image(systemName: "shuffle")
//                            .font(.system(size: 18))
//                            .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.3))
//                            .padding(4)
//                    }
//                    
//                    // 进度条
//                    HStack {
//                        Text("02:00")
//                            .font(.caption.monospacedDigit())
//                            .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
//                        
//                        ProgressView(value: 0.5)
//                            .progressViewStyle(
//                                CustomProgressViewStyle(
//                                    tint: Color(musicService.currentPlayerSkin.screenTextColor),
//                                    background: Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.1)
//                                )
//                            )
//                        
//                        Text("-01:55")
//                            .font(.caption.monospacedDigit())
//                            .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
//                    }
//                }
//                .frame(height: UIScreen.isCompactDevice ? 55.0 : 80.0)
//                .padding()
//                .background(
//                    RoundedRectangle(cornerRadius: 8)
//                        .fill(Color(musicService.currentPlayerSkin.screenColor))
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 8)
//                                .strokeBorder(Color(musicService.currentPlayerSkin.screenOutlineColor), lineWidth: 4)
//                        )
//                )
//                .padding(10)
//            }
//            .background(
//                RoundedRectangle(cornerRadius: 16)
//                    .fill(Color(musicService.currentPlayerSkin.panelColor))
//            )
//            .overlay(
//                RoundedRectangle(cornerRadius: 16)
//                    .strokeBorder(Color(musicService.currentPlayerSkin.panelOutlineColor), lineWidth: 2)
//            )
//            .padding()
//        }
//    }
//    .environmentObject(musicService)
//}
