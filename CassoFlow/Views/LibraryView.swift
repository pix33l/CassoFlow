import SwiftUI
import MusicKit

struct LibraryView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var musicService: MusicService
    @Environment(\.dismiss) var dismiss
    // 选中的分段
    @State private var selectedSegment = 0
    // 用户专辑列表数据
    @State private var userAlbums: MusicItemCollection<Album> = []
    // 用户歌单列表数据
    @State private var userPlaylists: MusicItemCollection<Playlist> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {  // 改为 NavigationStack 避免嵌套导航问题
            VStack(spacing: 0) {

                // 内容视图
                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    Image(systemName: "play.house")
                    Text(error)
                } else {
                    contentView
                }
            }
            .navigationTitle("媒体库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote)
                            .foregroundColor(.primary)
                            .padding(8)           // 增加内边距以扩大背景圆形
                            .background(
                                Circle()           // 圆形背景
                                    .fill(Color.gray.opacity(0.15))
                            )
                    }
                }
            }
            .task {
                await loadUserLibrary()
            }
        }
    }

    private var contentView: some View {
        ScrollView {
            
            // 分段控制器
            Picker("媒体类型", selection: $selectedSegment) {
                Text("专辑").tag(0)
                Text("歌单").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 110), spacing: 5)
            ], spacing: 20) {
                if selectedSegment == 0 {
                    ForEach(userAlbums) { album in
                        NavigationLink {
                            AlbumDetailView(album: album)
                                .environmentObject(musicService)
                        } label: {
                            AlbumCell(album: album)
                        }
                    }
                } else {
                    ForEach(userPlaylists) { playlist in
                        PlaylistCell(playlist: playlist)
                    }
                }
            }
            .padding()
        }
    }

    private func loadUserLibrary() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let status = await musicService.requestAuthorization()
            guard status == .authorized else {
                errorMessage = "请授权访问您的音乐库"
                return
            }

            // 同时加载专辑和歌单
            async let albums = musicService.fetchUserLibraryAlbums()
            async let playlists = musicService.fetchUserLibraryPlaylists()
            
            let (albumsResult, playlistsResult) = await (try? albums, try? playlists)
            
            userAlbums = albumsResult ?? []
            userPlaylists = playlistsResult ?? []
            
            if userAlbums.isEmpty && userPlaylists.isEmpty {
                errorMessage = "您的媒体库是空的"
            }
        } catch {
            errorMessage = "加载媒体库失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// 专辑单元格视图
struct AlbumCell: View {
    let album: Album
    
    var body: some View {
        VStack(alignment: .leading) {
            // 专辑封面
            ZStack {
                AsyncImage(url: album.artwork?.url(width: 300, height: 300)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
                .frame(width: 100, height: 160)
                .clipShape(Rectangle())
                Image("cover-cassette")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            // 专辑信息
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(album.artistName)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.top, 4)
        }
    }
}

// 歌单单元格视图
struct PlaylistCell: View {
    let playlist: Playlist
    
    var body: some View {
        VStack(alignment: .leading) {
            // 歌单封面
            ZStack {
                AsyncImage(url: playlist.artwork?.url(width: 300, height: 300)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
                .frame(width: 100, height: 160)
                .clipShape(Rectangle())
                Image("cover-cassette")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            // 歌单信息
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .foregroundColor(.primary)
                    .font(.footnote)
                    .lineLimit(1)
            }
            .padding(.top, 4)
        }
    }
}

#Preview {
    let musicService = MusicService.shared
    LibraryView()
        .environmentObject(musicService)
}
