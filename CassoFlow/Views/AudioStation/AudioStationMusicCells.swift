import SwiftUI

// MARK: - Audio Station专辑网格单元格

struct AudioStationGridAlbumCell: View {
    let album: UniversalAlbum
    @EnvironmentObject private var musicService: MusicService
    @State private var coverURL: URL?
    
    var body: some View {
        VStack(alignment: .leading) {
            // 专辑封面
            ZStack {
                // 🔧 使用优化后的CachedAsyncImage，支持动态URL变化
                CachedAsyncImage(url: coverURL ?? album.artworkURL) {
                    defaultAlbumCover
                } content: { image in
                    if musicService.currentCoverStyle == .rectangle {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 110, height: 170)
                            .clipShape(Rectangle())
                            .contentShape(Rectangle())
                    } else {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 110, height: 170)
                            .blur(radius: 8)
                            .overlay(Color.black.opacity(0.3))
                            .clipShape(Rectangle())
                            .contentShape(Rectangle())
                            .overlay(
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 110, height: 110)
                                    .clipShape(Rectangle())
                            )
                    }
                }
                
                // 磁带装饰
                Image(CassetteImageHelper.getRandomCassetteImage(for: album.id))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 170)
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
        .id(album.id) // 稳定视图身份，减少重新创建
        .task {
            // 🔧 只在没有封面URL时才加载，避免重复请求
            if album.artworkURL == nil && coverURL == nil {
                await loadCoverURL()
            }
        }
    }
    
    // 🔧 改进的封面加载方法，使用新的专辑封面API
    private func loadCoverURL() async {
        print("🎨 开始为专辑加载封面: \(album.title) - \(album.artistName)")
        
        let apiClient = AudioStationAPIClient.shared
        
        // 🔧 使用专辑名称和艺术家名称获取封面
        let albumCoverURL = apiClient.getCoverArtURL(albumName: album.title, artistName: album.artistName)
        
        if let coverURL = albumCoverURL {
            await MainActor.run {
                self.coverURL = coverURL
                print("🎨 设置专辑封面URL: \(coverURL.absoluteString)")
            }
            return
        }
        
        // 🔧 回退方法：获取专辑详情并使用第一首歌曲的封面
        do {
            let audioStationService = musicService.getAudioStationService()
            let detailedAlbum = try await audioStationService.getAlbum(id: album.id)
            
            print("🎨 专辑详情获取成功，歌曲数量: \(detailedAlbum.songs.count)")
            
            // 使用第一首歌曲获取封面
            if let firstSong = detailedAlbum.songs.first {
                print("🎨 使用第一首歌曲获取封面: \(firstSong.title) (ID: \(firstSong.id))")
                
                // 🔧 修复：从UniversalSong的originalData中获取AudioStationSong
                var songCoverURL: URL?
                
                if let audioStationSong = firstSong.originalData as? AudioStationSong {
                    songCoverURL = apiClient.getCoverArtURL(for: audioStationSong)
                } else {
                    // 回退到使用歌曲的专辑信息
                    if let albumName = firstSong.albumName, !albumName.isEmpty {
                        songCoverURL = apiClient.getCoverArtURL(albumName: albumName, artistName: firstSong.artistName)
                    }
                }
                
                await MainActor.run {
                    // 🔧 关键：更新coverURL会触发CachedAsyncImage的onChange监听
                    self.coverURL = songCoverURL
                    print("🎨 设置歌曲封面URL: \(songCoverURL?.absoluteString ?? "无")")
                }
            } else {
                print("🎨 专辑没有歌曲，无法获取封面")
            }
            
        } catch {
            print("❌ 获取专辑封面失败: \(album.title) - \(error)")
        }
    }
    
    private var defaultAlbumCover: some View {
        ZStack {
            Color.black
            Image("CASSOFLOW")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 75)
        }
        .frame(width: 110, height: 170)
        .clipShape(Rectangle())
    }
}

// MARK: - Audio Station专辑列表单元格

