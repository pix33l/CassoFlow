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
    @State private var closeTapped = false
    @State private var subscriptionStatus: MusicSubscription? = nil
    @State private var showSubscriptionOffer = false
    
    var body: some View {
        NavigationStack {  // 改为 NavigationStack 避免嵌套导航问题
            VStack(spacing: 0) {

                // 内容视图
                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    errorView(message: error)
                } else {
                    contentView
                }
            }
            .navigationTitle("媒体库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        closeTapped.toggle()
                        if musicService.isHapticFeedbackEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
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
            .musicSubscriptionOffer(
                isPresented: $showSubscriptionOffer,
                options: MusicSubscriptionOffer.Options()
            ) { result in
                print("订阅弹窗结果: \(String(describing: result))")
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: getErrorIcon(for: message))
                .font(.system(size: 48))
                .foregroundColor(.red)
                .padding(.bottom, 10)
            
            Text(message)
                .font(.title2)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                
            Text(getErrorDescription(for: message))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                if musicService.isHapticFeedbackEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
                handleErrorAction(for: message)
            } label: {
                Text(getButtonTitle(for: message))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.red)
                    )
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func getErrorIcon(for message: String) -> String {
        switch message {
        case "需要授权才能访问您的音乐库":
            return "music.note.list"
        case "需要 Apple Music 订阅才能使用":
            return "music.note.list"
        case let msg where msg.contains("您的媒体库是空的"):
            return "music.note.list"
        default:
            return "exclamationmark.triangle"
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
            .onChange(of: selectedSegment) { _, _ in
                if musicService.isHapticFeedbackEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }

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
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist)
                                .environmentObject(musicService)
                        } label: {
                            PlaylistCell(playlist: playlist)
                        }
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
                // 授权失败时检查订阅状态
                await checkSubscriptionStatus()
                errorMessage = "需要授权才能访问您的音乐库"
                isLoading = false
                return
            }

            // 检查订阅状态
            await checkSubscriptionStatus()
            
            // 如果用户没有Apple Music订阅，直接显示订阅提示
            if let subscription = subscriptionStatus,
               !subscription.canPlayCatalogContent {
                errorMessage = "需要 Apple Music 订阅才能使用"
                isLoading = false
                return
            }

            // 同时加载专辑和歌单
            async let albums = musicService.fetchUserLibraryAlbums()
            async let playlists = musicService.fetchUserLibraryPlaylists()
            
            let (albumsResult, playlistsResult) = await (try? albums, try? playlists)
            
            userAlbums = albumsResult ?? []
            userPlaylists = playlistsResult ?? []
            
            if userAlbums.isEmpty && userPlaylists.isEmpty {
                errorMessage = "您的媒体库是空的\n请先在 Apple Music 中添加一些音乐"
            }
        } catch {
            await checkSubscriptionStatus()
            errorMessage = "加载媒体库失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func checkSubscriptionStatus() async {
        do {
            // 使用MusicSubscription的静态属性来检查当前订阅状态
            let subscription = try await MusicSubscription.current
            await MainActor.run {
                self.subscriptionStatus = subscription
            }
        } catch {
            print("检查订阅状态失败: \(error)")
        }
    }
    
    private func requestAuthorizationAndReload() async {
        let status = await musicService.requestAuthorization()
        if status == .authorized {
            // 授权成功后重新加载媒体库
            await loadUserLibrary()
        }
    }
    
    private func getErrorDescription(for message: String) -> String {
        switch message {
        case "需要授权才能访问您的音乐库":
            return "允许访问您的 Apple Music 以查看专辑和播放列表"
        case "需要 Apple Music 订阅才能使用":
            return "现在加入 Apple Music，最多可享 3 个月免费试用"
        case let msg where msg.contains("您的媒体库是空的"):
            return "在 Apple Music 中添加专辑和播放列表以开始使用"
        default:
            return "请重试或检查网络连接"
        }
    }
    
    private func getButtonTitle(for message: String) -> String {
        switch message {
        case "需要授权才能访问您的音乐库":
            return "授权访问"
        case "需要 Apple Music 订阅才能使用":
            return "立即体验"
        case let msg where msg.contains("您的媒体库是空的"):
            return "打开 Apple Music"
        default:
            return "重试"
        }
    }
    
    private func handleErrorAction(for message: String) {
        switch message {
        case "需要授权才能访问您的音乐库":
            Task {
                await requestAuthorizationAndReload()
            }
        case "需要 Apple Music 订阅才能使用":
            showSubscriptionOffer = true
        case let msg where msg.contains("您的媒体库是空的"):
            openAppleMusic()
        default:
            Task {
                await loadUserLibrary()
            }
        }
    }
    
    private func openAppleMusic() {
        if let url = URL(string: "music://") {
            UIApplication.shared.open(url)
        }
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

#Preview("加载状态") {
    let musicService = MusicService.shared
    NavigationStack {
        VStack(spacing: 0) {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("媒体库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // 预览中的空操作
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                        )
                }
            }
        }
    }
    .environmentObject(musicService)
}

#Preview("成功状态") {
    let musicService = MusicService.shared
    LibraryView()
        .environmentObject(musicService)
}

#Preview("需要订阅状态") {
    let musicService = MusicService.shared
    NavigationStack {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                Text("需要 Apple Music 订阅才能使用")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 40) {
                    
                    Text("现在加入 Apple Music，最多可享 3 个月免费试用")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        // 预览中的空操作
                    } label: {
                        Text("立即体验")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.red)
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("媒体库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // 预览中的空操作
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                        )
                }
            }
        }
    }
    .environmentObject(musicService)
}

#Preview("授权错误状态") {
    let musicService = MusicService.shared
    NavigationStack {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                Text("需要授权才能访问您的音乐库")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 40) {
                    
                    Text("允许访问您的 Apple Music 以查看专辑和播放列表")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        // 预览中的空操作
                    } label: {
                        Text("授权访问")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.red)
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("媒体库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // 预览中的空操作
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                        )
                }
            }
        }
    }
    .environmentObject(musicService)
}

#Preview("媒体库为空状态") {
    let musicService = MusicService.shared
    NavigationStack {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                Text("您的媒体库是空的\n请先在 Apple Music 中添加一些音乐")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 40) {
                    
                    Text("在 Apple Music 中添加专辑和播放列表以开始使用")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        // 预览中的空操作
                    } label: {
                        Text("打开 Apple Music")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.red)
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("媒体库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // 预览中的空操作
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                        )
                }
            }
        }
    }
    .environmentObject(musicService)
}
