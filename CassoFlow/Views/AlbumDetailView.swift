import SwiftUI
import MusicKit

struct AlbumDetailView: View {
    @EnvironmentObject private var musicService: MusicService
    let album: Album
    @State private var tracks: MusicItemCollection<Track> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.title)
                            .font(.title.bold())
                        
                        Text(album.artistName)
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        if let releaseDate = album.releaseDate {
                            Text("\(album.genreNames?.first ?? "未知风格") • \(releaseDate.formatted(.dateTime.year()))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
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
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        Button {
                            Task {
                                let songs = try await album.with([.tracks]).tracks ?? []
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
                    Text("歌曲列表")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            HStack {
                                Text("\(index + 1)")
                                    .frame(width: 24, alignment: .center)
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
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
                            .onTapGesture {
                                Task {
                                    try await musicService.playTrack(track, in: album)
                                }
                            }
                        }
                    }
                }
                
                // 底部信息
                if let releaseDate = album.releaseDate, !tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("发布于 \(releaseDate.formatted(.dateTime.year().month().day()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let totalDuration = tracks.reduce(0) { $0 + ($1.duration ?? 0) }
                        Text("\(tracks.count) 首歌曲 • \(formattedDuration(totalDuration))")
                            .font(.caption)
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
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    let album = Album(
        id: "1",
        title: "示例专辑",
        artistName: "示例艺术家",
        artwork: nil,
        releaseDate: Date(),
        genreNames: ["流行"]
    )
    
    return AlbumDetailView(album: album)
        .environmentObject(MusicService.shared)
}