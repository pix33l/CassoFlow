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
            if isPlaying {
                startRotation()
                startPlaybackTracking()
            } else {
                stopRotation()
                stopPlaybackTracking()
            }
        }
        .onChange(of: musicService.isFastForwarding) { _, newValue in
            if musicService.isPlaying || newValue {
                startRotation()
            }
        }
        .onChange(of: musicService.isFastRewinding) { _, newValue in
            if musicService.isPlaying || newValue {
                startRotation()
            }
        }
        .onChange(of: storeManager.membershipStatus.isActive) { _, isActive in
            if isActive {
                // 用户升级为会员，重置播放时间限制
                resetPlaybackTimer()
                print("🎵 用户已升级为会员，移除播放时间限制")
            }
        }
        .onChange(of: musicService.currentPlayerSkin.name) { _, skinName in
            if skinName != "CF-DEMO" {
                // 用户切换到非默认皮肤，重置播放时间限制
                resetPlaybackTimer()
                print("🎵 用户切换到非默认皮肤(\(skinName))，移除播放时间限制")
            }
        }
        .onDisappear {
            stopRotation()
            stopPlaybackTracking()
        }
        .sheet(isPresented: $showLibraryView) { LibraryView() }
        .sheet(isPresented: $showSettingsView) { SettingsView() }
        .sheet(isPresented: $showStoreView) { StoreView() }
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
    }
    
    private func startRotation() {
        stopRotation()
        isRotating = true
        
        let (interval, angleIncrement) = getRotationParameters()
        
        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation(.linear(duration: interval)) {
                self.rotationAngle += angleIncrement
            }
        }
    }
    
    private func getRotationParameters() -> (TimeInterval, Double) {
        if musicService.isFastForwarding {
            return (0.01, 8.0) // 提高频率，减少每次角度增量
        } else if musicService.isFastRewinding {
            return (0.01, -8.0) // 提高频率，减少每次角度增量
        } else if musicService.isPlaying {
            return (0.03, 3.0) // 正常播放也稍微提高频率
        } else {
            return (0.03, 3.0)
        }
    }
    
    private func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        isRotating = false
    }
    
    // MARK: - ADD: 播放时间追踪方法
    
    /// 开始追踪播放时间（仅针对非会员用户）
    private func startPlaybackTracking() {
        guard !storeManager.membershipStatus.isActive && musicService.currentPlayerSkin.name == "CF-DEMO" else {
            if storeManager.membershipStatus.isActive {
                print("用户是会员，跳过播放时间限制")
            } else {
                print("用户使用非默认皮肤(\(musicService.currentPlayerSkin.name))，跳过播放时间限制")
            }
            return
        }
        
        // 停止现有的计时器
        stopPlaybackTracking()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            accumulatedPlaybackTime += 1.0
            
            // 每30秒输出一次日志，避免过多输出
            if Int(accumulatedPlaybackTime) % 30 == 0 {
                // 更新日志显示为10分钟限制
                let remainingTime = 300 - accumulatedPlaybackTime
                print("非会员播放时间: \(accumulatedPlaybackTime)秒, 剩余: \(remainingTime)秒")
            }
            
            // 检查是否达到10分钟限制（600秒）
            if accumulatedPlaybackTime >= 300 {
                showPlaybackLimitReached()
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
        guard !storeManager.membershipStatus.isActive && musicService.currentPlayerSkin.name == "CF-DEMO" else {
            if storeManager.membershipStatus.isActive {
                print("🎵 检测到用户是会员，取消限制弹窗")
            } else {
                print("🎵 检测到用户使用非默认皮肤，取消限制弹窗")
            }
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
            
            // 如果音乐正在播放，重新开始追踪
            if musicService.isPlaying {
                startPlaybackTracking()
            }
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
    }
}

// MARK: - 控制器视图 (提取出来)

struct PlayerControlsView: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var showLibraryView: Bool
    @Binding var showSettingsView: Bool
    @Binding var showStoreView: Bool
    @Binding var showPaywallForLimit: Bool
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
    @Binding var repeatMode: MusicPlayer.RepeatMode
    @Binding var isShuffled: MusicPlayer.ShuffleMode
    let progress: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: UIScreen.isCompactDevice ? 8 : 5) {
                // 根据屏幕尺寸判断是否显示TrackInfoHeader
                if !UIScreen.isCompactDevice {
                    TrackInfoHeader(showPaywallForLimit: $showPaywallForLimit)
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

    @State private var settingsTapped = false
    
    var body: some View {
        HStack {
            Group {
                if let index = musicService.currentTrackIndex, musicService.totalTracksInQueue > 0 {
                    Text("PGM NO. \(index)/\(musicService.totalTracksInQueue)")
                } else {
                    Text("PGM NO. 0/0")
                }
            }
            .padding(.leading, 4)
            
            Spacer()
            
            Button {
                settingsTapped.toggle()
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
    
    var isShuffleEnabled: Bool {
        return isShuffled != .off
    }
    
    var body: some View {
        HStack {
            Button {
                repeatTapped.toggle()
                if musicService.isHapticFeedbackEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                    impactFeedback.impactOccurred()
                }
                switch repeatMode {
                case .none: repeatMode = .all
                case .all: repeatMode = .one
                case .one: repeatMode = .none
                @unknown default: repeatMode = .none
                }
                musicService.repeatMode = repeatMode
            } label: {
                Group {
                    if repeatMode == .one {
                        Image(systemName: "repeat.1")
                    } else {
                        Image(systemName: "repeat")
                    }
                }
                .font(.system(size: 18))
                .foregroundColor(
                    repeatMode == .none ?
                    Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.3) :
                    Color(musicService.currentPlayerSkin.screenTextColor)
                )
                .padding(4)
                /*
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.1)))
                 */
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
                musicService.shuffleMode = isShuffleEnabled ? .off : .songs
                isShuffled = musicService.shuffleMode
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18))
                    .foregroundColor(
                        isShuffleEnabled ?
                        Color(musicService.currentPlayerSkin.screenTextColor) :
                        Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.3)
                    )
                    .padding(4)
                    /*
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.1)))
                     */
            }
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
                            minimumDuration: 0.5,
                            maximumDistance: 50,
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
    
    // 使用播放队列的总时长
    private var queueTotalDuration: TimeInterval {
        let duration = musicService.queueTotalDuration > 0 ? musicService.queueTotalDuration : 180.0
        print("CassetteHole - shouldGrow: \(shouldGrow), queueTotalDuration: \(duration)秒")
        return duration
    }
    
    // 计算当前播放进度对应的Circle尺寸
    private var currentProgressSize: CGFloat {
        guard queueTotalDuration > 0 else { return shouldGrow ? 100 : 200 }
        
        // 使用队列累计播放时长计算整体进度
        let progress = musicService.queueElapsedDuration / queueTotalDuration
        let clampedProgress = min(max(progress, 0.0), 1.0) // 确保进度在0-1之间
        
        print("播放进度计算 - shouldGrow: \(shouldGrow), 状态: \(rotationState), 累计时长: \(musicService.queueElapsedDuration)秒, 总时长: \(queueTotalDuration)秒, 进度: \(clampedProgress)")
        
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
                
                // 大幅减少日志输出频率 - 每3600度（20圈）输出一次
                if Int(newValue) % 3600 == 0 {
                    print("旋转角度更新 - shouldGrow: \(shouldGrow), 状态: \(rotationState), 完整角度: \(newValue)")
                }
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
        // 监听队列累计播放时长变化
        .onChange(of: musicService.queueElapsedDuration) { oldValue, newValue in
            // 只有当变化超过阈值时才更新和输出日志
            guard abs(oldValue - newValue) > 0.5 else { return }
            
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
        .onAppear {
            setupInitialSize()
            currentRotationAngle = rotationAngle
            if isRotating && musicService.isPlaying && !animationStarted {
                startSizeAnimation()
            }
        }
    }
    
    // 设置初始尺寸的方法
    private func setupInitialSize() {
        // 使用当前播放进度来设置初始尺寸
        circleSize = currentProgressSize
        animationStarted = false
        print("初始尺寸设置 - shouldGrow: \(shouldGrow), circleSize: \(circleSize)")
    }
    
    // 修正尺寸动画逻辑
    private func startSizeAnimation() {
        guard !animationStarted else {
            print("动画已经开始，跳过重复调用")
            return
        }
        
        animationStarted = true
        print("开始尺寸动画 - shouldGrow: \(shouldGrow), 当前尺寸: \(circleSize), 队列总时长: \(queueTotalDuration)秒")
        
        // 从当前队列进度对应的尺寸开始，动画到最终尺寸
        let startSize = currentProgressSize
        let endSize: CGFloat = shouldGrow ? 200 : 100
        let remainingDuration = queueTotalDuration - musicService.queueElapsedDuration
        
        circleSize = startSize
        
        if remainingDuration > 0 {
            withAnimation(.linear(duration: remainingDuration)) {
                circleSize = endSize
            }
        }
    }
}

#Preview {
    let musicService = MusicService.shared
    
    return PlayerView()
        .environmentObject(musicService)
}

#Preview("正在播放") {
    let musicService = MusicService.shared
    
    // 简单的静态预览视图，显示磁带和磁带孔
    ZStack {
        GeometryReader { geometry in
            // 背景
            Image(musicService.currentPlayerSkin.cassetteBgImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            // 磁带孔区域
            ZStack {
                VStack(spacing: 15) {
                    // 上磁带孔
                    ZStack {
                        Circle()
                            .fill(Color(musicService.currentCassetteSkin.cassetteColor))
                            .frame(width: 110, height: 110)
                        Image(musicService.currentCassetteSkin.cassetteHole)
                            .resizable()
                            .frame(width: 70, height: 70)
                    }
                    .frame(width: 200, height: 200)
                    
                    // 下磁带孔
                    ZStack {
                        Circle()
                            .fill(Color(musicService.currentCassetteSkin.cassetteColor))
                            .frame(width: 200, height: 200)
                        Image(musicService.currentCassetteSkin.cassetteHole)
                            .resizable()
                            .frame(width: 70, height: 70)
                    }
                    .frame(width: 200, height: 200)
                }
                .padding(.leading, 25.0)
                
                // 磁带图片
                Image(musicService.currentCassetteSkin.cassetteImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 400, height:400)
                    
            }
            .padding(.bottom, 270.0)
            .padding(.leading, 25.0)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

            // 播放器面板
            Image("player-CF-504")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

        }
        .edgesIgnoringSafeArea(.all)
        
        VStack {
            Spacer()
            
            // 控制面板
            VStack(spacing: 0) {
                let baseButtonHeight = musicService.currentPlayerSkin.buttonHeight
                let buttonHeight = UIScreen.isCompactDevice ? baseButtonHeight - 10 : baseButtonHeight
                
                HStack(spacing: 5) {
                    // 磁带按钮
                    Button(action: {}) {
                        Image(systemName: "recordingtape")
                            .font(.title3)
                            .foregroundColor(Color(musicService.currentPlayerSkin.buttonTextColor))
                    }
                    .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
                    
                    // 上一首按钮
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                            .font(.title3)
                            .foregroundColor(Color(musicService.currentPlayerSkin.buttonTextColor))
                    }
                    .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
                    
                    // 播放按钮
                    Button(action: {}) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundColor(Color(musicService.currentPlayerSkin.buttonTextColor))
                    }
                    .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
                    
                    // 下一首按钮
                    Button(action: {}) {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundColor(Color(musicService.currentPlayerSkin.buttonTextColor))
                    }
                    .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
                    
                    // 设置按钮
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(Color(musicService.currentPlayerSkin.buttonTextColor))
                    }
                    .buttonStyle(ThreeDButtonStyleWithExternalPress(externalIsPressed: false))
                }
                .frame(height: buttonHeight)
                .padding(.horizontal, 10.0)
                .padding(.vertical, 5.0)
                
                VStack(spacing: UIScreen.isCompactDevice ? 8 : 5) {
                    if !UIScreen.isCompactDevice {
                        HStack {
                            Text("PGM NO. 3/13")
                                .padding(.leading, 4)
                            
                            Spacer()
                            
                            Text("SOUND EFFECT")
                                .font(.caption)
                                .padding(4)
                                .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color(musicService.currentPlayerSkin.screenTextColor), lineWidth: 1)
                                )
                        }
                        .fontWeight(.bold)
                        .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
                    }
                    
                    // 播放控制和歌曲信息
                    HStack {
                        Image(systemName: "repeat")
                            .font(.system(size: 18))
                            .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.3))
                            .padding(4)
                        
                        Spacer()
                        
                        VStack {
                            Text("Love Story")
                                .font(.body)
                                .fontWeight(.bold)
                                .lineLimit(1)
                            Text("Taylor Swift")
                                .font(.callout)
                                .lineLimit(1)
                        }
                        .frame(height: 35.0)
                        .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
                        
                        Spacer()
                        
                        Image(systemName: "shuffle")
                            .font(.system(size: 18))
                            .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.3))
                            .padding(4)
                    }
                    
                    // 进度条
                    HStack {
                        Text("02:00")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
                        
                        ProgressView(value: 0.5)
                            .progressViewStyle(
                                CustomProgressViewStyle(
                                    tint: Color(musicService.currentPlayerSkin.screenTextColor),
                                    background: Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.1)
                                )
                            )
                        
                        Text("-01:55")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(Color(musicService.currentPlayerSkin.screenTextColor))
                    }
                }
                .frame(height: UIScreen.isCompactDevice ? 55.0 : 80.0)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(musicService.currentPlayerSkin.screenColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color(musicService.currentPlayerSkin.screenOutlineColor), lineWidth: 4)
                        )
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
    .environmentObject(musicService)
}
