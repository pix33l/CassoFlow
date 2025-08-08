import SwiftUI

struct AudioStationMusicDetailView: View {
    @EnvironmentObject private var musicService: MusicService
    @StateObject private var coordinator = MusicServiceCoordinator()
    
    let album: UniversalAlbum
    
    @State private var detailedAlbum: UniversalAlbum?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    LoadingView()
                } else if let error = errorMessage {
                    ErrorSection(message: error) {
                        Task {
                            await loadAlbumDetails()
                        }
                    }
                } else if let detailedAlbum = detailedAlbum {
                    // 专辑头部信息
                    AlbumHeaderView(album: detailedAlbum)
                    
                    // 播放控制按钮
                    PlayControlsView(album: detailedAlbum)
                    
                    // 歌曲列表
                    if !detailedAlbum.songs.isEmpty {
                        SongListView(songs: detailedAlbum.songs)
                    }
                    
                    // 专辑信息
                    AlbumInfoView(album: detailedAlbum)
                }
            }
            .padding()
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlbumDetails()
        }
    }
    
    @MainActor
    private func loadAlbumDetails() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedAlbum = try await coordinator.getAlbum(id: album.id)
            detailedAlbum = loadedAlbum
        } catch {
            errorMessage = "加载专辑详情失败：\(error.localizedDescription)"
            print("Audio Station专辑加载失败: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - 子视图组件

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在加载专辑详情...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

private struct ErrorSection: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重试", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

private struct AlbumHeaderView: View {
    let album: UniversalAlbum
    
    var body: some View {
        VStack(spacing: 16) {
            // 专辑封面
            AsyncImage(url: album.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.tertiary)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                    }
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 8)
            
            // 专辑信息
            VStack(spacing: 8) {
                Text(album.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(album.artistName)
                    .font(.headline)
                    .foregroundColor(.orange)
                
                HStack {
                    if let year = album.year {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if album.year != nil && !album.songs.isEmpty {
                        Text("•")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if !album.songs.isEmpty {
                        Text("\(album.songs.count) 首歌曲")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if !album.songs.isEmpty && album.duration > 0 {
                        Text("•")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(album.duration))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

private struct PlayControlsView: View {
    let album: UniversalAlbum
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        HStack(spacing: 16) {
            // 播放按钮
            Button {
                Task {
                    do {
                        try await musicService.playUniversalAlbum(album)
                    } catch {
                        print("播放专辑失败: \(error)")
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("播放")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.orange)
                .clipShape(Capsule())
            }
            
            // 随机播放按钮
            Button {
                Task {
                    do {
                        try await musicService.playUniversalAlbum(album, shuffled: true)
                    } catch {
                        print("随机播放专辑失败: \(error)")
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "shuffle")
                    Text("随机播放")
                }
                .font(.headline)
                .foregroundColor(.orange)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.orange.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }
}

private struct SongListView: View {
    let songs: [UniversalSong]
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("歌曲")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            LazyVStack(spacing: 0) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    SongRowView(song: song, index: index + 1) {
                        Task {
                            do {
                                try await musicService.playUniversalSongs(songs, startingAt: index)
                            } catch {
                                print("播放歌曲失败: \(error)")
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    if index < songs.count - 1 {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct SongRowView: View {
    let song: UniversalSong
    let index: Int
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 序号
            Text("\(index)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            // 歌曲信息
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                
                Text(song.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 时长
            Text(formatTime(song.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct AlbumInfoView: View {
    let album: UniversalAlbum
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("专辑信息")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(title: "专辑", value: album.title)
                InfoRow(title: "艺术家", value: album.artistName)
                
                if let year = album.year {
                    InfoRow(title: "发行年份", value: String(year))
                }
                
                if let genre = album.genre {
                    InfoRow(title: "流派", value: genre)
                }
                
                InfoRow(title: "歌曲数量", value: "\(album.songCount) 首")
                
                if album.duration > 0 {
                    InfoRow(title: "总时长", value: formatDuration(album.duration))
                }
                
                InfoRow(title: "来源", value: "Audio Station")
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - 预览

struct AudioStationMusicDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AudioStationMusicDetailView(album: UniversalAlbum(
                id: "test-album",
                title: "测试专辑",
                artistName: "测试艺术家",
                year: 2024,
                genre: "摇滚",
                songCount: 12,
                duration: 2800,
                artworkURL: nil,
                songs: [],
                source: .audioStation,
                originalData: "mock"
            ))
            .environmentObject(MusicService.shared)
        }
    }
}
