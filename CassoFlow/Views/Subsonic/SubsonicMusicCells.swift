import SwiftUI

// MARK: - Subsonic专辑网格单元格

struct SubsonicGridAlbumCell: View {
    let album: UniversalAlbum
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading) {
            // 专辑封面
            ZStack {
                if let artworkURL = album.artworkURL {
                    AsyncImage(url: artworkURL) { image in
                        if musicService.currentCoverStyle == .rectangle {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 170)
                                .clipShape(Rectangle())
                        } else {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 170)
                                .blur(radius: 8)
                                .overlay(Color.black.opacity(0.3))
                                .clipShape(Rectangle())
                                .overlay(
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 110, height: 110)
                                        .clipShape(Rectangle())
                                )
                        }
                    } placeholder: {
                        defaultAlbumCover
                    }
                } else {
                    defaultAlbumCover
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

// MARK: - Subsonic专辑列表单元格

struct SubsonicListAlbumCell: View {
    let album: UniversalAlbum
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                // 背景
                if let artworkURL = album.artworkURL {
                    AsyncImage(url: artworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360, height: 48)
                            .blur(radius: 8)
                            .overlay(Color.black.opacity(0.3))
                            .clipShape(Rectangle())
                    } placeholder: {
                        defaultListBackground
                    }
                } else {
                    defaultListBackground
                }
                
                // 前景内容
                HStack(spacing: 16) {
                    // 小封面
                    if let artworkURL = album.artworkURL {
                        AsyncImage(url: artworkURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Rectangle())
                        } placeholder: {
                            defaultSmallCover
                        }
                    } else {
                        defaultSmallCover
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

// MARK: - Subsonic播放列表网格单元格

struct SubsonicGridPlaylistCell: View {
    let playlist: UniversalPlaylist
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading) {
            // 播放列表封面
            ZStack {
                if let artworkURL = playlist.artworkURL {
                    AsyncImage(url: artworkURL) { image in
                        if musicService.currentCoverStyle == .rectangle {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 170)
                                .clipShape(Rectangle())
                        } else {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 170)
                                .blur(radius: 8)
                                .overlay(Color.black.opacity(0.3))
                                .clipShape(Rectangle())
                                .overlay(
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 110, height: 110)
                                        .clipShape(Rectangle())
                                )
                        }
                    } placeholder: {
                        defaultPlaylistCover
                    }
                } else {
                    defaultPlaylistCover
                }
                
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

// MARK: - Subsonic播放列表列表单元格

struct SubsonicListPlaylistCell: View {
    let playlist: UniversalPlaylist
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                // 背景
                if let artworkURL = playlist.artworkURL {
                    AsyncImage(url: artworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360, height: 48)
                            .blur(radius: 8)
                            .overlay(Color.black.opacity(0.3))
                            .clipShape(Rectangle())
                    } placeholder: {
                        defaultListPlaylistBackground
                    }
                } else {
                    defaultListPlaylistBackground
                }
                
                // 前景内容
                HStack(spacing: 16) {
                    // 小封面
                    if let artworkURL = playlist.artworkURL {
                        AsyncImage(url: artworkURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Rectangle())
                        } placeholder: {
                            defaultSmallPlaylistCover
                        }
                    } else {
                        defaultSmallPlaylistCover
                    }
                    
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
                
                // 磁带装饰
                Image(ListCassetteImageHelper.getRandomCassetteImage(for: playlist.id))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 360, height: 48)
            }
        }
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

// MARK: - Subsonic艺术家单元格

struct SubsonicArtistCell: View {
    let artist: UniversalArtist
    
    var body: some View {
        HStack(spacing: 16) {
            // 艺术家头像（使用默认图标）
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
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
