import SwiftUI
import MusicKit
import Foundation

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
    
    // 格式化时间显示
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
            PlayerBackgroundView(rotationAngle: $rotationAngle)
            PlayerControlsView(
                showLibraryView: $showLibraryView,
                showSettingsView: $showSettingsView,
                showStoreView: $showStoreView,
                progress: progress,
                repeatMode: $repeatMode,
                isShuffled: $isShuffled
            )
        }
        .onAppear {
            if musicService.isPlaying {
                startRotation()
            }
        }
        .onChange(of: musicService.isPlaying) { isPlaying in
            if isPlaying {
                startRotation()
            } else {
                stopRotation()
            }
        }
        .onDisappear { stopRotation() }
        .sheet(isPresented: $showLibraryView) { LibraryView() }
        .sheet(isPresented: $showSettingsView) { SettingsView() }
        .sheet(isPresented: $showStoreView) { StoreView() }
    }
    
    // 开始旋转（优化后版本）
    private func startRotation() {
        stopRotation() // 先停止现有的计时器
        isRotating = true
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.rotationAngle += 5 // 增大每次旋转角度
        }
    }
    
    // 停止旋转
    private func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        isRotating = false
    }
    
    // 在可能需要更新皮肤的代码段
    private func applySkinUpdate() {
        // 确保使用基于名称的设置方法
        musicService.currentSkin = Skin.skin(named: "NEW_SKIN_NAME") ?? Skin.allSkins[0]
    }
}

// MARK: - 背景视图 (提取出来)

struct PlayerBackgroundView: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var rotationAngle: Double
    
    var body: some View {
        ZStack(alignment: .center) {
            Image("bg-cassette")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            
            if musicService.currentTrackID != nil {
                HolesView(rotationAngle: $rotationAngle)
                    .padding(.bottom, 280.0)
            }
            
            Image(musicService.currentSkin.playerImage)
                .resizable()
                .scaledToFill()
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
                CassetteHole(isRotating: true, rotationAngle: $rotationAngle)
                CassetteHole(isRotating: musicService.isPlaying, rotationAngle: $rotationAngle)
            }
            .padding(.leading, 25.0)
            
            Image(musicService.currentSkin.cassetteImage)
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
        VStack(spacing: 0) {
            ControlButtonsView(
                showLibraryView: $showLibraryView,
                showStoreView: $showStoreView
            )
            .padding([.top, .leading, .trailing], 10.0)
            
            SongInfoView(
                showSettingsView: $showSettingsView,
                repeatMode: $repeatMode,
                isShuffled: $isShuffled,
                progress: progress
            )
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(musicService.currentSkin.screenColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(musicService.currentSkin.screenOutlineColor), lineWidth: 2))
            )
            .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(musicService.currentSkin.screenOutlineColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(musicService.currentSkin.screenOutlineColor), lineWidth: 2)
        )
        .padding()
        .padding(.top, 550)
    }
}

// MARK: - 控制器按钮视图 (进一步提取)

struct ControlButtonsView: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var showLibraryView: Bool
    @Binding var showStoreView: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            // 媒体库按钮
            ControlButton(systemName: "music.note.list", action: { showLibraryView = true })
            
            // 上一首按钮
            ControlButton(systemName: "backward.fill") {
                Task { try await musicService.skipToPrevious() }
            }
            
            // 播放/暂停按钮
            ControlButton(
                systemName: musicService.isPlaying ? "pause.fill" : "play.fill",
                action: {
                    Task {
                        if musicService.isPlaying {
                            await musicService.pause()
                        } else {
                            try await musicService.play()
                        }
                    }
                }
            )
            
            // 下一首按钮
            ControlButton(systemName: "forward.fill") {
                Task { try await musicService.skipToNext() }
            }
            
            // 设置按钮
            ControlButton(systemName: "recordingtape") {
                showStoreView = true
            }
        }
    }
}

// MARK: - 歌曲信息视图 (进一步提取)

struct SongInfoView: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var showSettingsView: Bool
    @Binding var repeatMode: MusicPlayer.RepeatMode
    @Binding var isShuffled: MusicPlayer.ShuffleMode
    let progress: CGFloat
    
    var body: some View {
        VStack(spacing: 5) {
            TrackInfoHeader(showSettingsView: $showSettingsView)
            RepeatAndShuffleView(repeatMode: $repeatMode, isShuffled: $isShuffled)
            PlaybackProgressView(progress: progress)
        }
    }
}

// MARK: - 追踪信息头部 (进一步提取)

