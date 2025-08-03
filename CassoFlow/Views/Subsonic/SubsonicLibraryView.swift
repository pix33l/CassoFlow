import SwiftUI

/// Subsonic音乐库视图
struct SubsonicLibraryView: View {
    @EnvironmentObject private var musicService: MusicService
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    
    // 数据管理器
    @StateObject private var libraryData = SubsonicLibraryDataManager()
    @StateObject private var preferences = LibraryPreferences()
    
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
                // 连接状态检查
                if !musicService.getSubsonicService().isConnected {
                    connectionErrorView
                } else if libraryData.isLoading {
                    ProgressView("正在加载Subsonic音乐库...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = libraryData.errorMessage {
                    errorView(message: error)
                } else {
                    contentView
                }
            }
            .navigationTitle("Subsonic 音乐库")
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
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
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
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.orange)
                        )
                }
                
                Button(action: {
                    Task {
                        await libraryData.testConnection(subsonicService: musicService.getSubsonicService())
                    }
                }) {
                    Text("重新连接")
                        .font(.subheadline)
                        .foregroundColor(.orange)
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
                // 刷新按钮
                Button(action: {
                    Task {
                        await libraryData.reloadLibrary(subsonicService: musicService.getSubsonicService())
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                        .font(.body)
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
                .foregroundColor(.orange)
            
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
                .foregroundColor(.orange)
            
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

class SubsonicLibraryDataManager: ObservableObject {
    @Published var albums: [UniversalAlbum] = []
    @Published var playlists: [UniversalPlaylist] = []
    @Published var artists: [UniversalArtist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasLoaded = false
    
    func loadLibraryIfNeeded(subsonicService: SubsonicMusicService) async {
        guard !hasLoaded else { return }
        
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
            
            await MainActor.run {
                self.albums = albumsResult
                self.playlists = playlistsResult
                self.artists = artistsResult
                self.isLoading = false
                self.hasLoaded = true
                
                if albumsResult.isEmpty && playlistsResult.isEmpty && artistsResult.isEmpty {
                    self.errorMessage = "Subsonic服务器上没有找到音乐内容"
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "加载音乐库失败：\(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func reloadLibrary(subsonicService: SubsonicMusicService) async {
        await MainActor.run {
            hasLoaded = false
        }
        await loadLibraryIfNeeded(subsonicService: subsonicService)
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
            }
        }
        
        if isConnected {
            await loadLibraryIfNeeded(subsonicService: subsonicService)
        }
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
