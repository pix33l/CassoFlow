//
//  GirdAlbumCell.swift
//  CassoFlow
//
//  Created by Zhang Shensen on 2025/8/26.
//
import SwiftUI
import MusicKit

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

// MARK: - 队列歌曲行视图
struct QueueTrackRow: View {
    let index: Int
    let entry: ApplicationMusicPlayer.Queue.Entry
    let isPlaying: Bool
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
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .center)
                }
            }
            
            // 专辑封面
            if let artwork = trackArtwork {
                ArtworkImage(artwork, width: 50, height: 50)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
            }
            
            // 歌曲信息
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(entry.subtitle ?? "未知艺术家")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 歌曲时长
            Text(formattedDuration(trackDuration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            isPlaying ? Color.primary.opacity(0.1) : Color.clear
        )
        .contentShape(Rectangle())
    }
    
    /// 获取歌曲封面
    private var trackArtwork: Artwork? {
        switch entry.item {
        case .song(let song):
            return song.artwork
        case .musicVideo(let musicVideo):
            return musicVideo.artwork
        case .none:
            return nil
        @unknown default:
            return nil
        }
    }
    
    /// 获取歌曲时长
    private var trackDuration: TimeInterval {
        switch entry.item {
        case .song(let song):
            return song.duration ?? 0
        case .musicVideo(let musicVideo):
            return musicVideo.duration ?? 0
        case .none:
            return 0
        @unknown default:
            return 0
        }
    }
    
    /// 格式化时长
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
