import SwiftUI
import MusicKit
import Foundation

// MARK: - 设备适配扩展
extension UIScreen {
    /// 检测是否为小屏设备（iPhone SE系列等）
    static var isCompactDevice: Bool {
        // iPhone SE系列和其他小屏设备的屏幕高度通常在667以下
        // iPhone SE (1st gen): 568pt
        // iPhone SE (2nd & 3rd gen): 667pt
        return UIScreen.main.bounds.height <= 667
    }
}

struct PlayerView: View {
    @EnvironmentObject private var musicService: MusicService
    @State private var showLibraryView = false
    @State private var showSettingsView = false
    @State private var showStoreView = false
    @State private var repeatMode: MusicPlayer.RepeatMode = .none
    @State private var isShuffled: MusicPlayer.ShuffleMode = .off
    @State private var rotationAngle: Double = 0
    @State private var rotationTimer: Timer?
    @State private var isRotating = false
    
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
                    progress: progress,
                    repeatMode: $repeatMode,
                    isShuffled: $isShuffled
                )
            }
        }
        .onAppear {
            if musicService.isPlaying {
                startRotation()
            }
        }
        .onChange(of: musicService.isPlaying) { _, isPlaying in
            if isPlaying {
                startRotation()
            } else {
                stopRotation()
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
        .onDisappear { stopRotation() }
        .sheet(isPresented: $showLibraryView) { LibraryView() }
        .sheet(isPresented: $showSettingsView) { SettingsView() }
        .sheet(isPresented: $showStoreView) { StoreView() }
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

}

// MARK: - 背景视图 (提取出来)

struct PlayerBackgroundView: View {
    @EnvironmentObject private var musicService: MusicService
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
                        .padding(.bottom, 280.0)
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
                    showLibraryView = true
                }) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.55)
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.35)
                
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
            VStack(spacing: 110) {
                CassetteHole(isRotating: musicService.isPlaying, rotationAngle: $rotationAngle, shouldGrow: true)
                CassetteHole(isRotating: musicService.isPlaying, rotationAngle: $rotationAngle, shouldGrow: false)
            }
            .padding(.leading, 25.0)
            
            Image(musicService.currentCassetteSkin.cassetteImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

// MARK: - 控制器视图 (提取出来)

struct PlayerControlsView: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var showLibraryView: Bool
    @Binding var showSettingsView: Bool
    @Binding var showStoreView: Bool
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
//                showSettingsView: $showSettingsView,
                showLibraryView: $showLibraryView,
                repeatMode: $repeatMode,
                isShuffled: $isShuffled,
                progress: progress
            )
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(musicService.currentPlayerSkin.screenColor))
                    
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
                libraryTapped.toggle()
                if musicService.isHapticFeedbackEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
                showStoreView = true
            })
            
            ControlButton(
                systemName: "backward.fill",
                action: {
                    previousTapped.toggle()
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
                    playPauseTapped.toggle()
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
                    nextTapped.toggle()
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
                storeTapped.toggle()
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
//    @Binding var showSettingsView: Bool
    @Binding var showLibraryView: Bool
    @Binding var repeatMode: MusicPlayer.RepeatMode
    @Binding var isShuffled: MusicPlayer.ShuffleMode
    let progress: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: UIScreen.isCompactDevice ? 8 : 5) {
                // 根据屏幕尺寸判断是否显示TrackInfoHeader
                if !UIScreen.isCompactDevice {
                    TrackInfoHeader()
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
//    @Binding var showSettingsView: Bool
    
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
                musicService.setCassetteEffect(enabled: !musicService.isCassetteEffectEnabled)
            } label: {
                Text("SOUND EFFECT")
                    .font(.caption)
                    .padding(4)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(
                        musicService.isCassetteEffectEnabled ?
                        Color(musicService.currentPlayerSkin.screenTextColor) :
                        Color(musicService.currentPlayerSkin.screenTextColor).opacity(0.3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                musicService.isCassetteEffectEnabled ?
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
                            print("短按: \(systemName)")
                            // 模拟按压动画
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
                                print("长按开始: \(systemName)")
                                longPressAction?()
                            },
                            onPressingChanged: { pressing in
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isPressed = pressing
                                }
                                if !pressing {
                                    print("松开按钮: \(systemName)")
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
        
        print("播放进度计算 - shouldGrow: \(shouldGrow), 累计时长: \(musicService.queueElapsedDuration)秒, 总时长: \(queueTotalDuration)秒, 进度: \(clampedProgress)")
        
        if shouldGrow {
            // 从100变到200
            return 100 + CGFloat(clampedProgress) * 100
        } else {
            // 从200变到100
            return 200 - CGFloat(clampedProgress) * 100
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
                .fill(Color.clear)
                .frame(width: 160, height: 160)
            Circle()
                .fill(Color(musicService.currentCassetteSkin.cassetteColor))
                .frame(width: circleSize, height: circleSize)
            Image(musicService.currentCassetteSkin.cassetteHole)
                .resizable()
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(currentRotationAngle))
        }
        .frame(width: 100, height: 100)
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
            print("isRotating变化: -> \(newValue)")
            if newValue && !animationStarted {
                startSizeAnimation()
            }
        }
        .onChange(of: musicService.queueTotalDuration) { oldValue, newValue in
            // 只有当值真正变化时才输出日志
            if oldValue != newValue {
                print("queueTotalDuration变化: \(oldValue) -> \(newValue)")
                if isRotating {
                    animationStarted = false
                    startSizeAnimation()
                }
            }
        }
        // 监听队列累计播放时长变化
        .onChange(of: musicService.queueElapsedDuration) { oldValue, newValue in
            // 只有当变化超过阈值时才更新和输出日志
            guard abs(oldValue - newValue) > 0.5 else { return }
            
            let newSize = currentProgressSize
            print("队列播放时间变化 - shouldGrow: \(shouldGrow), 状态: \(rotationState), 新尺寸: \(newSize)")
            
            withAnimation(.easeInOut(duration: 0.3)) {
                circleSize = newSize
            }
        }
        .onChange(of: musicService.isFastForwarding) { oldValue, newValue in
            // 只有当状态真正变化时才输出日志
            if oldValue != newValue {
                print("快进状态变化: \(oldValue) -> \(newValue), shouldGrow: \(shouldGrow)")
                if oldValue && !newValue {
                    // 快进结束，立即更新到当前进度对应的尺寸
                    let newSize = currentProgressSize
                    print("快进结束，更新尺寸: \(newSize)")
                    withAnimation(.easeInOut(duration: 0.5)) {
                        circleSize = newSize
                    }
                }
            }
        }
        .onChange(of: musicService.isFastRewinding) { oldValue, newValue in
            // 只有当状态真正变化时才输出日志
            if oldValue != newValue {
                print("快退状态变化: \(oldValue) -> \(newValue), shouldGrow: \(shouldGrow)")
                if oldValue && !newValue {
                    // 快退结束，立即更新到当前进度对应的尺寸
                    let newSize = currentProgressSize
                    print("快退结束，更新尺寸: \(newSize)")
                    withAnimation(.easeInOut(duration: 0.5)) {
                        circleSize = newSize
                    }
                }
            }
        }
        .onAppear {
            print("CassetteHole onAppear - shouldGrow: \(shouldGrow), isRotating: \(isRotating), isPlaying: \(musicService.isPlaying)")
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
        
        print("动画参数 - 起始尺寸: \(startSize), 结束尺寸: \(endSize), 剩余时长: \(remainingDuration)秒")
        
        circleSize = startSize
        
        if remainingDuration > 0 {
            withAnimation(.linear(duration: remainingDuration)) {
                circleSize = endSize
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("动画开始2秒后 - shouldGrow: \(self.shouldGrow), 当前尺寸: \(self.circleSize)")
        }
    }
}

#Preview {
    let musicService = MusicService.shared
    
    return PlayerView()
        .environmentObject(musicService)
}
