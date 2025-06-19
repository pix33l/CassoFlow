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
    @State private var debugInfo: String = ""
    @State private var showDebugInfo = false
    
    var body: some View {
        NavigationStack {  // 改为 NavigationStack 避免嵌套导航问题
            VStack(spacing: 0) {

                // 内容视图
                if isLoading {
                    VStack {
                        ProgressView()
                        if !debugInfo.isEmpty {
                            Text(debugInfo)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                                .multilineTextAlignment(.center)
                        }
                    }
                } else if let error = errorMessage {
                    errorView(message: error)
                } else {
                    contentView
                }
                
                #if DEBUG
                if !debugInfo.isEmpty {
                    Button("显示调试信息") {
                        showDebugInfo.toggle()
                    }
                    .font(.caption)
                    .padding(.bottom, 5)
                }
                #endif
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
                print("🎵 订阅弹窗结果: \(String(describing: result))")
            }
            .alert("调试信息", isPresented: $showDebugInfo) {
                Button("确定") { }
            } message: {
                Text(debugInfo)
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
        debugInfo = "开始加载媒体库..."
        
        debugInfo = "检查授权状态..."
        let currentAuth = MusicAuthorization.currentStatus
        print("🎵 当前授权状态: \(currentAuth)")
        
        let status = await musicService.requestAuthorization()
        print("🎵 请求授权后状态: \(status)")
        debugInfo = "授权状态: \(status)"
        
        guard status == .authorized else {
            // 授权失败时检查订阅状态
            await checkSubscriptionStatus()
            errorMessage = "需要授权才能访问您的音乐库"
            isLoading = false
            return
        }

        debugInfo = "检查订阅状态..."
        await checkSubscriptionStatus()
        
        if let subscription = subscriptionStatus {
            print("🎵 订阅状态详情:")
            print("🎵 - canPlayCatalogContent: \(subscription.canPlayCatalogContent)")
            print("🎵 - hasCloudLibraryEnabled: \(subscription.hasCloudLibraryEnabled)")
            debugInfo += "\n订阅详情: canPlay=\(subscription.canPlayCatalogContent), cloud=\(subscription.hasCloudLibraryEnabled)"
            
            // 如果用户没有Apple Music订阅，直接显示订阅提示
            if !subscription.canPlayCatalogContent {
                errorMessage = "需要 Apple Music 订阅才能使用"
                isLoading = false
                return
            }
        } else {
            print("🎵 无法获取订阅状态")
            debugInfo += "\n无法获取订阅状态"
        }

        debugInfo = "开始加载专辑和播放列表..."
        
        // 同时加载专辑和歌单
        async let albums = loadAlbumsWithDetails()
        async let playlists = loadPlaylistsWithDetails()
        
        let (albumsResult, playlistsResult) = await (albums, playlists)
        
        userAlbums = albumsResult
        userPlaylists = playlistsResult
        
        print("🎵 加载结果: \(userAlbums.count) 张专辑, \(userPlaylists.count) 个播放列表")
        debugInfo = "加载完成: \(userAlbums.count) 张专辑, \(userPlaylists.count) 个播放列表"
        
        if userAlbums.isEmpty && userPlaylists.isEmpty {
            errorMessage = "您的媒体库是空的\n请先在 Apple Music 中添加一些音乐"
        }
        
        isLoading = false
    }
    
    private func loadAlbumsWithDetails() async -> MusicItemCollection<Album> {
        do {
            print("🎵 开始获取用户专辑...")
            let albums = try await musicService.fetchUserLibraryAlbums()
            print("🎵 获取到 \(albums.count) 张专辑")
            
            // 检查前几张专辑的详细信息
            for (index, album) in albums.prefix(3).enumerated() {
                print("🎵 专辑 \(index + 1): \(album.title) - \(album.artistName)")
                print("🎵 - ID: \(album.id)")
                print("🎵 - 封面可用: \(album.artwork != nil)")
                if let artwork = album.artwork {
                    print("🎵 - 封面URL: \(String(describing: artwork.url(width: 300, height: 300)))")
                }
                
                // 尝试获取专辑的歌曲
                do {
                    let detailedAlbum = try await album.with(.tracks)
                    if let tracks = detailedAlbum.tracks {
                        print("🎵 - 歌曲数量: \(tracks.count)")
                        for (trackIndex, track) in tracks.prefix(2).enumerated() {
                            print("🎵   歌曲 \(trackIndex + 1): \(track.title)")
                        }
                    } else {
                        print("🎵 - 无法获取歌曲列表")
                    }
                } catch {
                    print("🎵 - 获取专辑歌曲失败: \(error)")
                }
            }
            
            return albums
        } catch {
            print("🎵 获取专辑失败: \(error)")
            return []
        }
    }
    
    private func loadPlaylistsWithDetails() async -> MusicItemCollection<Playlist> {
        do {
            print("🎵 开始获取用户播放列表...")
            let playlists = try await musicService.fetchUserLibraryPlaylists()
            print("🎵 获取到 \(playlists.count) 个播放列表")
            
            // 检查前几个播放列表的详细信息
            for (index, playlist) in playlists.prefix(3).enumerated() {
                print("🎵 播放列表 \(index + 1): \(playlist.name)")
                print("🎵 - ID: \(playlist.id)")
                print("🎵 - 封面可用: \(playlist.artwork != nil)")
                if let artwork = playlist.artwork {
                    print("🎵 - 封面URL: \(String(describing: artwork.url(width: 300, height: 300)))")
                }
                
                // 尝试获取播放列表的歌曲
                do {
                    let detailedPlaylist = try await playlist.with(.tracks)
                    if let tracks = detailedPlaylist.tracks {
                        print("🎵 - 歌曲数量: \(tracks.count)")
                        for (trackIndex, track) in tracks.prefix(2).enumerated() {
                            print("🎵   歌曲 \(trackIndex + 1): \(track.title)")
                        }
                    } else {
                        print("🎵 - 无法获取歌曲列表")
                    }
                } catch {
                    print("🎵 - 获取播放列表歌曲失败: \(error)")
                }
            }
            
            return playlists
        } catch {
            print("🎵 获取播放列表失败: \(error)")
            return []
        }
    }
    
    private func checkSubscriptionStatus() async {
        print("🎵 检查订阅状态...")
        // 添加重试机制
        var retryCount = 0
        let maxRetries = 3
        
        while retryCount < maxRetries {
            do {
                let subscription = try await MusicSubscription.current
                await MainActor.run {
                    self.subscriptionStatus = subscription
                    print("🎵 订阅状态获取成功")
                }
                return // 成功后退出重试循环
            } catch {
                print("🎵 检查订阅状态失败 (尝试 \(retryCount + 1)/\(maxRetries)): \(error)")
                retryCount += 1
                
                // 如果是权限错误，不要重试
                if let nsError = error as NSError?, nsError.code == -7013 {
                    print("🎵 权限错误，停止重试")
                    break
                }
                
                // 等待后重试
                if retryCount < maxRetries {
                    do {
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
                    } catch {
                        print("🎵 等待失败: \(error)")
                    }
                }
            }
        }
        
        print("🎵 检查订阅状态完全失败: 达到最大重试次数")
    }
    
    private func requestAuthorizationAndReload() async {
        let status = await musicService.requestAuthorization()
        if status == .authorized {
            // 授权成功后重新加载媒体库
            await loadUserLibrary()
        } else {
            // 授权失败，引导用户到设置
            await MainActor.run {
                openAppSettings()
            }
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

    private func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl) { success in
                print("打开设置: \(success)")
            }
        }
    }
}

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
                    ZStack{
                        Color.black
                        Image("CASSOFLOW")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 75)
                    }
                }
                .frame(width: 100, height: 160)
                .clipShape(Rectangle())
                .onAppear {
                    if let artworkURL = album.artwork?.url(width: 300, height: 300) {
                        print("🎵 尝试加载封面: \(album.title) - \(artworkURL)")
                    } else {
                        print("🎵 无封面URL: \(album.title)")
                    }
                }
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
                    ZStack{
                        Color.black
                        Image("CASSOFLOW")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 75)
                    }
                }
                .frame(width: 100, height: 160)
                .clipShape(Rectangle())
                .onAppear {
                    if let artworkURL = playlist.artwork?.url(width: 300, height: 300) {
                        print("🎵 尝试加载播放列表封面: \(playlist.name) - \(artworkURL)")
                    } else {
                        print("🎵 播放列表无封面URL: \(playlist.name)")
                    }
                }
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
    
    // 创建一个带有示例数据的LibraryView
    struct LibraryViewWithMockData: View {
        @State private var selectedSegment = 0
        @State private var userAlbums: [MockAlbum] = [
            MockAlbum(id: "1", title: "Folklore", artistName: "Taylor Swift"),
            MockAlbum(id: "2", title: "Blinding Lights", artistName: "The Weeknd"),
            MockAlbum(id: "3", title: "好想爱这个世界啊好想爱这个世界啊", artistName: "华晨宇好想爱这个世界啊"),
            MockAlbum(id: "4", title: "七里香", artistName: "周杰伦"),
            MockAlbum(id: "5", title: "千与千寻", artistName: "久石让"),
            MockAlbum(id: "6", title: "Bad Habits", artistName: "Ed Sheeran")
        ]
        @State private var userPlaylists: [MockPlaylist] = [
            MockPlaylist(id: "1", name: "我的最爱"),
            MockPlaylist(id: "2", name: "健身音乐"),
            MockPlaylist(id: "3", name: "深夜电台"),
            MockPlaylist(id: "4", name: "开车专用"),
            MockPlaylist(id: "5", name: "经典老歌"),
            MockPlaylist(id: "6", name: "学习背景音乐")
        ]
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
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
                                ForEach(userAlbums, id: \.id) { album in
                                    MockAlbumCell(album: album)
                                }
                            } else {
                                ForEach(userPlaylists, id: \.id) { playlist in
                                    MockPlaylistCell(playlist: playlist)
                                }
                            }
                        }
                        .padding()
                    }
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
        }
    }
    
    // 示例数据结构
    struct MockAlbum {
        let id: String
        let title: String
        let artistName: String
    }
    
    struct MockPlaylist {
        let id: String
        let name: String
    }
    
    // 示例专辑单元格
    struct MockAlbumCell: View {
        let album: MockAlbum
        
        var body: some View {
            VStack(alignment: .leading) {
                // 专辑封面
                ZStack {
                    ZStack{
                        Color.black
                        Image("CASSOFLOW")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 75)
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
    
    // 示例歌单单元格
    struct MockPlaylistCell: View {
        let playlist: MockPlaylist
        
        var body: some View {
            VStack(alignment: .leading) {
                // 歌单封面
                ZStack {
                    Color.gray
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
    
    return LibraryViewWithMockData()
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
