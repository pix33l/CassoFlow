import SwiftUI

struct AudioStationArtistDetailView: View {
    @EnvironmentObject private var musicService: MusicService
    @StateObject private var coordinator = MusicServiceCoordinator()
    
    let artist: UniversalArtist
    
    @State private var detailedArtist: UniversalArtist?
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
                            await loadArtistDetails()
                        }
                    }
                } else if let detailedArtist = detailedArtist {
                    // 艺术家头部信息
                    ArtistHeaderView(artist: detailedArtist)
                    
                    // 专辑列表
                    if !detailedArtist.albums.isEmpty {
                        AlbumsListView(albums: detailedArtist.albums)
                    }
                    
                    // 艺术家信息
                    ArtistInfoView(artist: detailedArtist)
                }
            }
            .padding()
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadArtistDetails()
        }
    }
    
    @MainActor
    private func loadArtistDetails() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedArtist = try await coordinator.getArtist(id: artist.id)
            detailedArtist = loadedArtist
        } catch {
            errorMessage = "加载艺术家详情失败：\(error.localizedDescription)"
            print("Audio Station艺术家加载失败: \(error)")
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
            
            Text("正在加载艺术家详情...")
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

private struct ArtistHeaderView: View {
    let artist: UniversalArtist
    
    var body: some View {
        VStack(spacing: 16) {
            // 艺术家头像
            Circle()
                .fill(.tertiary)
                .frame(width: 150, height: 150)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                }
                .shadow(radius: 8)
            
            // 艺术家信息
            VStack(spacing: 8) {
                Text(artist.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("艺术家")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Text("\(artist.albumCount) 张专辑")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct AlbumsListView: View {
    let albums: [UniversalAlbum]
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("专辑")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            LazyVStack(spacing: 0) {
                ForEach(albums) { album in
                    AlbumRowView(album: album) {
                        // 导航到专辑详情
                        print("点击专辑: \(album.title)")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    if album.id != albums.last?.id {
                        Divider()
                            .padding(.leading, 80)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct AlbumRowView: View {
    let album: UniversalAlbum
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
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
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 专辑信息
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    if let year = album.year {
                        Text(String(year))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if album.year != nil && album.songCount > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if album.songCount > 0 {
                        Text("\(album.songCount) 首")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let genre = album.genre {
                    Text(genre)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // 播放按钮
            Button {
                Task {
                    do {
                        try await MusicService.shared.playUniversalAlbum(album)
                    } catch {
                        print("播放专辑失败: \(error)")
                    }
                }
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

private struct ArtistInfoView: View {
    let artist: UniversalArtist
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("艺术家信息")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(title: "艺术家", value: artist.name)
                InfoRow(title: "专辑数量", value: "\(artist.albumCount) 张")
                InfoRow(title: "来源", value: "Audio Station")
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

struct AudioStationArtistDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AudioStationArtistDetailView(artist: UniversalArtist(
                id: "test-artist",
                name: "测试艺术家",
                albumCount: 5,
                albums: [],
                source: .audioStation,
                originalData: "mock"
            ))
            .environmentObject(MusicService.shared)
        }
    }
}
