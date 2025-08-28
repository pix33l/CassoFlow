import SwiftUI

/// Audio Station专用音乐详情视图 - 专辑
struct AudioStationMusicDetailView: View {
    @EnvironmentObject private var musicService: MusicService
    let album: UniversalAlbum
    @State private var detailedAlbum: UniversalAlbum?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var coverURL: URL? // 🔧 添加动态封面URL状态
    
    @State private var playTapped = false
    @State private var shufflePlayTapped = false
    @State private var trackTapped = false
    
    // 获取缓存管理器
    private let cacheManager = MusicDetailCacheManager.shared
    
    /// 判断当前是否正在播放指定歌曲
    private func isPlaying(_ song: UniversalSong) -> Bool {
        // 使用元数据匹配
        let titleMatch = musicService.currentTitle.trimmingCharacters(in: .whitespaces).lowercased() ==
                        song.title.trimmingCharacters(in: .whitespaces).lowercased()
        let artistMatch = musicService.currentArtist.trimmingCharacters(in: .whitespaces).lowercased() ==
                         song.artistName.trimmingCharacters(in: .whitespaces).lowercased()
        
        return titleMatch && artistMatch && musicService.currentDataSource == .audioStation
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 顶部专辑信息
                VStack(spacing: 16) {
                    ZStack {
                        Image("artwork-cassette")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 360)
                        
                        // 🔧 背景封面 - 使用动态封面URL
                        CachedAsyncImage(url: coverURL ?? album.artworkURL) {
                            defaultBackground
                        } content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 270, height: 120)
                                .blur(radius: 8)
                                .overlay(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(.bottom, 37)
                        }
                        
                        // CassoFlow Logo
                        Image("CASSOFLOW")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100)
                            .padding(.bottom, 110)
                        
