import SwiftUI

struct PlayerView: View {
    @State private var isPlaying = false
    @State private var progress: CGFloat = 0.3 // 示例进度值
    @State private var showLibraryView = false
    @State private var showSettingsView = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 1. 磁带播放器图片
            Image("CF-001") // 替换为你的图片资源名
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 600)
                .padding(.top, 20)
            
            Spacer()
            
            // 2. 歌曲信息区域
            VStack(spacing: 10) {
                // 演唱者 - 歌曲名
                VStack {
                    Text("The Beatles - Hey Jude")
                        .font(.title3)
                }
                
                // 播放控制条
                HStack {
                    // 循环播放图标
                    Image(systemName: "repeat")
                        .font(.system(size: 18))
                    
                    // 当前时间
                    Text("1:23")
                        .font(.caption.monospacedDigit())
                    
                    // 进度条
                    ProgressView(value: progress)
                        .tint(.primary)
                    
                    // 总时间
                    Text("3:45")
                        .font(.caption.monospacedDigit())
                    
                    // 随机播放图标
                    Image(systemName: "shuffle")
                        .font(.system(size: 18))
                }
            }
            .padding()
            
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 92/255, green: 107/255, blue: 104/255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color(red: 76/255, green: 88/255, blue: 86/255), lineWidth: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.black, lineWidth: 4)
                    )
            )
            .padding(.horizontal, 30)
            
            // 3. 底部控制按钮
            HStack(spacing: 12) {
                // 媒体库
                ControlButton(systemName: "music.note.list") {
                    showLibraryView = true
                }
                
                // 上一首
                ControlButton(systemName: "backward.fill") {}
                
                // 播放/暂停
                ControlButton(systemName: isPlaying ? "pause.fill" : "play.fill") {
                    isPlaying.toggle()
                }
                
                // 下一首
                ControlButton(systemName: "forward.fill") {}
                
                // 设置
                ControlButton(systemName: "gearshape.fill") {
                    showSettingsView = true
                }
            }
            .padding(.bottom, 60)
            .foregroundColor(.primary)
        }
        .sheet(isPresented: $showLibraryView) {
            LibraryView()
        }
        .sheet(isPresented: $showSettingsView) {
            SettingsView()
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
                .font(.title)
                .frame(width: 60, height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    PlayerView()
}
