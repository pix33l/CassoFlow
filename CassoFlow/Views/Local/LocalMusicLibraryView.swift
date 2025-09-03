import SwiftUI

// 🔑 新增：本地音乐库变化通知
extension Notification.Name {
    static let localMusicLibraryDidChange = Notification.Name("localMusicLibraryDidChange")
}

/// 本地音乐库视图
struct LocalMusicLibraryView: View {
    @EnvironmentObject private var musicService: MusicService
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    
    // 数据管理器
    @StateObject private var libraryData = LocalLibraryDataManager()
    @StateObject private var preferences = LocalLibraryPreferences()
    
    // UI状态
    @State private var selectedSegment = 0 // 0: 专辑, 1: 艺术家
    @State private var albumSearchText = ""
    @State private var artistSearchText = ""
    
    // 添加导入状态变量
    @State private var showDocumentPicker = false
    
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
                if libraryData.isLoading {
                    ProgressView("正在扫描本地音乐...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = libraryData.errorMessage {
                    errorView(message: error)
                } else {
                    contentView
                }
            }
            .navigationTitle("本地音乐库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // 刷新按钮
                    Button(action: {
                        if musicService.isHapticFeedbackEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        showDocumentPicker = true
                    }) {
                        Image(systemName: "plus")
                            .font(.body)
                            .foregroundColor(.primary)
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
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { urls in
                    Task {
                        await handleImportedFiles(urls: urls)
                    }
                }
                .ignoresSafeArea()
            }
            .task {
                await libraryData.loadLibraryIfNeeded(localService: musicService.getLocalService())
            }
            .onReceive(NotificationCenter.default.publisher(for: .localMusicLibraryDidChange)) { _ in
                // 🔑 接收到本地音乐库变化通知时，重新加载数据
                Task {
                    await libraryData.reloadLibrary(localService: musicService.getLocalService())
                }
            }
        }
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
                        LocalLibraryDataManager.clearSharedCache()
                    }
                    await libraryData.reloadLibrary(localService: musicService.getLocalService())
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
                    ForEach(LocalSortType.allCases, id: \.self) { sortType in
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
                    Text("艺术家").tag(1)
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
                
                // 艺术家视图
                artistsView.tag(1)
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
                emptyLibraryView(message: "暂无本地音乐", systemImage: "folder.fill.badge.plus")
            } else {
                if preferences.isGridMode {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 5)], spacing: 20) {
                        ForEach(filteredAlbums, id: \.id) { album in
                            NavigationLink(destination: UniversalMusicDetailView(album: album).environmentObject(musicService)) {
                                LocalGridAlbumCell(album: album)
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
                                LocalListAlbumCell(album: album)
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
                emptyLibraryView(message: "暂无本地艺术家", systemImage: "person.fill")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360))], spacing: 12) {
                    ForEach(filteredArtists, id: \.id) { artist in
                        NavigationLink(destination: UniversalMusicDetailView(artist: artist).environmentObject(musicService)) {
                            LocalArtistCell(artist: artist)
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
            
            Text("点击下方按钮导入音乐文件")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 添加导入按钮
            Button(action: {
                if musicService.isHapticFeedbackEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
                showDocumentPicker = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("导入")
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.yellow)
                )
            }
            .padding(.top, 20)
            
            Text("支持格式: MP3, AAC, WAV, FLAC 等")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { urls in
                Task {
                    await handleImportedFiles(urls: urls)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - 处理导入的文件
    private func handleImportedFiles(urls: [URL]) async {
        let localService = musicService.getLocalService()
        
        await MainActor.run {
            libraryData.isLoading = true
            libraryData.errorMessage = nil
        }
        
        do {
            // 将文件导入到应用文档目录
            try await localService.importFiles(from: urls)
            
            // 重新加载库数据
            await libraryData.reloadLibrary(localService: localService)
            
            await MainActor.run {
                libraryData.isLoading = false
            }
        } catch {
            await MainActor.run {
                libraryData.errorMessage = "导入文件失败: \(error.localizedDescription)"
                libraryData.isLoading = false
            }
        }
    }
}

// MARK: - 文档选择器
struct DocumentPicker: UIViewControllerRepresentable {
    var onFilesPicked: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onFilesPicked: onFilesPicked)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onFilesPicked: ([URL]) -> Void
        
        init(onFilesPicked: @escaping ([URL]) -> Void) {
            self.onFilesPicked = onFilesPicked
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onFilesPicked(urls)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // 用户取消选择
        }
    }
}

// MARK: - 本地音乐库数据管理器

// 本地音乐专用的排序类型
enum LocalSortType: String, CaseIterable {
    case newest = "newest"          // 按名称排序（本地音乐没有添加时间）
    case alphabeticalByName = "alphabeticalByName"  // 按专辑名称
    case alphabeticalByArtist = "alphabeticalByArtist" // 按艺术家名称
    
    var localizedName: String {
        switch self {
        case .newest:
            return "默认"
        case .alphabeticalByName:
            return "专辑"
        case .alphabeticalByArtist:
            return "艺术家"
        }
    }
}

// 本地音乐图书馆偏好设置管理器
class LocalLibraryPreferences: ObservableObject {
    private let sortTypeKey = "LocalLibrarySortType"
    private let displayModeKey = "LocalLibraryDisplayMode"
    
    @Published var currentSortType: LocalSortType {
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
        let savedSortType = UserDefaults.standard.string(forKey: sortTypeKey) ?? LocalSortType.newest.rawValue
        self.currentSortType = LocalSortType(rawValue: savedSortType) ?? .newest
        
        self.isGridMode = UserDefaults.standard.object(forKey: displayModeKey) as? Bool ?? true
    }
}

class LocalLibraryDataManager: ObservableObject {
    @Published var albums: [UniversalAlbum] = []
    @Published var artists: [UniversalArtist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasLoaded = false
    
    // 添加静态缓存，在整个应用生命周期中保持
    private static var sharedLibraryData: (albums: [UniversalAlbum], artists: [UniversalArtist])?
    
    // 保存原始未排序的数据
    private var originalAlbums: [UniversalAlbum] = []
    private var originalArtists: [UniversalArtist] = []
    
    func loadLibraryIfNeeded(localService: LocalMusicService) async {
        // 如果已经加载过或有静态缓存，直接使用缓存数据
        if hasLoaded {
            return
        }
        
        // 检查静态缓存
        if let cachedData = Self.sharedLibraryData {
            await MainActor.run {
                self.albums = cachedData.albums
                self.artists = cachedData.artists
                self.originalAlbums = cachedData.albums
                self.originalArtists = cachedData.artists
                self.hasLoaded = true
                self.isLoading = false
                self.errorMessage = nil
                
                // 预加载封面
                self.preloadAlbumCovers()
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // 检查服务可用性
        let isAvailable = await localService.checkAvailability()
        guard isAvailable else {
            await MainActor.run {
                errorMessage = "本地音乐服务不可用"
                isLoading = false
            }
            return
        }
        
        do {
            // 加载数据
            let albumsResult = try await localService.getRecentAlbums()
            let artistsResult = try await localService.getArtists()
            
            await MainActor.run {
                self.albums = albumsResult
                self.artists = artistsResult
                self.originalAlbums = albumsResult
                self.originalArtists = artistsResult
                self.isLoading = false
                self.hasLoaded = true
                
                // 缓存到静态变量
                Self.sharedLibraryData = (albumsResult, artistsResult)
                
                // 🔑 修复：不要设置错误消息，让UI根据数据是否为空来决定显示内容
                // 移除这行：if albumsResult.isEmpty && artistsResult.isEmpty { self.errorMessage = "未找到本地音乐文件" }
                
                // 预加载专辑封面
                self.preloadAlbumCovers()
            }
        } catch {
            await MainActor.run {
                // 🔑 修复：只有在真正发生错误时才设置错误消息
                self.errorMessage = "加载本地音乐库失败：\(error.localizedDescription)"
                self.isLoading = false
                
                // 🔑 即使发生错误，也要标记为已加载，避免后续重复尝试
                self.hasLoaded = true
                
                // 🔑 确保数组为空状态，这样UI会显示空状态而不是错误状态
                self.albums = []
                self.artists = []
                self.originalAlbums = []
                self.originalArtists = []
            }
        }
    }
    
    /// 应用排序
    func applySorting(_ sortType: LocalSortType) async {
        await MainActor.run {
            // 对专辑排序
            switch sortType {
            case .newest:
                albums = originalAlbums // 默认排序
            case .alphabeticalByName:
                albums = originalAlbums.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .alphabeticalByArtist:
                albums = originalAlbums.sorted { $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending }
            }
            
            // 对艺术家排序
            switch sortType {
            case .newest:
                artists = originalArtists // 默认排序
            case .alphabeticalByName, .alphabeticalByArtist:
                artists = originalArtists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        }
    }
    
    /// 预加载专辑封面
    @MainActor private func preloadAlbumCovers() {
        _ = ImageCacheManager.shared
        
        // 预加载前20个专辑的封面
        for _ in albums.prefix(20) {
            // 本地音乐没有远程URL，所以这里只是确保缓存机制正常工作
            // 实际的封面加载将在单元格中进行
        }
    }
    
    func reloadLibrary(localService: LocalMusicService) async {
        await MainActor.run {
            hasLoaded = false
            // 清除静态缓存，强制重新加载
            Self.sharedLibraryData = nil
        }
        await loadLibraryIfNeeded(localService: localService)
    }
    
    /// 清除缓存的类方法
    static func clearSharedCache() {
        sharedLibraryData = nil
    }
}

// MARK: - 预览

struct LocalMusicLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        LocalMusicLibraryView()
            .environmentObject(MusicService.shared)
            .environmentObject(StoreManager())
    }
}
