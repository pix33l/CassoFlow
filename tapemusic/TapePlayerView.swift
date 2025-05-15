
import SwiftUI

struct TapePlayerView: View {
    @EnvironmentObject var musicPlayer: MusicPlayerService
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    
    var body: some View {
        GeometryReader { geometry in
            let theme = musicPlayer.currentTapeTheme
            let buttonPositions = theme.buttonPositions
            let infoPositions = theme.infoPositions
            
            ZStack {
                // 磁带背景
                Image(theme.rawValue)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                
                // 歌曲信息
                if let track = musicPlayer.currentTrack {
                    Group {
                        // 歌曲标题
                        Text(track.title)
                            .font(.headline)
                            .position(
                                x: geometry.size.width * infoPositions.title.x,
                                y: geometry.size.height * infoPositions.title.y
                            )
                        
                        // 表演者
                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .position(
                                x: geometry.size.width * infoPositions.artist.x,
                                y: geometry.size.height * infoPositions.artist.y
                            )
                        
                        // 当前播放时间
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .position(
                                x: geometry.size.width * infoPositions.currentTime.x,
                                y: geometry.size.height * infoPositions.currentTime.y
                            )
                        
                        // 歌曲总时长
                        Text(formatTime(duration))
                            .font(.caption)
                            .position(
                                x: geometry.size.width * infoPositions.duration.x,
                                y: geometry.size.height * infoPositions.duration.y
                            )
                    }
                }
                
                // 控制按钮
                Group {
                    // 上一首按钮
                    Button(action: {
                        Task { await musicPlayer.skipToPrevious() }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 24))
                    }
                    .position(
                        x: geometry.size.width * buttonPositions.prevButton.x,
                        y: geometry.size.height * buttonPositions.prevButton.y
                    )
                    
                    // 播放/暂停按钮
                    Button(action: {
                        if musicPlayer.isPlaying {
                            musicPlayer.pause()
                        } else {
                            Task { await musicPlayer.play() }
                        }
                    }) {
                        Image(systemName: musicPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32))
                            .frame(width: 60, height: 60)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .position(
                        x: geometry.size.width * buttonPositions.playButton.x,
                        y: geometry.size.height * buttonPositions.playButton.y
                    )
                    
                    // 下一首按钮
                    Button(action: {
                        Task { await musicPlayer.skipToNext() }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 24))
                    }
                    .position(
                        x: geometry.size.width * buttonPositions.nextButton.x,
                        y: geometry.size.height * buttonPositions.nextButton.y
                    )
                }
            }
        }
        .onReceive(musicPlayer.$currentTrack) { _ in
            updateTrackTimes()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func updateTrackTimes() {
        // 这里需要实现获取当前播放时间和总时长的逻辑
        // 暂时使用示例值
        currentTime = 123
        duration = 256
    }
}
