import SwiftUI
import MusicKit

struct AlbumDetailView: View {
    @EnvironmentObject private var musicService: MusicService
    let album: Album
    @State private var tracks: MusicItemCollection<Track> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // 判断当前是否正在播放指定歌曲
    private func isPlaying(_ track: Track) -> Bool {
        let isSameTitle = musicService.currentTitle == track.title
        let isSameArtist = musicService.currentArtist == track.artistName
        return isSameTitle && isSameArtist && musicService.isPlaying
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部专辑信息
                VStack(spacing: 16) {
                    AsyncImage(url: album.artwork?.url(width: 300, height: 300)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(spacing: 4) {
                        Text(album.title)
                            .font(.title2.bold())
                        
                        Text(album.artistName)
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        if let releaseDate = album.releaseDate {
                            Text("\(album.genreNames.first ?? "未知风格") • \(releaseDate.formatted(.dateTime.year()))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // 播放控制按钮
                    HStack(spacing: 20) {
                        Button {
                            Task {
                                try await musicService.playAlbum(album)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("播放")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                        
                        Button {
                            Task {
                                try await musicService.playAlbum(album, shuffled: true)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "shuffle")
                                Text("随机播放")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 歌曲列表
                VStack(alignment: .leading, spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        Divider()
                            .padding(.leading, 20)
                            .padding(.trailing, 16)
                        
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            HStack {
                                // 替换序号为播放状态指示器
                                if isPlaying(track) {
                                    AudioWaveView()
                                        .frame(width: 24, height: 24)
                                } else {
                                    Text("\(index + 1)")
                                        .frame(width: 24, alignment: .center)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
                                        .foregroundColor(.primary)
                                    Text(track.artistName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(formattedDuration(track.duration ?? 0))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .background(
                                isPlaying(track) ? Color.white.opacity(0.1) :Color.clear
                                    .contentShape(Rectangle())
                            )
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.2), value: isPlaying(track))
                            .onTapGesture {
                                Task {
                                    try await musicService.playTrack(track, in: album)
                                }
                            }
                            
                            if index < tracks.count - 1 {
                                Divider()
                                    .padding(.leading, 40)
                                    .padding(.trailing, 16)
                            }
                        }
                        
                        Divider()
                            .padding(.leading, 20)
                            .padding(.trailing, 16)
                    }
                }
                
                // 底部信息
                if let releaseDate = album.releaseDate, !tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("发表于 \(releaseDate.formatted(.dateTime.year().month().day()))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        let totalDuration = tracks.reduce(0) { $0 + ($1.duration ?? 0) }
                        Text("\(tracks.count) 首歌曲 • \(formattedDuration(totalDuration))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlbumTracks()
        }
    }
    
    private func loadAlbumTracks() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let detailedAlbum = try await album.with([.tracks])
            tracks = detailedAlbum.tracks ?? []
            
            if tracks.isEmpty {
                errorMessage = "无法加载歌曲列表"
            }
        } catch {
            errorMessage = "加载专辑详情失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// 音频波形动画视图
struct AudioWaveView: View {
    @State private var animationAmounts = [0.5, 0.3, 0.7, 0.4, 0.6]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(.primary)
                    .frame(width: 2, height: animationAmounts[index] * 20)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                        value: animationAmounts[index]
                    )
                    .onAppear {
                        withAnimation {
                            animationAmounts[index] = [0.3, 0.5, 0.7, 0.9, 0.6].randomElement()!
                        }
                    }
            }
        }
        .frame(width: 24, height: 24)
    }
}

/*
 #Preview {
    let album = Album(
        id: MusicItemID("1"),
        title: "示例专辑",
        artistName: "示例艺术家",
        artwork: nil,
        releaseDate: Date(),
        genreNames: ["流行"]
    )
    
    let musicService = MusicService.shared
    musicService.currentSong = Song(
        id: MusicItemID("1"),
        title: "示例歌曲",
        artistName: "示例艺术家",
        duration: 180,
        artwork: nil
    )
    musicService.isPlaying = true
    
    AlbumDetailView(album: album)
        .environmentObject(musicService)
}
*/
