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
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        
        ZStack{
                // 播放器背景
                ZStack {
                    
                    ZStack {
                        
                        Image(musicService.currentSkin.cassetteImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                        
                        VStack(spacing: 30) {
                            // 旋转的磁带孔
                            ZStack {
                                // 磁带占位
                                Circle()
                                    .foregroundColor(Color("cassetteLight"))
                                    .frame(width: 160, height: 160)
                                // 当前磁带进度
                                Circle()
                                    .foregroundColor(Color("cassetteDark"))
                                    .frame(width: 90, height: 90)
                                // 磁带孔
                                Image("holeDark")
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
                                Image("holeDark")
                                    .resizable()
                                    .overlay {
                                        Circle()
                                            .strokeBorder(Color("cassetteDark"), lineWidth: 3)
                                    }
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(rotationAngle))
                            }
                        }
                        .padding(.leading, 20.0)
                    }
                    .padding(.bottom, 240.0)
                    
/*                    Image(musicService.currentSkin.playerImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
 */
                    
                    // 0. 播放器背景
                    Image(musicService.currentSkin.playerImage)
                        .resizable()
                        .scaledToFill()
                        .edgesIgnoringSafeArea(.all)
                    
                }
            
                // 控制器视图
                VStack(spacing: 0) {
                    
                    // 播放器控制按钮
                    HStack(spacing: 10) {
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
                        ControlButton(systemName: musicService.isPlaying ? "pause.fill" : "play.fill") {
                            Task {
                                if musicService.isPlaying {
                                    await musicService.pause()
                                } else {
                                    try await musicService.play()
                                }
                            }
                        }
                        
                        // 下一首
                        ControlButton(systemName: "forward.fill") {
                            Task {
                                try await musicService.skipToNext()
                            }
                        }
                        
                        // 设置
                        ControlButton(systemName: "recordingtape") {
                            showStoreView = true
                        }
                    }
                    .padding([.top, .leading, .trailing], 10.0)
                    
                    // 歌曲信息
                    VStack(spacing: 5) {
                        // 演唱者 - 歌曲名
                        HStack {
                            Text("PGM NO. 01/12")
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
                                    .foregroundColor(repeatMode == .none ? Color(musicService.currentSkin.screenTextColor).opacity(0.5) : Color(musicService.currentSkin.screenTextColor))
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text("Hey Jude (Remastered)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("The Beatles")
                                    .font(.body)
                            }
                            .foregroundColor(Color(musicService.currentSkin.screenTextColor))
                            
                            Spacer()
                            
                            // 随机播放图标
                            Button {
                                isShuffled.toggle()
                                musicService.shuffleMode = isShuffled ? .songs : .off
                            } label: {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 18))
                                    .foregroundColor(isShuffled ? Color(musicService.currentSkin.screenTextColor).opacity(0.5) : Color(musicService.currentSkin.screenTextColor))
                            }
                        }
                        
                        
                        // 播放控制条
                        HStack {
                            
                            // 当前时间
                            Text(formatTime(musicService.currentPlaybackTime))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(Color(musicService.currentSkin.screenTextColor))
                            
                            // 进度条
                            ProgressView(value: progress)
                                .tint(Color(musicService.currentSkin.screenTextColor))
                            
                            // 总时间
                            Text(formatTime(musicService.songDuration))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(Color(musicService.currentSkin.screenTextColor))
                        }
                    }
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
                    //            .frame(width: 300.0)
                    //.padding(.horizontal, 30)
                    

                }
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(musicService.currentSkin.screenOutlineColor)))
                
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color(musicService.currentSkin.screenOutlineColor), lineWidth: 2))
                .padding()
                
                .padding(.top, 550)
            
        }
        .onAppear {
            if musicService.isPlaying {
                startRotation()
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
    }
    
    // 开始旋转
    private func startRotation() {
        stopRotation() // 先停止现有的计时器
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                rotationAngle += 5 // 每次旋转5度
//                if rotationAngle >= 360 {
//                    rotationAngle = 0
//                }
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

#Preview {
    // 直接使用 MusicService 进行预览
    let musicService = MusicService.shared
    
    return PlayerView()
        .environmentObject(musicService)
}
