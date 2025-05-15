import SwiftUI

struct TapePlayerView: View {
    @EnvironmentObject var musicPlayer: MusicPlayerService
    @EnvironmentObject var purchaseManager: PurchaseManager
    @State private var showingThemeStore = false
    
    // 定义不同主题的按钮位置
    private var buttonPositions: [TapeTheme: [Edge: CGFloat]] {
        [
            .defaultTheme: [.leading: 0.3, .trailing: 0.3, .bottom: 0.15],
            .vintageRed: [.leading: 0.25, .trailing: 0.25, .bottom: 0.2],
            .neonBlue: [.leading: 0.35, .trailing: 0.35, .bottom: 0.1]
        ]
    }
    
    private func buttonPosition(_ edge: Edge) -> CGFloat {
        buttonPositions[musicPlayer.currentTapeTheme]?[edge] ?? 0.3
    }
    
    var body: some View {
        ZStack {
            // 磁带背景
            Image(musicPlayer.currentTapeTheme.rawValue)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()
            
            VStack(spacing: 20) {
                // 歌曲信息展示区域
                if let track = musicPlayer.currentTrack {
                    VStack(spacing: 10) {
                        // 专辑封面
                        if let artwork = track.artwork {
                            Image(uiImage: artwork)
                                .resizable()
                                .frame(width: 200, height: 200)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        } else {
                            Image(systemName: "music.note")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .foregroundColor(.white)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                        }
                        
                        // 歌曲信息
                        VStack(spacing: 5) {
                            Text(track.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            
                            Text(track.artist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 40)
                } else {
                    // 无歌曲时的提示
                    VStack {
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .padding(.bottom, 10)
                        Text("暂无播放歌曲")
                            .font(.headline)
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 40)
                }
                
                Spacer()
                
                GeometryReader { geometry in
                    HStack(spacing: 40) {
                        // 上一首按钮
                        Button(action: {
                            Task { await musicPlayer.skipToPrevious() }
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 30))
                        }
                        .position(
                            x: geometry.size.width * buttonPosition(.leading),
                            y: geometry.size.height * (1 - buttonPosition(.bottom))
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
                                .font(.system(size: 40))
                                .frame(width: 80, height: 80)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .position(
                            x: geometry.size.width * 0.5,
                            y: geometry.size.height * (1 - buttonPosition(.bottom))
                        )
                        
                        // 下一首按钮
                        Button(action: {
                            Task { await musicPlayer.skipToNext() }
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 30))
                        }
                        .position(
                            x: geometry.size.width * (1 - buttonPosition(.trailing)),
                            y: geometry.size.height * (1 - buttonPosition(.bottom))
                        )
                    }
                }
            }
            .padding()
            
            // 主题商店入口按钮
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingThemeStore = true
                    }) {
                        Image(systemName: "paintpalette")
                            .font(.title2)
                            .padding(10)
                            .background(Color.accentColor.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showingThemeStore) {
            ThemeStoreView()
                .environmentObject(musicPlayer)
                .environmentObject(purchaseManager)
        }
    }
}

#Preview("默认主题布局") {
    let musicPlayer = MusicPlayerService()
    musicPlayer.currentTapeTheme = .defaultTheme
    musicPlayer.currentTrack = Track(
        id: "1", 
        title: "示例歌曲",
        artist: "示例艺人",
        artwork: nil
    )
    return TapePlayerView()
        .environmentObject(musicPlayer)
        .environmentObject(PurchaseManager())
}

#Preview("复古红主题布局") {
    let musicPlayer = MusicPlayerService()
    musicPlayer.currentTapeTheme = .vintageRed
    musicPlayer.currentTrack = Track(
        id: "1",
        title: "示例歌曲",
        artist: "示例艺人", 
        artwork: nil
    )
    return TapePlayerView()
        .environmentObject(musicPlayer)
        .environmentObject(PurchaseManager())
}

#Preview("播放中") {
    let musicPlayer = MusicPlayerService()
    musicPlayer.currentTrack = Track(
        id: "1",
        title: "这是一首很长很长很长很长很长很长很长很长的歌曲名称",
        artist: "很长很长很长很长很长的艺人名称",
        artwork: nil
    )
    musicPlayer.isPlaying = true
    return TapePlayerView()
        .environmentObject(musicPlayer)
        .environmentObject(PurchaseManager())
}

#Preview("无歌曲") {
    TapePlayerView()
        .environmentObject(MusicPlayerService())
        .environmentObject(PurchaseManager())
}
