import SwiftUI

/// Subsonic音乐库视图
struct SubsonicLibraryView: View {
    @EnvironmentObject private var musicService: MusicService
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    
    // 数据管理器
    @StateObject private var libraryData = SubsonicLibraryDataManager()
    @StateObject private var preferences = SubsonicLibraryPreferences()
    
    // UI状态
    @State private var selectedSegment = 0 // 0: 专辑, 1: 播放列表, 2: 艺术家
    @State private var albumSearchText = ""
    @State private var playlistSearchText = ""
    @State private var artistSearchText = ""
    @State private var showPaywall = false
    @State private var showSubsonicSettings = false
    
    // 过滤后的数据
    private var filteredAlbums: [UniversalAlbum] {
        if albumSearchText.isEmpty {
            return libraryData.albums
        } else {
            return libraryData.albums.filter { album in
                album.title.localizedCaseInsensitiveContains(albumSearchText) ||
                album.artistName.localizedCaseInsensitiveContains(albumSearchText)
            }
        }
    }
    
    private var filteredPlaylists: [UniversalPlaylist] {
        if playlistSearchText.isEmpty {
            return libraryData.playlists
        } else {
            return libraryData.playlists.filter { playlist in
                playlist.name.localizedCaseInsensitiveContains(playlistSearchText)
            }
        }
    }
    