                        // 磁带孔洞
                        Image("artwork-cassette-hole")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 360)
                        
                        // 专辑信息
                        HStack {
                            // 🔧 小封面 - 使用动态封面URL
                            CachedAsyncImage(url: coverURL ?? album.artworkURL) {
                                defaultSmallCover
                            } content: { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                            }
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Text(album.title)
                                    .font(.headline.bold())
                                    .lineLimit(1)
                                
                                Text(album.artistName)
                                    .font(.footnote)
                                    .lineLimit(1)
                                    .padding(.top, 4)
                                
                                if let year = album.year {
                                    let genreText = album.genre ?? "未知风格"
                                    Text("\(genreText) • \(year)")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 120)
                        .frame(width: 300)
                    }
                    
                    // 播放控制按钮
                    HStack(spacing: 20) {
                        Button {
                            playTapped.toggle()
                            if musicService.isHapticFeedbackEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                            Task {
                                try await playAlbum(shuffled: false)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("播放")
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading)
                        
                        Button {
                            shufflePlayTapped.toggle()
                            if musicService.isHapticFeedbackEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                            Task {
                                try await playAlbum(shuffled: true)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "shuffle")
                                Text("随机播放")
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal)
                
                // 歌曲列表
                VStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        ProgressView("正在加载歌曲...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(.yellow)
                            
                            Text(error)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("重试") {
                                Task {
                                    await loadDetailedAlbum(forceRefresh: true)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.yellow)
                            .foregroundColor(.black)
                        }
                        .padding(.vertical, 40)
                    } else if let detailed = detailedAlbum, !detailed.songs.isEmpty {
                        Divider()
                            .padding(.leading, 20)
                            .padding(.trailing, 16)
                        
                        LazyVStack(spacing: 0) {
                            ForEach(Array(detailed.songs.enumerated()), id: \.element.id) { index, song in
                                AudioStationTrackRow(
                                    index: index,
                                    song: song,
                                    isPlaying: isPlaying(song)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    trackTapped.toggle()
                                    if musicService.isHapticFeedbackEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }
                                    Task {
                                        try await playSong(song, from: detailed.songs, startingAt: index)
                                    }
                                }
                                
                                if index < detailed.songs.count - 1 {
                                    Divider()
                                        .padding(.leading, 40)
                                        .padding(.trailing, 16)
                                }
                            }
                        }
                        
                        Divider()
                            .padding(.leading, 20)
                            .padding(.trailing, 16)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("此专辑暂无歌曲")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                    }
                }
                
                // 底部信息
                if let detailed = detailedAlbum, !detailed.songs.isEmpty {
                    AudioStationInfoFooter(
                        year: album.year,
                        trackCount: detailed.songs.count,
                        totalDuration: detailed.songs.reduce(0) { $0 + $1.duration },
                        isPlaylist: false
                    )
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetailedAlbum(forceRefresh: false)
            await loadAlbumCover() // 🔧 加载专辑封面
        }
    }
    
    // 🔧 新增：加载专辑封面方法
    private func loadAlbumCover() async {
        print("🎨 开始为专辑详情加载封面: \(album.title) - \(album.artistName)")
        
        let apiClient = AudioStationAPIClient.shared
        
        // 优先使用专辑名称和艺术家名称获取封面
        let albumCoverURL = apiClient.getCoverArtURL(albumName: album.title, artistName: album.artistName)
        
        if let coverURL = albumCoverURL {
            await MainActor.run {
                self.coverURL = coverURL
                print("🎨 专辑详情封面URL已设置: \(coverURL.absoluteString)")
            }
            
            // 🔧 验证封面URL是否有效
            let isValid = await apiClient.testCoverURL(albumName: album.title, artistName: album.artistName)
            if isValid {
                print("✅ 专辑详情封面URL验证成功")
                return
            } else {
                print("❌ 专辑详情封面URL验证失败，尝试其他方法")
            }
        }
//        
//        // 回退方法：从详细专辑信息中获取封面
//        if let detailed = detailedAlbum, let firstSong = detailed.songs.first {
//            var songCoverURL: URL?
//            
//            if let audioStationSong = firstSong.originalData as? AudioStationSong {
//                songCoverURL = apiClient.getCoverArtURL(for: audioStationSong)
//            } else {
//                // 使用歌曲的专辑信息获取封面
//                if let albumName = firstSong.albumName, !albumName.isEmpty {
//                    songCoverURL = apiClient.getCoverArtURL(albumName: albumName, artistName: firstSong.artistName)
//                }
//            }
//            
//            if let coverURL = songCoverURL {
//                await MainActor.run {
//                    self.coverURL = coverURL
//                    print("🎨 专辑详情封面URL已设置（歌曲方法）: \(coverURL.absoluteString)")
//                }
//            }
//        }
    }
    
    // MARK: - 默认视图
    
    private var defaultBackground: some View {
        ZStack {
            Color.black
            Image("CASSOFLOW")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 75)
        }
        .frame(width: 270, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.bottom, 37)
    }
    
    private var defaultSmallCover: some View {
        ZStack {
            Color.black
            Image("CASSOFLOW")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30)
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
    
    // MARK: - 数据加载（优化缓存版本）
    
    /// 加载详细专辑信息（支持缓存）
    private func loadDetailedAlbum(forceRefresh: Bool) async {
        // 如果不是强制刷新，先检查缓存
        if !forceRefresh {
            if let cached = cacheManager.getCachedAlbum(id: album.id) {
                await MainActor.run {
                    detailedAlbum = cached
                    isLoading = false
                    errorMessage = nil
                }
                // 🔧 加载详情后也尝试加载封面
                await loadAlbumCover()
                return
            }
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let coordinator = musicService.getCoordinator()
            let detailed = try await coordinator.getAlbum(id: album.id)
            
            // 缓存结果
            cacheManager.cacheAlbum(detailed, id: album.id)
            
            await MainActor.run {
                detailedAlbum = detailed
                isLoading = false
                
                if detailed.songs.isEmpty {
                    errorMessage = "此专辑没有歌曲"
                }
            }
            
            // 🔧 加载详情后尝试加载封面
            await loadAlbumCover()
        } catch {
            await MainActor.run {
                errorMessage = "加载专辑详情失败：\(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - 播放控制
    
    private func playAlbum(shuffled: Bool) async throws {
        guard let detailed = detailedAlbum, !detailed.songs.isEmpty else { return }
        
        let songs = shuffled ? detailed.songs.shuffled() : detailed.songs
        try await musicService.playUniversalSongs(songs)
    }
    
    private func playSong(_ song: UniversalSong, from songs: [UniversalSong], startingAt index: Int) async throws {
        try await musicService.playUniversalSongs(songs, startingAt: index)
    }
}

// MARK: - Audio Station播放列表详情视图

struct AudioStationPlaylistDetailView: View {
    @EnvironmentObject private var musicService: MusicService
    let playlist: UniversalPlaylist
    @State private var detailedPlaylist: UniversalPlaylist?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var playTapped = false
    @State private var shufflePlayTapped = false
    @State private var trackTapped = false
    
    /// 判断当前是否正在播放指定歌曲
    private func isPlaying(_ song: UniversalSong) -> Bool {
        let titleMatch = musicService.currentTitle.trimmingCharacters(in: .whitespaces).lowercased() ==
                        song.title.trimmingCharacters(in: .whitespaces).lowercased()
        let artistMatch = musicService.currentArtist.trimmingCharacters(in: .whitespaces).lowercased() ==
                         song.artistName.trimmingCharacters(in: .whitespaces).lowercased()
        
        return titleMatch && artistMatch && musicService.currentDataSource == .audioStation
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 顶部播放列表信息
                VStack(spacing: 16) {
                    ZStack {
                        Image("artwork-cassette")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 360)

                        // 统一只用默认背景封面
                        defaultPlaylistBackground

                        // CassoFlow Logo
                        Image("CASSOFLOW")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100)
                            .padding(.bottom, 110)
                        
                        // 磁带孔洞
                        Image("artwork-cassette-hole")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 360)
                        
                        // 播放列表信息
                        HStack {
                            // 只用默认小封面
                            defaultSmallPlaylistCover
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Text(playlist.name)
                                    .font(.headline.bold())
                                    .lineLimit(1)
                                
                                if let curatorName = playlist.curatorName {
                                    Text(curatorName)
                                        .font(.footnote)
                                        .lineLimit(1)
                                        .padding(.top, 4)
                                }
                                
                                Text("播放列表")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 120)
                        .frame(width: 300)
                    }
                    
                    // 播放控制按钮
                    HStack(spacing: 20) {
                        Button {
                            playTapped.toggle()
                            if musicService.isHapticFeedbackEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                            Task {
                                try await playPlaylist(shuffled: false)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("播放")
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading)
                        
                        Button {
                            shufflePlayTapped.toggle()
                            if musicService.isHapticFeedbackEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                            Task {
                                try await playPlaylist(shuffled: true)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "shuffle")
                                Text("随机播放")
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal)
                
                // 歌曲列表
                VStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        ProgressView("正在加载歌曲...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(.yellow)
                            
                            Text(error)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("重试") {
                                Task {
                                    await loadDetailedPlaylist()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.yellow)
                            .foregroundColor(.black)
                        }
                        .padding(.vertical, 40)
                    } else if let detailed = detailedPlaylist, !detailed.songs.isEmpty {
                        Divider()
                            .padding(.leading, 20)
                            .padding(.trailing, 16)
                        
                        LazyVStack(spacing: 0) {
                            ForEach(Array(detailed.songs.enumerated()), id: \.element.id) { index, song in
                                AudioStationTrackRow(
                                    index: index,
                                    song: song,
                                    isPlaying: isPlaying(song)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    trackTapped.toggle()
                                    if musicService.isHapticFeedbackEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }
                                    Task {
                                        try await playSong(song, from: detailed.songs, startingAt: index)
                                    }
                                }
                                
                                if index < detailed.songs.count - 1 {
                                    Divider()
                                        .padding(.leading, 40)
                                        .padding(.trailing, 16)
                                }
                            }
                        }
                        
                        Divider()
                            .padding(.leading, 20)
                            .padding(.trailing, 16)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("此播放列表暂无歌曲")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                    }
                }
                
                // 底部信息
                if let detailed = detailedPlaylist, !detailed.songs.isEmpty {
                    AudioStationInfoFooter(
                        year: nil,
                        trackCount: detailed.songs.count,
                        totalDuration: detailed.songs.reduce(0) { $0 + $1.duration },
                        isPlaylist: true
                    )
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetailedPlaylist()
        }
    }

    // 默认大封面
    private var defaultPlaylistBackground: some View {
        ZStack {
            Color.black
            Image("CASSOFLOW")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 75)
        }
        .frame(width: 270, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.bottom, 37)
    }

    // 默认小封面
    private var defaultSmallPlaylistCover: some View {
        ZStack {
            Color.black
            Image("CASSOFLOW")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30)
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    // MARK: - 数据加载
    
    private func loadDetailedPlaylist() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let coordinator = musicService.getCoordinator()
            let detailed = try await coordinator.getPlaylist(id: playlist.id)
            
            await MainActor.run {
                detailedPlaylist = detailed
                isLoading = false
                
                if detailed.songs.isEmpty {
                    errorMessage = "此播放列表没有歌曲"
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "加载播放列表详情失败：\(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - 播放控制
    
    private func playPlaylist(shuffled: Bool) async throws {
        guard let detailed = detailedPlaylist, !detailed.songs.isEmpty else { return }
        
        let songs = shuffled ? detailed.songs.shuffled() : detailed.songs
        try await musicService.playUniversalSongs(songs)
    }
    
    private func playSong(_ song: UniversalSong, from songs: [UniversalSong], startingAt index: Int) async throws {
        try await musicService.playUniversalSongs(songs, startingAt: index)
    }
}

// MARK: - Audio Station艺术家详情视图

struct AudioStationArtistDetailView: View {
    @EnvironmentObject private var musicService: MusicService
    let artist: UniversalArtist
    @State private var detailedArtist: UniversalArtist?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 顶部艺术家信息
                VStack(spacing: 16) {
                    // 艺术家头像
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.2))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                    }
                    
                    VStack(spacing: 8) {
                        Text(artist.name)
                            .font(.largeTitle.bold())
                        
                        Text("\(artist.albumCount) 张专辑")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // 专辑列表
                VStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        ProgressView("正在加载专辑...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(.yellow)
                            
                            Text(error)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("重试") {
                                Task {
                                    await loadDetailedArtist()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.yellow)
                            .foregroundColor(.black)
                        }
                        .padding(.vertical, 40)
                    } else if let detailed = detailedArtist, !detailed.albums.isEmpty {
                        Text("专辑")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 20) {
                            ForEach(detailed.albums, id: \.id) { album in
                                NavigationLink(destination: UniversalMusicDetailView(album: album).environmentObject(musicService)) {
                                    AudioStationGridAlbumCell(album: album)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "opticaldisc")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("此艺术家暂无专辑")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetailedArtist()
        }
    }
    
    // MARK: - 数据加载
    
    private func loadDetailedArtist() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let coordinator = musicService.getCoordinator()
            let detailed = try await coordinator.getArtist(id: artist.id)
            
            await MainActor.run {
                detailedArtist = detailed
                isLoading = false
                
                if detailed.albums.isEmpty {
                    errorMessage = "此艺术家没有专辑"
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "加载艺术家详情失败：\(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - Audio Station歌曲行视图

struct AudioStationTrackRow: View {
    let index: Int
    let song: UniversalSong
    let isPlaying: Bool
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        HStack {
            if isPlaying {
                AudioWaveView()
                    .frame(width: 24, height: 24)
                    .opacity(musicService.isPlaying ? 1.0 : 0.6)
            } else {
                Text("\(index + 1)")
                    .frame(width: 24, alignment: .center)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .foregroundColor(.primary)
                Text(song.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formattedDuration(song.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(
            isPlaying ? Color.white.opacity(0.1) : Color.clear
        )
        .contentShape(Rectangle())
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Station底部信息栏

struct AudioStationInfoFooter: View {
    let year: Int?
    let trackCount: Int
    let totalDuration: TimeInterval
    let isPlaylist: Bool
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            if let year = year, !isPlaylist {
                Text("发布于 \(year) 年")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else if isPlaylist {
                Text("Audio Station 播放列表")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Text("\(trackCount)首歌曲 • \(formatMinutes(totalDuration))")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private func formatMinutes(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        
        if minutes < 60 {
            return String(localized: "\(minutes)分钟")
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(localized: "\(hours)小时\(remainingMinutes)分钟")
        }
    }
}

// MARK: - 预览

struct AudioStationMusicDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockAlbum = UniversalAlbum(
            id: "mock-1",
            title: "Audio Station专辑示例",
            artistName: "Audio Station艺术家",
            year: 2024,
            genre: "摇滚",
            songCount: 10,
            duration: 2400,
            artworkURL: nil,
            songs: [],
            source: .audioStation,
            originalData: "mock"
        )
        
        NavigationView {
            AudioStationMusicDetailView(album: mockAlbum)
                .environmentObject(MusicService.shared)
        }
    }
}
