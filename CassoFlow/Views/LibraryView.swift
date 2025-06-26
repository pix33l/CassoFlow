import SwiftUI
import MusicKit

// 独立的媒体库数据管理器，避免与播放器状态混淆
class LibraryDataManager: ObservableObject {
    @Published var userAlbums: MusicItemCollection<Album> = []
    @Published var userPlaylists: MusicItemCollection<Playlist> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var subscriptionStatus: MusicSubscription? = nil
    
    @Published var hasLoaded = false
    
    func loadUserLibraryIfNeeded() async {
        guard !hasLoaded else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let status = await MusicAuthorization.request()
        
        guard status == .authorized else {
            await checkSubscriptionStatus()
            await MainActor.run {
                errorMessage = "需要授权才能访问您的音乐库"
                isLoading = false
            }
            return
        }

        await checkSubscriptionStatus()
        
        if let subscription = subscriptionStatus, !subscription.canPlayCatalogContent {
            await MainActor.run {
                errorMessage = "需要 Apple Music 订阅才能使用"
                isLoading = false
            }
            return
        }
        
        // 并行加载专辑和歌单
        async let albums = fetchUserLibraryAlbums()
        async let playlists = fetchUserLibraryPlaylists()
        
        do {
            let (albumsResult, playlistsResult) = try await (albums, playlists)
            
            await MainActor.run {
                userAlbums = albumsResult
                userPlaylists = playlistsResult
                
                if userAlbums.isEmpty && userPlaylists.isEmpty {
                    errorMessage = "您的媒体库是空的\n请先在 Apple Music 中添加一些音乐"
                }
                
                isLoading = false
                hasLoaded = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "加载媒体库失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func checkSubscriptionStatus() async {
        do {
            let subscription = try await MusicSubscription.current
            await MainActor.run {
                self.subscriptionStatus = subscription
            }
        } catch {
            // 静默处理错误
        }
    }
    
    private func fetchUserLibraryAlbums() async throws -> MusicItemCollection<Album> {
        var request = MusicLibraryRequest<Album>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 50
        
        let response = try await request.response()
        return response.items
    }

    private func fetchUserLibraryPlaylists() async throws -> MusicItemCollection<Playlist> {
        var request = MusicLibraryRequest<Playlist>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 50
        
        let response = try await request.response()
        return response.items
    }
}

struct LibraryView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var musicService: MusicService
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    
    // 使用独立的数据管理器
    @StateObject private var libraryData = LibraryDataManager()
    
    // 选中的分段
    @State private var selectedSegment = 0
    @State private var showSubscriptionOffer = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 内容视图
                if libraryData.isLoading {
                    ProgressView("正在加载...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = libraryData.errorMessage {
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
                        if musicService.isHapticFeedbackEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        dismiss()
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
            .task {
                await libraryData.loadUserLibraryIfNeeded()
            }
            .musicSubscriptionOffer(
                isPresented: $showSubscriptionOffer,
                options: MusicSubscriptionOffer.Options()
            ) { result in
                // 订阅结果处理
            }
        }
        .navigationViewStyle(.stack) // 确保使用栈式导航
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
    
    private var contentView: some View {
        VStack(spacing: 0) {
            // 分段控制器 - 固定在顶部
            Picker("媒体类型", selection: $selectedSegment) {
                Text("专辑").tag(0)
                Text("歌单").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .onChange(of: selectedSegment) { _, _ in
                if musicService.isHapticFeedbackEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
            
            // 滚动内容区域 - 为每个分段使用独立的视图
            TabView(selection: $selectedSegment) {
                // 专辑视图
                ScrollView {
                    
                    if !storeManager.membershipStatus.isActive {
                        PayLabel()
                            .environmentObject(storeManager)
                            .padding(.top, 20)
                    }
                    
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 110), spacing: 5)],
                        spacing: 20
                    ) {
                        ForEach(libraryData.userAlbums, id: \.id) { album in
                            NavigationLink(destination: MusicDetailView(containerType: .album(album)).environmentObject(musicService)) {
                                AlbumCell(album: album)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .tag(0)
                
                // 播放列表视图
                ScrollView {
                    
                    if !storeManager.membershipStatus.isActive {
                        PayLabel()
                            .environmentObject(storeManager)
                            .padding(.top, 20)
                    }
                    
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 110), spacing: 5)],
                        spacing: 20
                    ) {
                        ForEach(libraryData.userPlaylists, id: \.id) { playlist in
                                NavigationLink(destination: MusicDetailView(containerType: .playlist(playlist)).environmentObject(musicService)) {
                                    PlaylistCell(playlist: playlist)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: selectedSegment)
        }
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
                await libraryData.loadUserLibraryIfNeeded()
            }
        }
    }
    
    private func requestAuthorizationAndReload() async {
        let status = await MusicAuthorization.request()
        if status == .authorized {
            await libraryData.loadUserLibraryIfNeeded()
        } else {
            await MainActor.run {
                openAppSettings()
            }
        }
    }
    
    private func openAppleMusic() {
        if let url = URL(string: "music://") {
            UIApplication.shared.open(url)
        }
    }

    private func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl) { _ in }
        }
    }
}

struct AlbumCell: View {
    let album: Album
    
    var body: some View {
        VStack(alignment: .leading) {
            // 专辑封面
            ZStack {
                // 使用 MusicKit 的 ArtworkImage 替代 AsyncImage
                if let artwork = album.artwork {
                    ArtworkImage(artwork, width: 160, height: 160)
                        .frame(width: 105, height: 160)
                        .clipShape(Rectangle())
                } else {
                    ZStack{
                        Color.black
                        Image("CASSOFLOW")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 75)
                    }
                    .frame(width: 105, height: 160)
                    .clipShape(Rectangle())
                }
                
                Image("package-cassette")
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

struct PlaylistCell: View {
    let playlist: Playlist
    
    var body: some View {
        VStack(alignment: .leading) {
            // 歌单封面
            ZStack {
                // 使用 MusicKit 的 ArtworkImage 替代 AsyncImage
                if let artwork = playlist.artwork {
                    ArtworkImage(artwork, width: 160, height: 160)
                        .frame(width: 105, height: 160)
                        .clipShape(Rectangle())
                } else {
                    ZStack{
                        Color.black
                        Image("CASSOFLOW")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 75)
                    }
                    .frame(width: 105, height: 160)
                    .clipShape(Rectangle())
                }
                
                Image("package-cassette")
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
