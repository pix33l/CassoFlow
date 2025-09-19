import SwiftUI
import MusicKit

// 排序类型枚举
enum SortType: String, CaseIterable {
    case recentlyAdded = "recentlyAdded"
    case albumTitle = "albumTitle"
    case artistName = "artistName"
    
    var localizedName: String {
        switch self {
        case .recentlyAdded:
            return String(localized: "最近添加")
        case .albumTitle:
            return String(localized: "专辑")
        case .artistName:
            return String(localized: "艺术家")
        }
    }
}

// 用户偏好设置管理器
class LibraryPreferences: ObservableObject {
    // UserDefaults 键名
    private let sortTypeKey = "LibrarySortType"
    private let displayModeKey = "LibraryDisplayMode"
    
    @Published var currentSortType: SortType {
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
        // 从 UserDefaults 读取保存的排序方式
        let savedSortType = UserDefaults.standard.string(forKey: sortTypeKey) ?? SortType.recentlyAdded.rawValue
        self.currentSortType = SortType(rawValue: savedSortType) ?? .recentlyAdded
        
        // 从 UserDefaults 读取保存的显示模式，默认为网格模式
        self.isGridMode = UserDefaults.standard.object(forKey: displayModeKey) as? Bool ?? true
    }
}

// 独立的媒体库数据管理器，避免与播放器状态混淆
class LibraryDataManager: ObservableObject {
    @Published var userAlbums: MusicItemCollection<Album> = []
    @Published var userPlaylists: MusicItemCollection<Playlist> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var subscriptionStatus: MusicSubscription? = nil
    
    @Published var hasLoaded = false
    
    // 添加对偏好设置的引用
    var preferences: LibraryPreferences?
    
    // 音乐服务引用
    private let musicService = MusicService.shared
    
