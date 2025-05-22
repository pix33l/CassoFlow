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
            Image("CF-001")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 600)
                .padding(.top, 20)
            
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

                    Spacer()
                    Button {
                        showSettingsView = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
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
                            .foregroundColor(repeatMode == .none ? .primary : .blue)
                    }
                    
                    // 当前时间
                    Text(formatTime(musicService.currentPlaybackTime))
                        .font(.caption.monospacedDigit())
                    
                    // 进度条
                    ProgressView(value: progress)
                        .tint(.primary)
                    
                    // 总时间
                    Text(formatTime(musicService.songDuration))
                        .font(.caption.monospacedDigit())
                    
                    // 随机播放图标
                    Button {
                        isShuffled.toggle()
                        musicService.shuffleMode = isShuffled ? .songs : .off
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 18))
                            .foregroundColor(isShuffled ? .blue : .primary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 92/255, green: 107/255, blue: 104/255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color(red: 76/255, green: 88/255, blue: 86/255), lineWidth: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.black, lineWidth: 4))
            )
            .padding(.horizontal, 30)
            
            // 3. 底部控制按钮
            HStack(spacing: 12) {
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
            .padding(.bottom, 60)
            .foregroundColor(.primary)
        }
        .background(musicService.currentSkin.backgroundColor)
        .onAppear {
            Task {
                await MainActor.run {
                    musicService.updateCurrentSong()
                }
            }
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
                .background(Color.black)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

#Preview {
    // 直接使用 MusicService 进行预览
    let musicService = MusicService.shared
    
    return PlayerView()
        .environmentObject(musicService)
}
