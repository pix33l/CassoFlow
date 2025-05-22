import SwiftUI
import MusicKit
import Foundation

struct PlayerView: View {
    @EnvironmentObject private var musicService: MusicService
    @State private var showLibraryView = false
    @State private var showSettingsView = false
    @State private var showStoreView = false
    @State private var repeatMode: MusicPlayer.RepeatMode = .none
    @State private var isShuffled = false
    @State private var isPlaying = false
    @State private var rotationAngle: Double = 0
    @State private var rotationTimer: Timer?
    
    // 计算属性：当前播放进度
    private var progress: CGFloat {
        guard musicService.songDuration > 0 else { return 0 }
        return CGFloat(musicService.currentPlaybackTime / musicService.songDuration)
    }
    
    // 格式化时间显示
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 20) {
            // 1. 磁带播放器图片
            ZStack {
                Image("cassette")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 550)

                VStack(spacing: 30) {
                    // 旋转的磁带孔
                    ZStack {
                        Circle()
                            .foregroundColor(Color("cassetteLight"))
                            .frame(width: 160, height: 160)
                        Circle()
                            .foregroundColor(Color("cassetteDark"))
                            .frame(width: 90, height: 90)
                        Image("hole")
                            .resizable()
                            .overlay {
                                Circle()
                                    .strokeBorder(Color("cassetteDark"), lineWidth: 3)
                            }
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(rotationAngle))
                            .onChange(of: musicService.isPlaying) { isPlaying in
                                if isPlaying {
                                    startRotation()
                                } else {
                                    stopRotation()
                                }
                            }
                    }
                    
                    // 第二个旋转的磁带孔
                    ZStack {
                        Circle()
                            .foregroundColor(Color("cassetteLight"))
                            .frame(width: 160, height: 160)
                        Circle()
                            .foregroundColor(Color("cassetteDark"))
                            .frame(width: 150, height: 150)
                        Image("hole")
                            .resizable()
                            .overlay {
                                Circle()
                                    .strokeBorder(Color("cassetteDark"), lineWidth: 3)
                            }
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(rotationAngle))
                    }
                }
            }
            .padding(.top, 20.0)
            
            Spacer()
            
            // 2. 歌曲信息区域
            VStack(spacing: 10) {
                // 演唱者 - 歌曲名
                HStack {
                    VStack {
                        if let song = musicService.currentSong {
                            Text("\(song.artistName) - \(song.title)")
                                .font(.title3)
                        } else {
                            Text("未播放歌曲")
                                .font(.title3)
                        }
                    }
                    .foregroundColor(Color("cassetteDark"))

                    Spacer()
                    Button {
                        showSettingsView = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .foregroundColor(Color("cassetteDark"))
                }

                
                // 播放控制条
                HStack {
                    // 循环播放图标
                    Button {
                        switch repeatMode {
                        case .none: repeatMode = .one
                        case .one: repeatMode = .all
                        case .all: repeatMode = .none
                        }
                        musicService.repeatMode = repeatMode
                    } label: {
                        Image(systemName: repeatMode == .none ? "repeat" : "repeat.1")
                            .font(.system(size: 18))
                            .foregroundColor(repeatMode == .none ? Color("cassetteDark").opacity(0.5) : Color("cassetteDark"))
                    }
                    
                    // 当前时间
                    Text(formatTime(musicService.currentPlaybackTime))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(Color("cassetteDark"))
                    
                    // 进度条
                    ProgressView(value: progress)
                        .tint(Color("cassetteDark"))
                    
                    // 总时间
                    Text(formatTime(musicService.songDuration))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(Color("cassetteDark"))
                    
                    // 随机播放图标
                    Button {
                        isShuffled.toggle()
                        musicService.shuffleMode = isShuffled ? .songs : .off
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 18))
                            .foregroundColor(isShuffled ? Color("cassetteDark").opacity(0.5) : Color("cassetteDark"))
                    }
                }
                .frame(width: 300.0)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color("cassetteLight"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color("cassetteDark").opacity(0.2), lineWidth: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color("cassetteDark"), lineWidth: 3))
            )
            .padding(.horizontal, 30)
            
            // 3. 底部控制按钮
            HStack(spacing: 8) {
                // 媒体库
                ControlButton(systemName: "music.note.list") {
                    showLibraryView = true
                }
                
                // 上一首
                ControlButton(systemName: "backward.fill") {
                    Task {
                        try await musicService.skipToPrevious()
                    }
                }
                
                // 播放/暂停
                ControlButton(systemName: isPlaying ? "pause.fill" : "play.fill") {
                    Task {
                        isPlaying ? try await musicService.pause() : try await musicService.play()
                        isPlaying.toggle()
                    }
                }
                
                // 下一首
                ControlButton(systemName: "forward.fill") {
                    Task {
                        try await musicService.skipToNext()
                    }
                }
                
                // 设置
                ControlButton(systemName: "paintbrush.pointed.fill") {
                    showStoreView = true
                }
            }
            .padding(.bottom, 100)
            .foregroundColor(.primary)
        }
        .background(musicService.currentSkin.backgroundColor)
        .onAppear {
            if musicService.isPlaying {
                startRotation()
            }
            Task {
                await MainActor.run {
                    musicService.updateCurrentSong()
                }
            }
        }
        .onDisappear {
            stopRotation()
        }
        .sheet(isPresented: $showLibraryView) {
            LibraryView()
        }
        .sheet(isPresented: $showSettingsView) {
            SettingsView()
        }
        .sheet(isPresented: $showStoreView) {
            StoreView()
        }
        .background(musicService.currentSkin.backgroundColor)
    }
    
    // 开始旋转
    private func startRotation() {
        stopRotation() // 先停止现有的计时器
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                rotationAngle += 5 // 每次旋转5度
                if rotationAngle >= 360 {
                    rotationAngle = 0
                }
            }
        }
    }
    
    // 停止旋转
    private func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }
}

// 新增ControlButton视图来简化按钮样式
struct ControlButton: View {
    let systemName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .frame(width: 60, height: 60)
                .background(Color("cassetteLight"))
                .foregroundColor(Color("cassetteDark"))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    // 外描边
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color("cassetteDark"), lineWidth: 3)
                )
                .overlay(
                    // 内描边 - 使用inset实现向内偏移效果
                    RoundedRectangle(cornerRadius: 4)
                        .inset(by: 6)  // 向内偏移6pt
                        .strokeBorder(Color("cassetteDark").opacity(0.5), lineWidth: 1)
                )
        }
    }
}

#Preview {
    // 直接使用 MusicService 进行预览
    let musicService = MusicService.shared
    
    return PlayerView()
        .environmentObject(musicService)
}