struct TrackInfoHeader: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var showSettingsView: Bool
    
    var body: some View {
        HStack {
            Group {
                if let index = musicService.currentTrackIndex, musicService.totalTracksInQueue > 0 {
                    Text("PGM NO. \(index)/\(musicService.totalTracksInQueue)")
                } else {
                    Text("PGM NO.")
                }
            }
            .padding(.leading, 4)
            
            Spacer()
            
            Button {
                showSettingsView = true
            } label: {
                Text("SETTINGS")
            }
            .foregroundColor(Color(musicService.currentSkin.screenTextColor))
        }
        .fontWeight(.bold)
        .foregroundColor(Color(musicService.currentSkin.screenTextColor))
    }
}

// MARK: - 重复和随机播放视图 (进一步提取)

struct RepeatAndShuffleView: View {
    @EnvironmentObject private var musicService: MusicService
    @Binding var repeatMode: MusicPlayer.RepeatMode
    @Binding var isShuffled: MusicPlayer.ShuffleMode
    
    // 创建计算属性以简化随机播放布尔状态检查
    var isShuffleEnabled: Bool {
        return isShuffled != .off
    }
    
    var body: some View {
        HStack {
            // 循环播放图标
            Button {
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
                    Color(musicService.currentSkin.screenTextColor).opacity(0.3) :
                    Color(musicService.currentSkin.screenTextColor)
                )
            }
            
            Spacer()
            
            SongTitleView()
            
            Spacer()
            
            // 修复随机播放图标（使用自定义Boolean处理）
            Button {
                musicService.shuffleMode = isShuffleEnabled ? .off : .songs
                isShuffled = musicService.shuffleMode
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18))
                    .foregroundColor(
                        isShuffleEnabled ?
                        Color(musicService.currentSkin.screenTextColor) :
                        Color(musicService.currentSkin.screenTextColor).opacity(0.3)
                    )
            }
        }
    }
}

// MARK: - 歌曲标题视图 (进一步提取)

struct SongTitleView: View {
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack {
            Text(musicService.currentTitle)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
            Text(musicService.currentArtist)
                .font(.body)
                .lineLimit(1)
        }
        .foregroundColor(Color(musicService.currentSkin.screenTextColor))
    }
}

// MARK: - 播放进度视图 (进一步提取)

struct PlaybackProgressView: View {
    @EnvironmentObject private var musicService: MusicService
    let progress: CGFloat
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatRemainingTime(_ time: TimeInterval) -> String {
        guard time > 0 else { return "-00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "-" + String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack {
            // 当前时间
            Text(formatTime(musicService.currentDuration))
                .font(.caption.monospacedDigit())
                .foregroundColor(Color(musicService.currentSkin.screenTextColor))
            
            // 进度条
            ProgressView(value: progress)
                .progressViewStyle(
                    CustomProgressViewStyle(
                        tint: Color(musicService.currentSkin.screenTextColor),
                        background: Color(musicService.currentSkin.screenTextColor).opacity(0.3)
                    )
                )
            
            // 剩余时间
            Text(formatRemainingTime(musicService.totalDuration - musicService.currentDuration))
                .font(.caption.monospacedDigit())
                .foregroundColor(Color(musicService.currentSkin.screenTextColor))
        }
    }
}

// 新增ControlButton视图来简化按钮样式
struct ControlButton: View {
    
    @EnvironmentObject private var musicService: MusicService
    let systemName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .frame(width: 60, height: 60)
                .background(musicService.currentSkin.buttonColor)
                .foregroundColor(musicService.currentSkin.buttonTextColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    // 外描边
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(musicService.currentSkin.buttonOutlineColor), lineWidth: 2)
                )
                .overlay(
                    // 内描边 - 使用inset实现向内偏移效果
                    RoundedRectangle(cornerRadius: 2)
                        .inset(by: 6)  // 向内偏移6pt
                        .strokeBorder(Color(musicService.currentSkin.buttonOutlineColor).opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// 自定义进度条样式结构
struct CustomProgressViewStyle: ProgressViewStyle {
    var tint: Color
    var background: Color
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景轨道
                Capsule()
                    .frame(width: geometry.size.width, height: 4)
                    .foregroundColor(background)
                
                // 前景进度条
                Capsule()
                    .frame(
                        width: CGFloat(configuration.fractionCompleted ?? 0) * geometry.size.width,
                        height: 4
                    )
                    .foregroundColor(tint)
            }
        }
        .frame(height: 4)
    }
}

// 改为简单自定义视图
struct CassetteHole: View {
    var isRotating: Bool
    @Binding var rotationAngle: Double
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.clear)
                .frame(width: 160, height: 160)
            Circle()
                .fill(Color("cassetteColor"))
                .frame(width: 120, height: 120)
            Image("holeDark")
                .resizable()
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(isRotating ? rotationAngle : 0))
        }
        .frame(width: 100, height: 100)
    }
}

#Preview {
    // 直接使用 MusicService 进行预览
    let musicService = MusicService.shared
    
    return PlayerView()
        .environmentObject(musicService)
}
