import SwiftUI

struct AudioStationLibraryView: View {
    @EnvironmentObject private var musicService: MusicService
    @StateObject private var coordinator = MusicServiceCoordinator()
    
    @State private var albums: [UniversalAlbum] = []
    @State private var playlists: [UniversalPlaylist] = []
    @State private var artists: [UniversalArtist] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if isLoading {
                        LoadingSection()
                    } else if let error = errorMessage {
                        ErrorSection(message: error) {
                            Task {
                                await loadData()
                            }
                        }
                    } else {
                        // 最近专辑部分
                        if !albums.isEmpty {
                            AlbumsSection(albums: albums)
                        }
                        
                        // 播放列表部分
                        if !playlists.isEmpty {
                            PlaylistsSection(playlists: playlists)
                        }
                        
                        // 艺术家部分
                        if !artists.isEmpty {
                            ArtistsSection(artists: artists)
                        }
                        
                        // 连接状态提示
                        ConnectionStatusSection()
                    }
                }
                .padding()
            }
            .navigationTitle("Audio Station")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshData()
            }
        }
        .task {
            await loadInitialData()
        }
    }
    
    // MARK: - 数据加载
    
    @MainActor
    private func loadInitialData() async {
        await loadData()
    }
    
    @MainActor
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 并行加载数据
            async let albumsTask = coordinator.getRecentAlbums()
            async let playlistsTask = coordinator.getRecentPlaylists()
            async let artistsTask = coordinator.getArtists()
            
            let (loadedAlbums, loadedPlaylists, loadedArtists) = try await (albumsTask, playlistsTask, artistsTask)
            
            albums = loadedAlbums
            playlists = loadedPlaylists
            artists = Array(loadedArtists.prefix(20)) // 限制艺术家数量以提升性能
            
        } catch {
            errorMessage = "加载数据失败：\(error.localizedDescription)"
            print("AudioStation数据加载失败: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func refreshData() async {
        await loadData()
    }
}

// MARK: - 子视图组件

private struct LoadingSection: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在加载 Audio Station 媒体库...")
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

private struct AlbumsSection: View {
    let albums: [UniversalAlbum]
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "opticaldisc")
                    .foregroundColor(.orange)
                Text("最新专辑")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(albums.count) 张专辑")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(albums.prefix(10)) { album in
                        AlbumCard(album: album)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct PlaylistsSection: View {
    let playlists: [UniversalPlaylist]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundColor(.orange)
                Text("播放列表")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(playlists.count) 个列表")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(playlists.prefix(10)) { playlist in
                        PlaylistCard(playlist: playlist)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct ArtistsSection: View {
    let artists: [UniversalArtist]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2")
                    .foregroundColor(.orange)
                Text("艺术家")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(artists.count) 位艺术家")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(artists.prefix(6)) { artist in
                    ArtistCard(artist: artist)
                }
            }
        }
    }
}

private struct ConnectionStatusSection: View {
    @StateObject private var audioStationService = AudioStationMusicService.shared
    
    var body: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack {
                Image(systemName: audioStationService.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(audioStationService.isConnected ? .green : .red)
                
                Text(audioStationService.isConnected ? "已连接到 Audio Station" : "未连接到 Audio Station")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(.top)
    }
}

// MARK: - 卡片组件

private struct AlbumCard: View {
    let album: UniversalAlbum
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: album.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.tertiary)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(album.artistName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 120)
        .onTapGesture {
            Task {
                do {
                    try await musicService.playUniversalAlbum(album)
                } catch {
                    print("播放专辑失败: \(error)")
                }
            }
        }
    }
}

private struct PlaylistCard: View {
    let playlist: UniversalPlaylist
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: playlist.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.tertiary)
                    .overlay {
                        Image(systemName: "music.note.list")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text("\(playlist.songCount) 首歌曲")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120)
        .onTapGesture {
            Task {
                do {
                    try await musicService.playUniversalPlaylist(playlist)
                } catch {
                    print("播放播放列表失败: \(error)")
                }
            }
        }
    }
}

private struct ArtistCard: View {
    let artist: UniversalArtist
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.tertiary)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(artist.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(artist.albumCount) 张专辑")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 预览

struct AudioStationLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        AudioStationLibraryView()
            .environmentObject(MusicService.shared)
    }
}