struct AudioStationListAlbumCell: View {
    let album: UniversalAlbum
    @EnvironmentObject private var musicService: MusicService
    @State private var coverURL: URL?
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                // 背景
                CachedAsyncImage(url: coverURL ?? album.artworkURL) {
                    defaultListBackground
                } content: { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 360, height: 48)
                        .blur(radius: 8)
                        .overlay(Color.black.opacity(0.3))
                        .clipShape(Rectangle())
                        .contentShape(Rectangle())
                }
                
                // 前景内容
                HStack(spacing: 16) {
                    // 小封面
                    CachedAsyncImage(url: coverURL ?? album.artworkURL) {
                        defaultSmallCover
                    } content: { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
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
                
                // 磁带装饰
                Image(ListCassetteImageHelper.getRandomCassetteImage(for: album.id))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 360, height: 48)
            }
        }
        .id(album.id) // 稳定视图身份
        .task {
            if album.artworkURL == nil && coverURL == nil {
                await loadCoverURL()
            }
        }
    }
    
    // 🔧 简化的封面加载方法，使用新的专辑封面API
    private func loadCoverURL() async {
        print("🎨 开始为列表专辑加载封面: \(album.title) - \(album.artistName)")
        
        let apiClient = AudioStationAPIClient.shared
        
        // 🔧 直接使用专辑名称和艺术家名称获取封面
        let albumCoverURL = apiClient.getCoverArtURL(albumName: album.title, artistName: album.artistName)
        
        if let coverURL = albumCoverURL {
            await MainActor.run {
                self.coverURL = coverURL
                print("🎨 列表封面URL已设置: \(coverURL.absoluteString)")
            }
            return
        }
        
        // 🔧 回退方法
        do {
            let audioStationService = musicService.getAudioStationService()
            let detailedAlbum = try await audioStationService.getAlbum(id: album.id)
            
            if let firstSong = detailedAlbum.songs.first {
                // 🔧 修复：从UniversalSong的originalData中获取AudioStationSong
                var songCoverURL: URL?
                
                if let audioStationSong = firstSong.originalData as? AudioStationSong {
                    songCoverURL = apiClient.getCoverArtURL(for: audioStationSong)
                } else {
                    // 回退到使用歌曲的专辑信息
                    if let albumName = firstSong.albumName, !albumName.isEmpty {
                        songCoverURL = apiClient.getCoverArtURL(albumName: albumName, artistName: firstSong.artistName)
                    }
                }
                
                await MainActor.run {
                    self.coverURL = songCoverURL
                    print("🎨 列表封面URL已设置（回退）: \(songCoverURL?.absoluteString ?? "无")")
                }
            }
            
        } catch {
            print("❌ 获取列表专辑封面失败: \(album.title) - \(error)")
        }
    }
    
    private var defaultListBackground: some View {
        ZStack {
            Color.black
            Image("CASSOFLOW")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 75)
        }
        .frame(width: 360, height: 48)
        .clipShape(Rectangle())
    }
    
    private var defaultSmallCover: some View {
        ZStack {
            Color.black
            Image("CASSOFLOW")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20)
        }
        .frame(width: 40, height: 40)
        .clipShape(Rectangle())
    }
}

// MARK: - Audio Station播放列表网格单元格

struct AudioStationGridPlaylistCell: View {
    let playlist: UniversalPlaylist
    @EnvironmentObject private var musicService: MusicService

    var body: some View {
        VStack(alignment: .leading) {
            // 直接使用默认封面
            ZStack {
                defaultPlaylistCover

                // 磁带装饰
                Image(CassetteImageHelper.getRandomCassetteImage(for: playlist.id))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 170)
            }

            // 播放列表信息
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .foregroundColor(.primary)
                    .font(.footnote)
                    .lineLimit(1)
                
                if let curatorName = playlist.curatorName {
                    Text(curatorName)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 2)
        }
        .id(playlist.id) // 稳定视图身份
    }
    
    private var defaultPlaylistCover: some View {
        ZStack {
            Color.black
            Image("CASSOFLOW")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 75)
        }
        .frame(width: 110, height: 170)
        .clipShape(Rectangle())
    }
}

// MARK: - Audio Station播放列表列表单元格

struct AudioStationListPlaylistCell: View {
    let playlist: UniversalPlaylist
    @EnvironmentObject private var musicService: MusicService

    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                defaultListPlaylistBackground

                HStack(spacing: 16) {
                    defaultSmallPlaylistCover
                    
                    VStack(alignment: .leading) {
                        Text(playlist.name)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if let curatorName = playlist.curatorName {
                            Text(curatorName)
                                .font(.footnote)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 5)
                
                Image(ListCassetteImageHelper.getRandomCassetteImage(for: playlist.id))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 360, height: 48)
            }
        }
        .id(playlist.id) // 稳定视图身份
    }
    
    private var defaultListPlaylistBackground: some View {
        ZStack {
            Color.black
            Image("CASSOFLOW")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 75)
        }
        .frame(width: 360, height: 48)
        .clipShape(Rectangle())
    }
    
    private var defaultSmallPlaylistCover: some View {
        ZStack {
            Color.black
            Image("CASSOFLOW")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20)
        }
        .frame(width: 40, height: 40)
        .clipShape(Rectangle())
    }
}

// MARK: - Audio Station艺术家单元格

struct AudioStationArtistCell: View {
    let artist: UniversalArtist
    
    var body: some View {
        HStack(spacing: 16) {
            // 艺术家头像（使用默认图标）
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(artist.albumCount) 张专辑")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}