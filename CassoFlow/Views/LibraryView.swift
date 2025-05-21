import SwiftUI
import MusicKit

struct LibraryView: View {
    // 选中的分段
    @State private var selectedSegment = 0
    // 专辑列表数据
    @State private var albums: [Album] = []
    
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
                        // 关闭按钮动作
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
                
                // 专辑网格
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150), spacing: 20)
                    ], spacing: 20) {
                        ForEach(albums) { album in
                            AlbumCell(album: album)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .task {
                // 加载专辑数据
                await loadAlbums()
            }
        }
    }
    
    // 加载专辑数据
    private func loadAlbums() async {
        do {
            let status = await MusicAuthorization.request()
            guard status == .authorized else { return }
            
            // 这里暂时使用搜索接口获取一些专辑数据
            // 实际应用中应该从用户的音乐库中获取
            var request = MusicCatalogSearchRequest(term: "Jay Chou", types: [Album.self])
            request.limit = 25
            let response = try await request.response()
            self.albums = response.albums.compactMap { $0 }
        } catch {
            print("Failed to load albums: \(error)")
        }
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

#Preview {
    LibraryView()
}