    func loadUserLibraryIfNeeded(with sortType: SortType = .recentlyAdded) async {
        guard !hasLoaded else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let status = await MusicAuthorization.request()
        
        guard status == .authorized else {
            await checkSubscriptionStatus()
            await MainActor.run {
                errorMessage = String(localized: "需要授权才能访问您的媒体库")
                isLoading = false
            }
            return
        }

        await checkSubscriptionStatus()
        
        if let subscription = subscriptionStatus, !subscription.canPlayCatalogContent {
            await MainActor.run {
                errorMessage = String(localized: "需要 Apple Music 订阅才能使用")
                isLoading = false
            }
            return
        }
        
        // 并行加载专辑和歌单
        async let albums = fetchUserLibraryAlbumsWithSort(sortType)
        async let playlists = fetchUserLibraryPlaylistsWithSort(sortType)
        
        do {
            let (albumsResult, playlistsResult) = try await (albums, playlists)
            
            await MainActor.run {
                userAlbums = albumsResult
                userPlaylists = playlistsResult
                
                if userAlbums.isEmpty && userPlaylists.isEmpty {
                    errorMessage = String(localized: "您的媒体库是空的")
                }
                
                isLoading = false
                hasLoaded = true
            }
            // 加载完成后更新Widget的最近专辑封面
            await updateWidgetWithRecentAlbums()
            
        } catch {
            await MainActor.run {
                errorMessage = String(localized: "加载媒体库失败: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }
    
    // 重新排序现有数据
    func applySorting(_ sortType: SortType) async {
        await MainActor.run {
            isLoading = true
        }
        
        // 重新获取排序后的数据
        async let albums = fetchUserLibraryAlbumsWithSort(sortType)
        async let playlists = fetchUserLibraryPlaylistsWithSort(sortType)
        
        do {
            let (albumsResult, playlistsResult) = try await (albums, playlists)
            
            await MainActor.run {
                userAlbums = albumsResult
                userPlaylists = playlistsResult
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = String(localized: "重新排序失败: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }
    
    // 添加专辑到媒体库
    func addAlbumToLibrary(_ album: Album) async {
        do {
            try await MusicLibrary.shared.add(album)
            
            // 重新加载媒体库以包含新添加的专辑
            await MainActor.run {
                hasLoaded = false
            }
            await loadUserLibraryIfNeeded(with: preferences?.currentSortType ?? .recentlyAdded)
            
            // 添加专辑后立即更新Widget的最近专辑封面
            await updateWidgetWithRecentAlbums()
        } catch {
            await MainActor.run {
                errorMessage = String(localized: "添加专辑到媒体库失败: \(error.localizedDescription)")
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
    
    private func fetchUserLibraryAlbumsWithSort(_ sortType: SortType) async throws -> MusicItemCollection<Album> {
        var request = MusicLibraryRequest<Album>()
        
        switch sortType {
        case .recentlyAdded:
            request.sort(by: \.libraryAddedDate, ascending: false)
        case .albumTitle:
            request.sort(by: \.title, ascending: true)
        case .artistName:
            request.sort(by: \.artistName, ascending: true)
        }
        
        request.limit = 200
        
        let response = try await request.response()
        return response.items
    }

    private func fetchUserLibraryPlaylistsWithSort(_ sortType: SortType) async throws -> MusicItemCollection<Playlist> {
        var request = MusicLibraryRequest<Playlist>()
        
        switch sortType {
        case .recentlyAdded:
            request.sort(by: \.libraryAddedDate, ascending: false)
        case .albumTitle, .artistName:
            request.sort(by: \.name, ascending: true)
        }
        
        request.limit = 200
        
        let response = try await request.response()
        return response.items
    }
    
    private func fetchUserLibraryAlbums() async throws -> MusicItemCollection<Album> {
        return try await fetchUserLibraryAlbumsWithSort(preferences?.currentSortType ?? .recentlyAdded)
    }

    private func fetchUserLibraryPlaylists() async throws -> MusicItemCollection<Playlist> {
        return try await fetchUserLibraryPlaylistsWithSort(preferences?.currentSortType ?? .recentlyAdded)
    }
    
    /// 更新Widget的最近专辑封面数据
    private func updateWidgetWithRecentAlbums() async {
        await musicService.updateWidgetWithRecentAlbums()
    }
}

// 磁带图片随机选择器
struct CassetteImageHelper {
    // 可用的磁带图片名称数组
    static let cassetteImages = [
        "package-cassette-01",
        "package-cassette-02",
        "package-cassette-03",
        "package-cassette-04",
        "package-cassette-05",
        "package-cassette-06",
        "package-cassette-07",
        "package-cassette-08",
        "package-cassette-09",
        "package-cassette-10"
    ]
    
    // 根据ID获取稳定的随机图片名称
    static func getRandomCassetteImage(for id: String) -> String {
        // 使用ID的哈希值作为随机数种子，确保每个ID都有固定的图片选择
        let hash = abs(id.hashValue)
        let index = hash % cassetteImages.count
        return cassetteImages[index]
    }
}

struct ListCassetteImageHelper {
    // 可用的磁带图片名称数组
    static let cassetteImages = [
        "package-list-cassette-01",
        "package-list-cassette-02",
        "package-list-cassette-03",
        "package-list-cassette-04",
        "package-list-cassette-05",
        "package-list-cassette-06",
        "package-list-cassette-07",
        "package-list-cassette-08",
        "package-list-cassette-09",
        "package-list-cassette-10"
    ]
    
    // 根据ID获取稳定的随机图片名称
    static func getRandomCassetteImage(for id: String) -> String {
        // 使用ID的哈希值作为随机数种子，确保每个ID都有固定的图片选择
        let hash = abs(id.hashValue)
        let index = hash % cassetteImages.count
        return cassetteImages[index]
    }
}

struct LibraryView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var musicService: MusicService
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    
    // 使用独立的数据管理器
    @StateObject private var libraryData = LibraryDataManager()
    // 用户偏好设置
    @StateObject private var preferences = LibraryPreferences()
    
    // 选中的分段
    @State private var selectedSegment = 0
    @State private var showSubscriptionOffer = false
    @State private var albumSearchText = ""
    @State private var playlistSearchText = ""
    
    // 条形码扫描相关状态
    @State private var showBarcodeScannerView = false
    @State private var detectedBarcode = ""
    @State private var showAddAlbumSuccess = false
    @State private var addedAlbumTitle = ""
    @State private var showPaywall = false
    
    // 过滤后的数据
    private var filteredAlbums: MusicItemCollection<Album> {
        if albumSearchText.isEmpty {
            return libraryData.userAlbums
        } else {
            return MusicItemCollection(libraryData.userAlbums.filter { album in
                album.title.localizedCaseInsensitiveContains(albumSearchText) ||
                album.artistName.localizedCaseInsensitiveContains(albumSearchText)
            })
        }
    }
    
    private var filteredPlaylists: MusicItemCollection<Playlist> {
        if playlistSearchText.isEmpty {
            return libraryData.userPlaylists
        } else {
            return MusicItemCollection(libraryData.userPlaylists.filter { playlist in
                playlist.name.localizedCaseInsensitiveContains(playlistSearchText)
            })
        }
    }

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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if musicService.isHapticFeedbackEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        
                        // 检查会员状态
                        if storeManager.membershipStatus.isActive {
                            showBarcodeScannerView = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(8)
                    }
                }
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
            .onAppear {
                // 设置数据管理器的偏好设置引用
                libraryData.preferences = preferences
            }
            .task {
                await libraryData.loadUserLibraryIfNeeded(with: preferences.currentSortType)
            }
            .musicSubscriptionOffer(
                isPresented: $showSubscriptionOffer,
                options: MusicSubscriptionOffer.Options()
            ) { result in
                // 订阅结果处理
            }
            .fullScreenCover(isPresented: $showBarcodeScannerView) {
                BarcodeScannerView(
                    detectedBarcode: $detectedBarcode,
                    onAlbumFound: { album in
                        Task {
                            await handleFoundAlbum(album)
                        }
                    },
                    onDismiss: {
                        showBarcodeScannerView = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(storeManager)
            }
            .alert("专辑已添加", isPresented: $showAddAlbumSuccess) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("专辑「\(addedAlbumTitle)」已成功添加到您的媒体库中")
            }
        }
        .navigationViewStyle(.stack) // 确保使用栈式导航
    }
    
    // MARK: - 处理找到的专辑
    
    @MainActor
    private func handleFoundAlbum(_ album: Album) async {
        // 触觉反馈
        if musicService.isHapticFeedbackEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
        // 保存专辑标题用于显示
        addedAlbumTitle = album.title
        
        // 添加专辑到媒体库
        await libraryData.addAlbumToLibrary(album)
        
        // 显示成功提示
        showAddAlbumSuccess = true
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: getErrorIcon(for: message))
                .font(.system(size: 48))
                .foregroundColor(.yellow)
                .padding(.bottom, 10)
            
            Text(message)
                .font(.title3)
                .foregroundColor(.primary)
                .padding(.horizontal, 32)
                
            Text(getErrorDescription(for: message))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
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
                            .fill(Color.yellow)
                    )
            }
            .padding(.top, 20)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal)
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            
            HStack{
                
                Menu {
                    ForEach(SortType.allCases, id: \.self) { sortType in
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
                    .padding(.horizontal)
                }
                
                // 分段控制器 - 固定在顶部
                Picker("媒体类型", selection: $selectedSegment) {
                    Text("专辑").tag(0)
                    Text("歌单").tag(1)
                }
                .pickerStyle(.segmented)
//                .padding(.horizontal)
                .padding(.vertical, 8)
//                .background(.regularMaterial)
                .onChange(of: selectedSegment) { _, _ in
                    if musicService.isHapticFeedbackEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }
                
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
                        .padding(.horizontal)
                }

            }
            .background(.regularMaterial)
            
            // 滚动内容区域 - 为每个分段使用独立的视图
            TabView(selection: $selectedSegment) {
                // 专辑视图
                VStack(spacing: 0) {
                    ScrollView {
                        // 专辑搜索框
                        HStack {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                
                                TextField("搜索专辑或艺术家", text: $albumSearchText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.body)
                                
                                if !albumSearchText.isEmpty {
                                    Button {
                                        albumSearchText = ""
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
                            if !albumSearchText.isEmpty {
                                Button("取消") {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    albumSearchText = ""
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        if !storeManager.membershipStatus.isActive {
                            PayLabel()
                                .environmentObject(storeManager)
                                .padding(.top, 8)
                        }
                        
                        if filteredAlbums.isEmpty && !albumSearchText.isEmpty {
                            // 搜索无结果提示
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(.yellow)
                                
                                Text("未找到匹配的专辑或艺术家")
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
                        } else {
                            if preferences.isGridMode {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 110), spacing: 5)],
                                    spacing: 20
                                ) {
                                    ForEach(filteredAlbums, id: \.id) { album in
                                        NavigationLink(destination: MusicDetailView(containerType: .album(album)).environmentObject(musicService)) {
                                            GirdAlbumCell(album: album)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            } else {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 360))],
                                    spacing: 12
                                ) {
                                    ForEach(filteredAlbums, id: \.id) { album in
                                        NavigationLink(destination: MusicDetailView(containerType: .album(album)).environmentObject(musicService)) {
                                            ListAlbumCell(album: album)
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
                .tag(0)
                
                // 播放列表视图
                VStack(spacing: 0) {
                    ScrollView {
                        
                        // 播放列表搜索框
                        HStack {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                
                                TextField("搜索歌单", text: $playlistSearchText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.body)
                                
                                if !playlistSearchText.isEmpty {
                                    Button {
                                        playlistSearchText = ""
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
                            if !playlistSearchText.isEmpty {
                                Button("取消") {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    playlistSearchText = ""
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        if !storeManager.membershipStatus.isActive {
                            PayLabel()
                                .environmentObject(storeManager)
                                .padding(.top, 8)
                        }
                        
                        if filteredPlaylists.isEmpty && !playlistSearchText.isEmpty {
                            // 搜索无结果提示
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(.yellow)
                                
                                Text("未找到匹配的歌单")
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
                        } else {
                            if preferences.isGridMode {
                                // 网格模式
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 110), spacing: 5)],
                                    spacing: 16
                                ) {
                                    ForEach(filteredPlaylists, id: \.id) { playlist in
                                        NavigationLink(destination: MusicDetailView(containerType: .playlist(playlist)).environmentObject(musicService)) {
                                            GridPlaylistCell(playlist: playlist)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                
                            } else {
                                // 列表模式
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 360))],
                                    spacing: 12
                                ) {
                                    ForEach(filteredPlaylists, id: \.id) { playlist in
                                        NavigationLink(destination: MusicDetailView(containerType: .playlist(playlist)).environmentObject(musicService)) {
                                            ListPlaylistCell(playlist: playlist)
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
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: selectedSegment)
        }
    }

    private func getErrorIcon(for message: String) -> String {
        switch message {
        case String(localized: "需要授权才能访问您的媒体库"):
            return "music.note.list"
        case String(localized: "需要 Apple Music 订阅才能使用"):
            return "music.note.list"
        case String(localized: "您的媒体库是空的"):
            return "music.note.list"
        default:
            return "exclamationmark.triangle"
        }
    }
    
    private func getErrorDescription(for message: String) -> String {
        switch message {
        case String(localized: "需要授权才能访问您的媒体库"):
            return String(localized: "允许访问您的 Apple Music 以查看专辑和播放列表")
        case String(localized: "需要 Apple Music 订阅才能使用"):
            return String(localized: "现在加入 Apple Music，最多可享 3 个月免费试用")
        case String(localized: "您的媒体库是空的"):
            return String(localized: "请先在 Apple Music 中添加专辑或播放列表")
        default:
            return String(localized: "请重试或检查网络连接")
        }
    }
    
    private func getButtonTitle(for message: String) -> String {
        switch message {
        case String(localized: "需要授权才能访问您的媒体库"):
            return String(localized: "授权访问")
        case String(localized: "需要 Apple Music 订阅才能使用"):
            return String(localized: "立即体验")
        case String(localized: "您的媒体库是空的"):
            return String(localized: "打开 Apple Music")
        default:
            return String(localized: "重试")
        }
    }
    
    private func handleErrorAction(for message: String) {
        switch message {
        case String(localized: "需要授权才能访问您的媒体库"):
            Task {
                await requestAuthorizationAndReload()
            }
        case String(localized: "需要 Apple Music 订阅才能使用"):
            showSubscriptionOffer = true
        case String(localized: "您的媒体库是空的"):
            openAppleMusic()
        default:
            Task {
                await libraryData.loadUserLibraryIfNeeded(with: preferences.currentSortType)
            }
        }
    }
    
    private func requestAuthorizationAndReload() async {
        let status = await MusicAuthorization.request()
        if status == .authorized {
            await libraryData.loadUserLibraryIfNeeded(with: preferences.currentSortType)
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

struct GirdAlbumCell: View {
    let album: Album
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading) {
            // 专辑封面 - 根据用户选择的样式显示
            ZStack {
                // 使用 MusicKit 的 ArtworkImage 替代 AsyncImage
                if let artwork = album.artwork {
                    
                    if musicService.currentCoverStyle == .rectangle {
                        // 矩形封面样式
                        ArtworkImage(artwork, width: 170, height: 170)
                            .frame(width: 110, height: 170)
                            .clipShape(Rectangle())
                            .contentShape(Rectangle())
                    } else {
                        ArtworkImage(artwork, width: 170, height: 170)
                            .frame(width: 110, height: 170)
                            .blur(radius: 8)
                            .overlay(
                                Color.black.opacity(0.3)
                            )
                            .clipShape(Rectangle())
                            .contentShape(Rectangle())
                        
                        ArtworkImage(artwork, width: 110, height: 110)
                            .frame(width: 110, height: 110)
                            .clipShape(Rectangle())
                    }
                    
                } else {
                    ZStack{
                        Color.black
                        Image("CASSOFLOW")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 75)
                    }
                    .frame(width: 110, height: 170)
                    .clipShape(Rectangle())
                }
                
                // 使用随机磁带图片
                Image(CassetteImageHelper.getRandomCassetteImage(for: album.id.rawValue))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 170)
//                    .clipShape(RoundedRectangle(cornerRadius: 4))
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
            .padding(.top, 2)
        }
    }
}

struct GridPlaylistCell: View {
    let playlist: Playlist
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading) {
            // 歌单封面 - 根据用户选择的样式显示
            ZStack {
                // 使用 MusicKit 的 ArtworkImage 替代 AsyncImage
                if let artwork = playlist.artwork {
                    if musicService.currentCoverStyle == .rectangle {
                        // 矩形封面
                        ArtworkImage(artwork, width: 170, height: 170)
                            .frame(width: 110, height: 170)
                            .clipShape(Rectangle())
                            .contentShape(Rectangle())
                    } else {
                        // 方形封面
                        ArtworkImage(artwork, width: 170, height: 170)
                            .frame(width: 110, height: 170)
                            .blur(radius: 8)
                            .overlay(
                                Color.black.opacity(0.3)
                            )
                            .clipShape(Rectangle())
                            .contentShape(Rectangle())
                        
                        ArtworkImage(artwork, width: 110, height: 110)
                            .frame(width: 110, height: 110)
                            .clipShape(Rectangle())
                    }
                } else {
                    ZStack{
                        Color.black
                        Image("CASSOFLOW")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 75)
                    }
                    .frame(width: 110, height: 170)
                    .clipShape(Rectangle())
                }
                
                // 使用随机磁带图片
                Image(CassetteImageHelper.getRandomCassetteImage(for: playlist.id.rawValue))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 170)
//                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            // 歌单信息
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .foregroundColor(.primary)
                    .font(.footnote)
                    .lineLimit(1)
            }
            .padding(.top, 2)
        }
    }
}

struct ListAlbumCell: View {
    let album: Album
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading) {
            // 专辑封面 - 根据用户选择的样式显示
            ZStack {
                // 使用 MusicKit 的 ArtworkImage 替代 AsyncImage
                if let artwork = album.artwork {
                    
                    ArtworkImage(artwork, width: 360, height: 360)
                        .frame(width: 360, height: 48)
                        .blur(radius: 8)
                        .overlay(
                            Color.black.opacity(0.3)
                        )
                        .clipShape(Rectangle())
                        .contentShape(Rectangle())
                
                } else {
                    ZStack{
                        Color.black
                        Image("CASSOFLOW")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 75)
                    }
                    .frame(width: 360, height: 48)
                    .clipShape(Rectangle())
                }
                
                HStack(spacing: 16){
                    if let artwork = album.artwork {
                        ArtworkImage(artwork, width: 40, height: 40)
                            .frame(width: 40, height: 40)
                            .clipShape(Rectangle())
                    } else {
                        ZStack{
                            Color.black
                            Image("CASSOFLOW")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Rectangle())
                    }
                    
                    VStack(alignment: .leading) {
                        Text(album.title)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(album.artistName)
                            .font(.footnote)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 5)
                
                Image(ListCassetteImageHelper.getRandomCassetteImage(for: album.id.rawValue))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 360, height: 48)
            }
        }
    }
}

struct ListPlaylistCell: View {
    let playlist: Playlist
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading) {
            // 歌单封面 - 根据用户选择的样式显示
            ZStack {
                // 使用 MusicKit 的 ArtworkImage 替代 AsyncImage
                if let artwork = playlist.artwork {

                        ArtworkImage(artwork, width: 360, height: 360)
                            .frame(width: 360, height: 48)
                            .blur(radius: 8)
                            .overlay(
                                Color.black.opacity(0.3)
                            )
                            .clipShape(Rectangle())
                            .contentShape(Rectangle())
                    
                } else {
                    ZStack{
                        Color.black
                        Image("CASSOFLOW")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 75)
                    }
                    .frame(width: 360, height: 48)
                    .clipShape(Rectangle())
                }
                
                HStack(spacing: 16){
                    if let artwork = playlist.artwork {
                        ArtworkImage(artwork, width: 40, height: 40)
                            .frame(width: 40, height: 40)
                            .clipShape(Rectangle())
                    } else {
                        ZStack{
                            Color.black
                            Image("CASSOFLOW")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Rectangle())
                    }
                    
                    Text(playlist.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal, 6)
                
//                Image("package-list-cassette-01")
//                    .resizable()
//                    .aspectRatio(contentMode: .fill)
//                    .frame(width: 360, height: 48)
//                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                // 使用随机磁带图片
                Image(ListCassetteImageHelper.getRandomCassetteImage(for: playlist.id.rawValue))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 360, height: 48)
                
            }
        }
    }
}

#Preview("成功状态") {
    let musicService = MusicService.shared
    
    // 创建一个带有示例数据的LibraryView
    struct LibraryViewWithMockData: View {
        @State private var selectedSegment = 0
        @State private var userAlbums: [MockAlbum] = [
            MockAlbum(id: "1", title: "Folklore", artistName: "Taylor Swift"),
            MockAlbum(id: "2", title: "Blinding Lights", artistName: "The Weeknd"),
            MockAlbum(id: "3", title: "好想爱这个世界啊", artistName: "华晨宇"),
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
                        
                        HStack{
                            
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(.secondary)
                                .font(.body)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                )
                            
                            // 分段控制器
                            Picker("媒体类型", selection: $selectedSegment) {
                                Text("专辑").tag(0)
                                Text("歌单").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            
                            Image(systemName: "rectangle.grid.1x2")
                                .foregroundColor(.secondary)
                                .font(.body)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                )
                        }
                        
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 330))],
                            spacing: 15) {
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
                        Color.gray
//                        Image("CASSOFLOW")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 75)
                    }
                    .frame(width: 360, height: 60)
                    .clipShape(Rectangle())
                    
                    Image("cover-cassette")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 360, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    HStack(spacing: 16) {
                        
                        Color.yellow
                            .frame(width: 40, height: 40)
                            .clipShape(Rectangle())
                        
                        HStack(spacing: 8){
                            Text(album.title)
                                .font(.footnote)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text(album.artistName)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                }
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
                    .foregroundColor(.yellow)
                
                Text(String(localized: "需要 Apple Music 订阅才能使用"))
                    .font(.title2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 40) {
                    
                    Text(String(localized: "现在加入 Apple Music，最多可享 3 个月免费试用"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        // 预览中的空操作
                    } label: {
                        Text(String(localized: "立即体验"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.yellow)
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
                    .foregroundColor(.yellow)
                
                Text(String(localized: "需要授权才能访问您的音乐库"))
                    .font(.title2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 40) {
                    
                    Text(String(localized: "允许访问您的 Apple Music 以查看专辑和播放列表"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        // 预览中的空操作
                    } label: {
                        Text(String(localized: "授权访问"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.yellow)
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

//#Preview("媒体库为空状态") {
//    let musicService = MusicService.shared
//    NavigationStack {
//        VStack(spacing: 0) {
//            VStack(spacing: 20) {
//                Image(systemName: "music.note.list")
//                    .font(.system(size: 48))
//                    .foregroundColor(.red)
//                
//                Text(String(localized: "您的媒体库是空的\n请先在 Apple Music 中添加一些音乐"))
//                    .font(.title2)
//                    .foregroundColor(.primary)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal, 32)
//                
//                VStack(spacing: 40) {
//                    
//                    Text(String(localized: "在 Apple Music 中添加专辑和播放列表以开始使用"))
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                        .multilineTextAlignment(.center)
//                    
//                    Button {
//                        // 预览中的空操作
//                    } label: {
//                        Text(String(localized: "打开 Apple Music"))
//                            .font(.headline)
//                            .foregroundColor(.white)
//                            .padding(.horizontal, 24)
//                            .padding(.vertical, 12)
//                            .background(
//                                RoundedRectangle(cornerRadius: 25)
//                                    .fill(Color.red)
//                            )
//                    }
//                }
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//        }
//        .navigationTitle("媒体库")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button {
//                    // 预览中的空操作
//                } label: {
//                    Image(systemName: "xmark")
//                        .font(.caption)
//                        .foregroundColor(.primary)
//                        .padding(8)
//                        .background(
//                            Circle()
//                                .fill(Color.gray.opacity(0.15))
//                        )
//                }
//            }
//        }
//    }
//    .environmentObject(musicService)
//}
