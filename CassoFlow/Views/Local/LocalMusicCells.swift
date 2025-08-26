import SwiftUI

// MARK: - 本地专辑网格单元格

struct LocalGridAlbumCell: View {
    let album: UniversalAlbum
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading) {
            // 专辑封面
            ZStack {
                // 🔑 正确显示本地专辑封面，并根据封面样式调整显示
                if let localAlbum = album.originalData as? LocalAlbumItem,
                   let artworkData = localAlbum.artworkData,
                   let image = UIImage(data: artworkData) {
                    if musicService.currentCoverStyle == .rectangle {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 110, height: 170)
                            .clipShape(Rectangle())
                            .contentShape(Rectangle())
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 110, height: 170)
                            .blur(radius: 8)
                            .overlay(Color.black.opacity(0.3))
                            .clipShape(Rectangle())
                            .contentShape(Rectangle())
                            .overlay(
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 110, height: 110)
                                    .clipShape(Rectangle())
                            )
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
        .id(album.id) // 稳定视图身份，减少重新创建
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

// MARK: - 本地专辑列表单元格

struct LocalListAlbumCell: View {
    let album: UniversalAlbum
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                // 背景
                // 🔑 正确显示本地专辑封面，并根据封面样式调整显示
                if let localAlbum = album.originalData as? LocalAlbumItem,
                   let artworkData = localAlbum.artworkData,
                   let image = UIImage(data: artworkData) {
                    if musicService.currentCoverStyle == .rectangle {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360, height: 48)
                            .clipShape(Rectangle())
                            .contentShape(Rectangle())
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360, height: 48)
                            .blur(radius: 8)
                            .overlay(Color.black.opacity(0.3))
                            .clipShape(Rectangle())
                            .contentShape(Rectangle())
                    }
                } else {
                    defaultListBackground
                }
                
                // 前景内容
                HStack(spacing: 16) {
                    // 小封面
                    // 🔑 正确显示本地小专辑封面
                    if let localAlbum = album.originalData as? LocalAlbumItem,
                       let artworkData = localAlbum.artworkData,
                       let image = UIImage(data: artworkData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Rectangle())
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
        .id(album.id) // 稳定视图身份
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

// MARK: - 本地播放列表网格单元格

struct LocalGridPlaylistCell: View {
    let playlist: UniversalPlaylist
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading) {
            // 播放列表封面
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

// MARK: - 本地播放列表列表单元格

struct LocalListPlaylistCell: View {
    let playlist: UniversalPlaylist
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                // 背景
                defaultListPlaylistBackground
                
                // 前景内容
                HStack(spacing: 16) {
                    // 小封面
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
                
                // 磁带装饰
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

// MARK: - 本地艺术家单元格

struct LocalArtistCell: View {
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

// MARK: - 本地歌曲行视图

struct LocalTrackRow: View {
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

// MARK: - 本地队列歌曲行视图

struct LocalQueueTrackRow: View {
    let index: Int
    let song: UniversalSong
    let isPlaying: Bool
    let isCurrent: Bool
    @EnvironmentObject private var musicService: MusicService
    
    var body: some View {
        HStack(spacing: 12) {
            // 歌曲序号或播放状态
            VStack {
                if isPlaying {
                    AudioWaveView()
                        .frame(width: 24, height: 24)
                        .opacity(musicService.isPlaying ? 1.0 : 0.6)
                } else {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundColor(isCurrent ? .yellow : .secondary)
                        .frame(width: 24, alignment: .center)
                }
            }
            
            if let localSong = song.originalData as? LocalMusicItem,
               let artworkData = localSong.artwork,
               let image = UIImage(data: artworkData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                // 专辑封面
                defaultArtwork
            }
            
            // 歌曲信息
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(song.artistName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let albumName = song.albumName {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(albumName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // 歌曲时长
            Text(formattedDuration(song.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            isCurrent ? Color.yellow.opacity(0.1) : Color.clear
        )
        .contentShape(Rectangle())
    }
    
    private var defaultArtwork: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.yellow.opacity(0.2))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundColor(.yellow)
            )
    }
    
    /// 格式化时长
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
