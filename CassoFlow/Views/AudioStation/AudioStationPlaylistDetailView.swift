import SwiftUI

struct AudioStationPlaylistDetailView: View {
    @EnvironmentObject private var musicService: MusicService
    @StateObject private var coordinator = MusicServiceCoordinator()
    
    let playlist: UniversalPlaylist
    
    @State private var detailedPlaylist: UniversalPlaylist?
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
                            await loadPlaylistDetails()
                        }
                    }
                } else if let detailedPlaylist = detailedPlaylist {
                    // 播放列表头部信息
                    PlaylistHeaderView(playlist: detailedPlaylist)
                    
                    // 播放控制按钮
                    PlayControlsView(playlist: detailedPlaylist)
                    
                    // 歌曲列表
                    if !detailedPlaylist.songs.isEmpty {
                        SongListView(songs: detailedPlaylist.songs)
                    }
                    
                    // 播放列表信息
                    PlaylistInfoView(playlist: detailedPlaylist)
                }
            }
            .padding()
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPlaylistDetails()
        }
    }
    
    @MainActor
    private func loadPlaylistDetails() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedPlaylist = try await coordinator.getPlaylist(id: playlist.id)
            detailedPlaylist = loadedPlaylist
        } catch {
            errorMessage = "加载播放列表详情失败：\(error.localizedDescription)"
            print("Audio Station播放列表加载失败: \(error)")
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
            
            Text("正在加载播放列表详情...")
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
                .foregroundColor(.yellow)
            
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

private struct PlaylistHeaderView: View {
    let playlist: UniversalPlaylist
    
    var body: some View {
        VStack(spacing: 16) {
            // 播放列表封面
            AsyncImage(url: playlist.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.tertiary)
                    .overlay {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                    }
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 8)
            
            // 播放列表信息
            VStack(spacing: 8) {
                Text(playlist.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if let curatorName = playlist.curatorName {
                    Text(curatorName)
                        .font(.headline)
                        .foregroundColor(.yellow)
                }
                
                HStack {
                    if !playlist.songs.isEmpty {
                        Text("\(playlist.songs.count) 首歌曲")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if !playlist.songs.isEmpty && playlist.duration > 0 {
                        Text("•")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(playlist.duration))
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
    let playlist: UniversalPlaylist
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        HStack(spacing: 16) {
            // 播放按钮
            Button {
                Task {
                    do {
                        try await musicService.playUniversalPlaylist(playlist)
                    } catch {
                        print("播放播放列表失败: \(error)")
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
                        try await musicService.playUniversalPlaylist(playlist, shuffled: true)
                    } catch {
                        print("随机播放播放列表失败: \(error)")
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
                
                HStack {
                    Text(song.artistName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let albumName = song.albumName {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(albumName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
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

private struct PlaylistInfoView: View {
    let playlist: UniversalPlaylist
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("播放列表信息")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(title: "播放列表", value: playlist.name)
                
                if let curatorName = playlist.curatorName {
                    InfoRow(title: "创建者", value: curatorName)
                }
                
                InfoRow(title: "歌曲数量", value: "\(playlist.songCount) 首")
                
                if playlist.duration > 0 {
                    InfoRow(title: "总时长", value: formatDuration(playlist.duration))
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

struct AudioStationPlaylistDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AudioStationPlaylistDetailView(playlist: UniversalPlaylist(
                id: "test-playlist",
                name: "我的播放列表",
                curatorName: "Audio Station",
                songCount: 15,
                duration: 3600,
                artworkURL: nil,
                songs: [],
                source: .audioStation,
                originalData: "mock"
            ))
            .environmentObject(MusicService.shared)
        }
    }
}
