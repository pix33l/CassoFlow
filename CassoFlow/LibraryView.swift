import SwiftUI
import MusicKit

struct LibraryView: View {
    @EnvironmentObject var musicPlayer: MusicPlayerService
    @State private var searchText = ""
    
    var filteredTracks: [Track] {
        if searchText.isEmpty {
            return musicPlayer.musicCatalog
        } else {
            return musicPlayer.musicCatalog.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if musicPlayer.musicCatalog.isEmpty {
                    emptyStateView
                } else {
                    musicListView
                }
            }
            .navigationTitle("音乐库")
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "没有找到音乐",
            systemImage: "music.note",
            description: Text("请确保已授权访问Apple Music")
        )
    }
    
    private var musicListView: some View {
        List(filteredTracks) { track in
            TrackRow(track: track)
                .onTapGesture {
                    Task { await musicPlayer.play(track: track) }
                }
        }
        .searchable(text: $searchText, prompt: "搜索歌曲或艺人")
    }
}

struct TrackRow: View {
    let track: Track
    
    var body: some View {
        HStack {
            if let artwork = track.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .frame(width: 50, height: 50)
                    .cornerRadius(4)
            } else {
                Image(systemName: "music.note")
                    .frame(width: 50, height: 50)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading) {
                Text(track.title)
                    .font(.headline)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// 预览提供不同状态
#Preview("有音乐") {
    let musicPlayer = MusicPlayerService()
    musicPlayer.musicCatalog = [
        Track(id: "1", title: "夜曲", artist: "周杰伦", artwork: nil),
        Track(id: "2", title: "稻香", artist: "周杰伦", artwork: nil),
        Track(id: "3", title: "青花瓷", artist: "周杰伦", artwork: nil)
    ]
    return LibraryView()
        .environmentObject(musicPlayer)
}

#Preview("空状态") {
    let musicPlayer = MusicPlayerService()
    musicPlayer.musicCatalog = []
    return LibraryView()
        .environmentObject(musicPlayer)
}

#Preview("歌曲行") {
    TrackRow(track: Track(
        id: "1",
        title: "示例歌曲",
        artist: "示例艺人",
        artwork: nil
    ))
    .previewLayout(.sizeThatFits)
}
