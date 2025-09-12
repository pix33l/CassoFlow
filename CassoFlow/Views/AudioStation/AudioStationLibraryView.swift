import SwiftUI

struct AudioStationLibraryView: View {
    @EnvironmentObject private var musicService: MusicService
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    
    // 数据管理器
    @StateObject private var libraryData = AudioStationLibraryDataManager()
    @StateObject private var preferences = AudioStationLibraryPreferences()
    
    // UI状态
    @State private var selectedSegment = 0 // 0: 专辑, 1: 播放列表, 2: 艺术家
    @State private var albumSearchText = ""
    @State private var playlistSearchText = ""
    @State private var artistSearchText = ""
    @State private var showPaywall = false
    @State private var showAudioStationSettings = false
    
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
                // 连接状态检查
                if !musicService.getAudioStationService().isConnected {
                    connectionErrorView
                } else if libraryData.isLoading {
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
                                MusicDetailCacheManager.shared.clearAllCache()
                                ImageCacheManager.shared.clearCache()
                                AudioStationLibraryDataManager.clearSharedCache()
                            }
                            // 重新加载库数据
                            await libraryData.reloadLibrary(audioStationService: musicService.getAudioStationService())
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
                await libraryData.loadLibraryIfNeeded(audioStationService: musicService.getAudioStationService())
            }
            .sheet(isPresented: $showAudioStationSettings) {
                AudioStationSettingsView()
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
            Image("Audio-Station")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
            
            Text("Audio Station 服务器未连接")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("请检查服务器配置和网络连接")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Button(action: {
                    showAudioStationSettings = true
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
                        await libraryData.testConnection(audioStationService: musicService.getAudioStationService())
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
                        MusicDetailCacheManager.shared.clearAllCache()
                        ImageCacheManager.shared.clearCache()
                        AudioStationLibraryDataManager.clearSharedCache()
                    }
                    await libraryData.reloadLibrary(audioStationService: musicService.getAudioStationService())
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
                    ForEach(AudioStationSortType.allCases, id: \.self) { sortType in
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
                                AudioStationGridAlbumCell(album: album)
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
                                AudioStationListAlbumCell(album: album)
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
                                AudioStationGridPlaylistCell(playlist: playlist)
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
                                AudioStationListPlaylistCell(playlist: playlist)
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
                            AudioStationArtistCell(artist: artist)
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
            
            Text("您的Audio Station服务器上暂无此类内容")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal)
    }
}

// MARK: - Audio Station音乐库数据管理器

// Audio Station 专用的排序类型
enum AudioStationSortType: String, CaseIterable {
    case newest = "newest"          // 最新添加
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

// Audio Station 图书馆偏好设置管理器
class AudioStationLibraryPreferences: ObservableObject {
    private let sortTypeKey = "AudioStationLibrarySortType"
    private let displayModeKey = "AudioStationLibraryDisplayMode"
    
