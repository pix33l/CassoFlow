import SwiftUI
import MusicKit

struct LibraryView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var musicService: MusicService
    // 选中的分段
    @State private var selectedSegment = 0
    // 用户专辑列表数据
    @State private var userAlbums: MusicItemCollection<Album> = []
    // 用户歌单列表数据
    @State private var userPlaylists: MusicItemCollection<Playlist> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部标题
                HStack {
                    Text("媒体库")
                        .font(.title)
                        .bold()
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                // 分段控制器
                Picker("媒体类型", selection: $selectedSegment) {
                    Text("专辑").tag(0)
                    Text("歌单").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                } else {
                    contentView
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadUserLibrary()
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150), spacing: 20)
            ], spacing: 20) {
                if selectedSegment == 0 {
                    ForEach(userAlbums) { album in
                        AlbumCell(album: album)
                            .onTapGesture {
                                Task {
                                    try await musicService.playAlbum(album)
                                }
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
            AsyncImage(url: album.artwork?.url(width: 300, height: 300)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 专辑信息
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.system(size: 14))
                    .lineLimit(1)
                
                Text(album.artistName)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
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
            AsyncImage(url: playlist.artwork?.url(width: 300, height: 300)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 歌单信息
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 14))
                    .lineLimit(1)
                
                Text(playlist.description)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            .padding(.top, 4)
        }
    }
}

#Preview {
    // 直接使用 MusicService 进行预览
    let musicService = MusicService.shared
    
    return LibraryView()
        .environmentObject(musicService)
}