    private var filteredArtists: [UniversalArtist] {
        if artistSearchText.isEmpty {
            return libraryData.artists
        } else {
            return libraryData.artists.filter { artist in
                artist.name.localizedCaseInsensitiveContains(artistSearchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 优先显示缓存内容，连接状态检查放到后台
                if libraryData.isLoading && libraryData.albums.isEmpty && libraryData.playlists.isEmpty && libraryData.artists.isEmpty {
                    ProgressView("正在加载...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = libraryData.errorMessage, libraryData.albums.isEmpty && libraryData.playlists.isEmpty && libraryData.artists.isEmpty {
                    // 只有在没有缓存数据且有错误时才显示错误
                    if !musicService.getSubsonicService().isConnected {
                        connectionErrorView
                    } else {
                        errorView(message: error)
                    }
                } else if libraryData.albums.isEmpty && libraryData.playlists.isEmpty && libraryData.artists.isEmpty && !libraryData.hasLoaded {
                    // 没有数据且未加载过，显示连接检查
                    if !musicService.getSubsonicService().isConnected {
                        connectionErrorView
                    } else {
                        ProgressView("正在加载...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    // 有数据或已加载过，显示内容
                    contentView
                }
            }
            .navigationTitle("媒体库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
                ToolbarItem(placement: .navigationBarLeading) {
                    // 刷新按钮
                    Button(action: {
                        if musicService.isHapticFeedbackEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        
                        Task {
                            // 清除所有缓存
                            await MainActor.run {
                                MusicLibraryCacheManager.shared.clearAllCache()
                            }
                            // 强制刷新库数据
                            await libraryData.forceRefresh(subsonicService: musicService.getSubsonicService())
                        }
                    }) {
                        Image(systemName: "arrow.trianglehead.2.counterclockwise")
                            .foregroundColor(.primary)
                            .font(.body)
                    }
                    .disabled(libraryData.isLoading)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 关闭按钮
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
                // 启动时立即尝试加载缓存，不等待连接检查
                await libraryData.loadLibraryIfNeeded(subsonicService: musicService.getSubsonicService())
            }
            .sheet(isPresented: $showSubsonicSettings) {
                SubsonicSettingsView()
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(storeManager)
            }
        }
    }
    
    // MARK: - 连接错误视图
    
    private var connectionErrorView: some View {
        VStack(spacing: 20) {
            Image("Subsonic")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 96, height: 48)
            
            Text("Subsonic 服务器未连接")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("请检查服务器配置和网络连接")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Button(action: {
                    showSubsonicSettings = true
                }) {
                    Text("配置服务器")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.yellow)
                        )
                }
                
                Button(action: {
                    Task {
                        await libraryData.testConnection(subsonicService: musicService.getSubsonicService())
                    }
                }) {
                    Text("重新连接")
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - 错误视图
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("加载失败")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    // 清除所有缓存
                    await MainActor.run {
                        MusicLibraryCacheManager.shared.clearAllCache()
                    }
                    await libraryData.reloadLibrary(subsonicService: musicService.getSubsonicService())
                }
            }) {
                Text("重试")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - 主内容视图
    
    private var contentView: some View {
        VStack(spacing: 0) {
            // 控制栏
            HStack {
                // 排序菜单
                Menu {
                    ForEach(SubsonicSortType.allCases, id: \.self) { sortType in
                        Button {
                            if musicService.isHapticFeedbackEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                            preferences.currentSortType = sortType
                            Task {
                                await libraryData.applySorting(sortType)
                            }
                        } label: {
                            if preferences.currentSortType == sortType {
                                Label(sortType.localizedName, systemImage: "checkmark")
                            } else {
                                Text(sortType.localizedName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                    )
                }
                .disabled(libraryData.isLoading)
                
                // 分段控制器
                Picker("内容类型", selection: $selectedSegment) {
                    Text("专辑").tag(0)
                    Text("播放列表").tag(1)
                    Text("艺术家").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedSegment) { _, _ in
                    if musicService.isHapticFeedbackEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }
                
                // 显示模式切换
                Button {
                    if musicService.isHapticFeedbackEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        preferences.isGridMode.toggle()
                    }
                } label: {
                    Image(systemName: preferences.isGridMode ? "rectangle.grid.3x2" : "rectangle.grid.1x2")
                        .foregroundColor(.secondary)
                        .font(.body)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            
            // 内容区域
            TabView(selection: $selectedSegment) {
                // 专辑视图
                albumsView.tag(0)
                
                // 播放列表视图
                playlistsView.tag(1)
                
                // 艺术家视图
                artistsView.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
    
    // MARK: - 专辑视图
    
    private var albumsView: some View {
        ScrollView {
            // 搜索框
            searchBarView(searchText: $albumSearchText, placeholder: "搜索专辑")
            
            if !storeManager.membershipStatus.isActive {
                PayLabel()
                    .environmentObject(storeManager)
                    .padding(.top, 8)
            }
            
            if filteredAlbums.isEmpty && !albumSearchText.isEmpty {
                emptySearchView(message: "未找到匹配的专辑")
            } else if filteredAlbums.isEmpty {
                emptyLibraryView(message: "暂无专辑", systemImage: "opticaldisc")
            } else {
                if preferences.isGridMode {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 5)], spacing: 20) {
                        ForEach(filteredAlbums, id: \.id) { album in
                            NavigationLink(destination: UniversalMusicDetailView(album: album).environmentObject(musicService)) {
                                SubsonicGridAlbumCell(album: album)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 360))], spacing: 12) {
                        ForEach(filteredAlbums, id: \.id) { album in
                            NavigationLink(destination: UniversalMusicDetailView(album: album).environmentObject(musicService)) {
                                SubsonicListAlbumCell(album: album)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    // MARK: - 播放列表视图
    
    private var playlistsView: some View {
        ScrollView {
            // 搜索框
            searchBarView(searchText: $playlistSearchText, placeholder: "搜索播放列表")
            
            if !storeManager.membershipStatus.isActive {
                PayLabel()
                    .environmentObject(storeManager)
                    .padding(.top, 8)
            }
            
            if filteredPlaylists.isEmpty && !playlistSearchText.isEmpty {
                emptySearchView(message: "未找到匹配的播放列表")
            } else if filteredPlaylists.isEmpty {
                emptyLibraryView(message: "暂无播放列表", systemImage: "music.note.list")
            } else {
                if preferences.isGridMode {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 5)], spacing: 20) {
                        ForEach(filteredPlaylists, id: \.id) { playlist in
                            NavigationLink(destination: UniversalMusicDetailView(playlist: playlist).environmentObject(musicService)) {
                                SubsonicGridPlaylistCell(playlist: playlist)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 360))], spacing: 12) {
                        ForEach(filteredPlaylists, id: \.id) { playlist in
                            NavigationLink(destination: UniversalMusicDetailView(playlist: playlist).environmentObject(musicService)) {
                                SubsonicListPlaylistCell(playlist: playlist)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    // MARK: - 艺术家视图
    
    private var artistsView: some View {
        ScrollView {
            // 搜索框
            searchBarView(searchText: $artistSearchText, placeholder: "搜索艺术家")
            
            if !storeManager.membershipStatus.isActive {
                PayLabel()
                    .environmentObject(storeManager)
                    .padding(.top, 8)
            }
            
            if filteredArtists.isEmpty && !artistSearchText.isEmpty {
                emptySearchView(message: "未找到匹配的艺术家")
            } else if filteredArtists.isEmpty {
                emptyLibraryView(message: "暂无艺术家", systemImage: "person.fill")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360))], spacing: 12) {
                    ForEach(filteredArtists, id: \.id) { artist in
                        NavigationLink(destination: UniversalMusicDetailView(artist: artist).environmentObject(musicService)) {
                            SubsonicArtistCell(artist: artist)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - 辅助视图
    
    private func searchBarView(searchText: Binding<String>, placeholder: String) -> some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)
                
                TextField(placeholder, text: searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                
                if !searchText.wrappedValue.isEmpty {
                    Button {
                        searchText.wrappedValue = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .cornerRadius(10)
            
            if !searchText.wrappedValue.isEmpty {
                Button("取消") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    searchText.wrappedValue = ""
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private func emptySearchView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.yellow)
            
            Text(message)
                .font(.title3)
                .foregroundColor(.primary)
            
            Text("请尝试使用不同的关键词搜索")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal)
    }
    
    private func emptyLibraryView(message: String, systemImage: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(.yellow)
            
            Text(message)
                .font(.title3)
                .foregroundColor(.primary)
            
            Text("您的Subsonic服务器上暂无此类内容")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal)
    }
}

// MARK: - Subsonic音乐库数据管理器

// Subsonic 专用的排序类型
enum SubsonicSortType: String, CaseIterable {
    case newest = "newest"          // 最新添加 (对应 Subsonic API 中的 newest)
    case alphabeticalByName = "alphabeticalByName"  // 按专辑名称
    case alphabeticalByArtist = "alphabeticalByArtist" // 按艺术家名称
    
    var localizedName: String {
        switch self {
        case .newest:
            return "最近添加"
        case .alphabeticalByName:
            return "专辑"
        case .alphabeticalByArtist:
            return "艺术家"
        }
    }
}

//// 缓存数据结构
//struct SubsonicLibraryCacheData: Codable {
//    let albums: [CachedAlbum]
//    let playlists: [CachedPlaylist]
//    let artists: [CachedArtist]
//    let timestamp: Date
//    
//    var isExpired: Bool {
//        let cacheValidityDuration: TimeInterval = 1440 * 60 // 24小时缓存有效期
//        return Date().timeIntervalSince(timestamp) > cacheValidityDuration
//    }
//    
//    var isStale: Bool {
//        let staleThreshold: TimeInterval = 60 * 60 // 1小时后开始后台更新
//        return Date().timeIntervalSince(timestamp) > staleThreshold
//    }
//}
//
//// 简化的缓存模型 - 只保存必要信息
//struct CachedAlbum: Codable, Identifiable {
//    let id: String
//    let title: String
//    let artistName: String
//    let year: Int?
//    let genre: String?
//    let songCount: Int
//    let duration: TimeInterval
//    let artworkURL: URL?
//    let source: String
//    
//    init(from album: UniversalAlbum) {
//        self.id = album.id
//        self.title = album.title
//        self.artistName = album.artistName
//        self.year = album.year
//        self.genre = album.genre
//        self.songCount = album.songCount
//        self.duration = album.duration
//        self.artworkURL = album.artworkURL
//        self.source = album.source.rawValue
//    }
//    
//    func toUniversalAlbum() -> UniversalAlbum {
//        UniversalAlbum(
//            id: id,
//            title: title,
//            artistName: artistName,
//            year: year,
//            genre: genre,
//            songCount: songCount,
//            duration: duration,
//            artworkURL: artworkURL,
//            songs: [], // 缓存中不保存歌曲详情
//            source: MusicDataSourceType(rawValue: source) ?? .subsonic,
//            originalData: () // 使用空元组作为占位符
//        )
//    }
//}
//
//struct CachedPlaylist: Codable, Identifiable {
//    let id: String
//    let name: String
//    let curatorName: String?
//    let songCount: Int
//    let duration: TimeInterval
//    let artworkURL: URL?
//    let source: String
//    
//    init(from playlist: UniversalPlaylist) {
//        self.id = playlist.id
//        self.name = playlist.name
//        self.curatorName = playlist.curatorName
//        self.songCount = playlist.songCount
//        self.duration = playlist.duration
//        self.artworkURL = playlist.artworkURL
//        self.source = playlist.source.rawValue
//    }
//    
//    func toUniversalPlaylist() -> UniversalPlaylist {
//        UniversalPlaylist(
//            id: id,
//            name: name,
//            curatorName: curatorName,
//            songCount: songCount,
//            duration: duration,
//            artworkURL: artworkURL,
//            songs: [], // 缓存中不保存歌曲详情
//            source: MusicDataSourceType(rawValue: source) ?? .subsonic,
//            originalData: () // 使用空元组作为占位符
//        )
//    }
//}
//
//struct CachedArtist: Codable, Identifiable {
//    let id: String
//    let name: String
//    let albumCount: Int
//    let source: String
//    
//    init(from artist: UniversalArtist) {
//        self.id = artist.id
//        self.name = artist.name
//        self.albumCount = artist.albumCount
//        self.source = artist.source.rawValue
//    }
//    
//    func toUniversalArtist() -> UniversalArtist {
//        UniversalArtist(
//            id: id,
//            name: name,
//            albumCount: albumCount,
//            albums: [], // 缓存中不保存专辑详情
//            source: MusicDataSourceType(rawValue: source) ?? .subsonic,
//            originalData: () // 使用空元组作为占位符
//        )
//    }
//}

// Subsonic 图书馆偏好设置管理器
class SubsonicLibraryPreferences: ObservableObject {
    private let sortTypeKey = "SubsonicLibrarySortType"
    private let displayModeKey = "SubsonicLibraryDisplayMode"
    
    @Published var currentSortType: SubsonicSortType {
        didSet {
            UserDefaults.standard.set(currentSortType.rawValue, forKey: sortTypeKey)
        }
    }
    
    @Published var isGridMode: Bool {
        didSet {
            UserDefaults.standard.set(isGridMode, forKey: displayModeKey)
        }
    }
    
    init() {
        let savedSortType = UserDefaults.standard.string(forKey: sortTypeKey) ?? SubsonicSortType.newest.rawValue
        self.currentSortType = SubsonicSortType(rawValue: savedSortType) ?? .newest
        
        self.isGridMode = UserDefaults.standard.object(forKey: displayModeKey) as? Bool ?? true
    }
}

class SubsonicLibraryDataManager: ObservableObject {
    @Published var albums: [UniversalAlbum] = []
    @Published var playlists: [UniversalPlaylist] = []
    @Published var artists: [UniversalArtist] = []
    @Published var isLoading = false
    @Published var isBackgroundRefreshing = false // 后台刷新状态
    @Published var errorMessage: String?
    @Published var hasLoaded = false
    @Published var lastUpdateTime: Date?
    
    // 使用新的音乐库缓存管理器
    @MainActor private let libraryCache = MusicLibraryCacheManager.shared
    
    // 保存原始未排序的数据
    private var originalAlbums: [UniversalAlbum] = []
    private var originalPlaylists: [UniversalPlaylist] = []
    private var originalArtists: [UniversalArtist] = []
    
    func loadLibraryIfNeeded(subsonicService: SubsonicMusicService) async {
        // 如果已经加载过内存数据，直接返回
        if hasLoaded && !albums.isEmpty {
            // 检查是否需要后台刷新
            if await libraryCache.shouldRefreshLibraryCache(for: "Subsonic") && !isBackgroundRefreshing {
                await performBackgroundRefresh(subsonicService: subsonicService)
            }
            return
        }
        
        // 检查新的缓存系统
        if let cachedData = await libraryCache.getCachedLibraryData(for: "Subsonic") {
            await MainActor.run {
                self.albums = cachedData.albums
                self.playlists = cachedData.playlists
                self.artists = cachedData.artists
                self.originalAlbums = cachedData.albums
                self.originalPlaylists = cachedData.playlists
                self.originalArtists = cachedData.artists
                self.hasLoaded = true
                self.isLoading = false
                self.errorMessage = nil
                self.lastUpdateTime = Date()
                
                print("📚 使用缓存的Subsonic库数据")
            }
            
            // 后台检查是否需要刷新
            if await libraryCache.shouldRefreshLibraryCache(for: "Subsonic") && !isBackgroundRefreshing {
                await libraryCache.backgroundRefreshLibraryData(for: "Subsonic") {
                    try await self.loadFreshLibraryData(subsonicService: subsonicService)
                }
            }
            
            return
        }
        
        // 没有可用缓存，执行完整加载
        await performFullLoad(subsonicService: subsonicService)
    }
    
    /// 执行完整加载
    private func performFullLoad(subsonicService: SubsonicMusicService) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // 检查连接状态
        let isConnected = await subsonicService.checkAvailability()
        guard isConnected else {
            await MainActor.run {
                errorMessage = "无法连接到Subsonic服务器"
                isLoading = false
            }
            return
        }
        
        do {
            // 并行加载数据
            async let albumsTask = subsonicService.getRecentAlbums()
            async let playlistsTask = subsonicService.getPlaylists()
            async let artistsTask = subsonicService.getArtists()
            
            let (albumsResult, playlistsResult, artistsResult) = try await (albumsTask, playlistsTask, artistsTask)
            
            // 添加调试信息
            print("🔄 完整加载音乐库 - Albums: \(albumsResult.count), Playlists: \(playlistsResult.count), Artists: \(artistsResult.count)")
            
            await MainActor.run {
                self.albums = albumsResult
                self.playlists = playlistsResult
                self.artists = artistsResult
                self.originalAlbums = albumsResult
                self.originalPlaylists = playlistsResult
                self.originalArtists = artistsResult
                self.isLoading = false
                self.hasLoaded = true
                self.lastUpdateTime = Date()
                
                // 使用新的缓存系统
                libraryCache.cacheLibraryData(
                    albums: albumsResult,
                    playlists: playlistsResult,
                    artists: artistsResult,
                    for: "Subsonic"
                )
                
                if albumsResult.isEmpty && playlistsResult.isEmpty && artistsResult.isEmpty {
                    self.errorMessage = "Subsonic服务器上没有找到音乐内容"
                }
            }
            
            // 使用新的预加载系统
            await libraryCache.preloadLibraryData(
                albums: albumsResult,
                playlists: playlistsResult,
                artists: artistsResult,
                subsonicService: subsonicService
            )
        } catch {
            // 添加更详细的错误信息
            print("❌ 音乐库加载失败: \(error)")
            await MainActor.run {
                self.errorMessage = "加载音乐库失败：\(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// 执行后台刷新
    private func performBackgroundRefresh(subsonicService: SubsonicMusicService) async {
        await MainActor.run {
            isBackgroundRefreshing = true
        }
        
        print("🔄 开始后台刷新音乐库数据...")
        
        // 检查连接状态（静默检查，不影响用户界面）
        let isConnected = await subsonicService.checkAvailability()
        guard isConnected else {
            print("⚠️ 后台刷新跳过：服务器不可用")
            await MainActor.run {
                isBackgroundRefreshing = false
            }
            return
        }
        
        do {
            // 并行加载新数据
            async let albumsTask = subsonicService.getRecentAlbums()
            async let playlistsTask = subsonicService.getPlaylists()
            async let artistsTask = subsonicService.getArtists()
            
            let (newAlbums, newPlaylists, newArtists) = try await (albumsTask, playlistsTask, artistsTask)
            
            // 检查数据是否有变化
            let hasChanges = await MainActor.run {
                return !self.isDataEqual(
                    newAlbums: newAlbums,
                    newPlaylists: newPlaylists,
                    newArtists: newArtists
                )
            }
            
            if hasChanges {
                print("✅ 检测到数据更新，应用新数据")
                await MainActor.run {
                    // 平滑更新数据
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.albums = newAlbums
                        self.playlists = newPlaylists
                        self.artists = newArtists
                        self.originalAlbums = newAlbums
                        self.originalPlaylists = newPlaylists
                        self.originalArtists = newArtists
                        self.lastUpdateTime = Date()
                    }
                    
                    // 更新缓存
                    libraryCache.cacheLibraryData(
                        albums: newAlbums,
                        playlists: newPlaylists,
                        artists: newArtists,
                        for: "Subsonic"
                    )
                    
                    // 清除错误信息
                    self.errorMessage = nil
                }
                
                // 使用新的预加载系统
                await libraryCache.preloadLibraryData(
                    albums: newAlbums,
                    playlists: newPlaylists,
                    artists: newArtists,
                    subsonicService: subsonicService
                )
            } else {
                print("📦 数据无变化，更新缓存时间戳")
                // 数据无变化，仅更新缓存时间戳
                await MainActor.run {
                    self.lastUpdateTime = Date()
                    // 清除错误信息，因为连接是正常的
                    self.errorMessage = nil
                }
            }
            
        } catch {
            print("⚠️ 后台刷新失败: \(error)")
            // 后台刷新失败不应该影响当前显示的缓存内容
            // 只在没有任何数据时才设置错误消息
            await MainActor.run {
                if self.albums.isEmpty && self.playlists.isEmpty && self.artists.isEmpty {
                    self.errorMessage = "无法连接到Subsonic服务器"
                }
            }
        }
        
        await MainActor.run {
            isBackgroundRefreshing = false
        }
    }
    
    /// 检查数据是否相同
    private func isDataEqual(newAlbums: [UniversalAlbum], newPlaylists: [UniversalPlaylist], newArtists: [UniversalArtist]) -> Bool {
        return albums.count == newAlbums.count &&
               playlists.count == newPlaylists.count &&
               artists.count == newArtists.count &&
               Set(albums.map { $0.id }) == Set(newAlbums.map { $0.id }) &&
               Set(playlists.map { $0.id }) == Set(newPlaylists.map { $0.id }) &&
               Set(artists.map { $0.id }) == Set(newArtists.map { $0.id })
    }
    
    /// 应用排序
    func applySorting(_ sortType: SubsonicSortType) async {
        await MainActor.run {
            // 对专辑排序
            switch sortType {
            case .newest:
                albums = originalAlbums // Subsonic通常已按最新排序
            case .alphabeticalByName:
                albums = originalAlbums.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .alphabeticalByArtist:
                albums = originalAlbums.sorted { $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending }
            }
            
            // 对播放列表排序
            switch sortType {
            case .newest:
                playlists = originalPlaylists
            case .alphabeticalByName:
                playlists = originalPlaylists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            case .alphabeticalByArtist:
                playlists = originalPlaylists.sorted { ($0.curatorName ?? "").localizedCaseInsensitiveCompare($1.curatorName ?? "") == .orderedAscending }
            }
            
            // 对艺术家排序
            switch sortType {
            case .newest:
                artists = originalArtists
            case .alphabeticalByName, .alphabeticalByArtist:
                artists = originalArtists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        }
    }
    
    /// 加载新鲜的库数据（用于后台刷新）
    private func loadFreshLibraryData(subsonicService: SubsonicMusicService) async throws -> (albums: [UniversalAlbum], playlists: [UniversalPlaylist], artists: [UniversalArtist]) {
        // 并行加载数据
        async let albumsTask = subsonicService.getRecentAlbums()
        async let playlistsTask = subsonicService.getPlaylists()
        async let artistsTask = subsonicService.getArtists()
        
        let (albumsResult, playlistsResult, artistsResult) = try await (albumsTask, playlistsTask, artistsTask)
        
        print("🔄 后台刷新数据 - Albums: \(albumsResult.count), Playlists: \(playlistsResult.count), Artists: \(artistsResult.count)")
        
        return (albumsResult, playlistsResult, artistsResult)
    }
    
    func reloadLibrary(subsonicService: SubsonicMusicService) async {
        await MainActor.run {
            hasLoaded = false
            // 清除缓存，强制重新加载
            libraryCache.clearLibraryCache(for: "Subsonic")
        }
        await performFullLoad(subsonicService: subsonicService)
    }
    
    func testConnection(subsonicService: SubsonicMusicService) async {
        await MainActor.run {
            isLoading = true
        }
        
        let isConnected = await subsonicService.checkAvailability()
        
        await MainActor.run {
            isLoading = false
            if isConnected {
                hasLoaded = false
                // 连接测试成功后清除缓存
                libraryCache.clearLibraryCache(for: "Subsonic")
            }
        }
        
        if isConnected {
            await loadLibraryIfNeeded(subsonicService: subsonicService)
        }
    }
    
    /// 强制刷新数据
    func forceRefresh(subsonicService: SubsonicMusicService) async {
        // 清除所有缓存
        await MainActor.run {
            libraryCache.clearLibraryCache(for: "Subsonic")
        }
        
        // 执行完整加载
        await performFullLoad(subsonicService: subsonicService)
    }
    
    /// 清除缓存的类方法
    @MainActor static func clearSharedCache() {
        MusicLibraryCacheManager.shared.clearLibraryCache(for: "Subsonic")
    }
}


// MARK: - 预览

struct SubsonicLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        SubsonicLibraryView()
            .environmentObject(MusicService.shared)
            .environmentObject(StoreManager())
    }
}