    @Published var currentSortType: AudioStationSortType {
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
        let savedSortType = UserDefaults.standard.string(forKey: sortTypeKey) ?? AudioStationSortType.newest.rawValue
        self.currentSortType = AudioStationSortType(rawValue: savedSortType) ?? .newest
        
        self.isGridMode = UserDefaults.standard.object(forKey: displayModeKey) as? Bool ?? true
    }
}

class AudioStationLibraryDataManager: ObservableObject {
    @Published var albums: [UniversalAlbum] = []
    @Published var playlists: [UniversalPlaylist] = []
    @Published var artists: [UniversalArtist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasLoaded = false
    
    // 使用新的音乐库缓存管理器
    @MainActor private let libraryCache = MusicLibraryCacheManager.shared
    
    // 保存原始未排序的数据
    private var originalAlbums: [UniversalAlbum] = []
    private var originalPlaylists: [UniversalPlaylist] = []
    private var originalArtists: [UniversalArtist] = []
    
    func loadLibraryIfNeeded(audioStationService: AudioStationMusicService) async {
        // 如果已经加载过，直接返回
        if hasLoaded {
            return
        }
        
        // 检查新的缓存系统
        if let cachedData = await libraryCache.getCachedLibraryData(for: "AudioStation") {
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
                
                print("📚 使用缓存的AudioStation库数据")
            }
            
            // 后台检查是否需要刷新
            if await libraryCache.shouldRefreshLibraryCache(for: "AudioStation") {
                await libraryCache.backgroundRefreshLibraryData(for: "AudioStation") {
                    try await self.loadFreshLibraryData(audioStationService: audioStationService)
                }
            }
            
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // 检查连接状态
        let isConnected = await audioStationService.checkAvailability()
        guard isConnected else {
            await MainActor.run {
                errorMessage = "无法连接到Audio Station服务器"
                isLoading = false
            }
            return
        }
        
        do {
            // 并行加载数据
            async let albumsTask = audioStationService.getRecentAlbums()
            async let playlistsTask = audioStationService.getPlaylists()
            async let artistsTask = audioStationService.getArtists()
            
            let (albumsResult, playlistsResult, artistsResult) = try await (albumsTask, playlistsTask, artistsTask)
            
            // 添加调试信息
            print("Albums loaded: \(albumsResult.count)")
            print("Playlists loaded: \(playlistsResult.count)")
            print("Artists loaded: \(artistsResult.count)")
            
            await MainActor.run {
                self.albums = albumsResult
                self.playlists = playlistsResult
                self.artists = artistsResult
                self.originalAlbums = albumsResult
                self.originalPlaylists = playlistsResult
                self.originalArtists = artistsResult
                self.isLoading = false
                self.hasLoaded = true
                
                // 使用新的缓存系统
                libraryCache.cacheLibraryData(
                    albums: albumsResult,
                    playlists: playlistsResult,
                    artists: artistsResult,
                    for: "AudioStation"
                )
                
                if albumsResult.isEmpty && playlistsResult.isEmpty && artistsResult.isEmpty {
                    self.errorMessage = "Audio Station服务器上没有找到音乐内容"
                }
            }
            
            // 使用新的预加载系统
            await libraryCache.preloadLibraryData(
                albums: albumsResult,
                playlists: playlistsResult,
                artists: artistsResult,
                audioStationService: audioStationService
            )
        } catch {
            // 添加更详细的错误信息
            print("Library loading error: \(error)")
            await MainActor.run {
                self.errorMessage = "加载音乐库失败：\(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// 应用排序
    func applySorting(_ sortType: AudioStationSortType) async {
        await MainActor.run {
            // 对专辑排序
            switch sortType {
            case .newest:
                albums = originalAlbums // Audio Station通常已按最新排序
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
    private func loadFreshLibraryData(audioStationService: AudioStationMusicService) async throws -> (albums: [UniversalAlbum], playlists: [UniversalPlaylist], artists: [UniversalArtist]) {
        // 并行加载数据
        async let albumsTask = audioStationService.getRecentAlbums()
        async let playlistsTask = audioStationService.getPlaylists()
        async let artistsTask = audioStationService.getArtists()
        
        let (albumsResult, playlistsResult, artistsResult) = try await (albumsTask, playlistsTask, artistsTask)
        
        print("🔄 后台刷新数据 - Albums: \(albumsResult.count), Playlists: \(playlistsResult.count), Artists: \(artistsResult.count)")
        
        return (albumsResult, playlistsResult, artistsResult)
    }
    
    func reloadLibrary(audioStationService: AudioStationMusicService) async {
        await MainActor.run {
            hasLoaded = false
            // 清除缓存，强制重新加载
            libraryCache.clearLibraryCache(for: "AudioStation")
        }
        await loadLibraryIfNeeded(audioStationService: audioStationService)
    }
    
    func testConnection(audioStationService: AudioStationMusicService) async {
        await MainActor.run {
            isLoading = true
        }
        
        let isConnected = await audioStationService.checkAvailability()
        
        await MainActor.run {
            isLoading = false
            if isConnected {
                hasLoaded = false
                // 连接测试成功后清除缓存
                libraryCache.clearLibraryCache(for: "AudioStation")
            }
        }
        
        if isConnected {
            await loadLibraryIfNeeded(audioStationService: audioStationService)
        }
    }
    
    /// 清除缓存的类方法
    @MainActor static func clearSharedCache() {
        MusicLibraryCacheManager.shared.clearLibraryCache(for: "AudioStation")
    }
}


// MARK: - 预览

struct AudioStationLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        AudioStationLibraryView()
            .environmentObject(MusicService.shared)
            .environmentObject(StoreManager())
    }
}
