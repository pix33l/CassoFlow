import SwiftUI
import MusicKit

/// 统一音乐详情视图路由器 - 根据数据源和内容类型自动切换
struct UniversalMusicDetailView: View {
    @EnvironmentObject private var musicService: MusicService
    
    // 用于Apple Music数据源
    let containerType: MusicContainerType?
    
    // 用于Subsonic和Audio Station数据源
    let album: UniversalAlbum?
    let playlist: UniversalPlaylist?
    let artist: UniversalArtist?
    
    // MARK: - 初始化方法
    
    /// 用于Apple Music专辑/播放列表
    init(containerType: MusicContainerType) {
        self.containerType = containerType
        self.album = nil
        self.playlist = nil
        self.artist = nil
    }
    
    /// 用于通用专辑（Subsonic/Audio Station）
    init(album: UniversalAlbum) {
        self.containerType = nil
        self.album = album
        self.playlist = nil
        self.artist = nil
    }
    
    /// 用于通用播放列表（Subsonic/Audio Station）
    init(playlist: UniversalPlaylist) {
        self.containerType = nil
        self.album = nil
        self.playlist = playlist
        self.artist = nil
    }
    
    /// 用于通用艺术家（Subsonic/Audio Station）
    init(artist: UniversalArtist) {
        self.containerType = nil
        self.album = nil
        self.playlist = nil
        self.artist = artist
    }
    
    var body: some View {
        Group {
            switch musicService.currentDataSource {
            case .musicKit:
                // 使用Apple Music详情视图
                if let containerType = containerType {
                    MusicDetailView(containerType: containerType)
                } else {
                    ErrorView(message: "无效的Apple Music内容类型")
                }
                
            case .subsonic:
                // 使用Subsonic详情视图
                if let album = album {
                    SubsonicMusicDetailView(album: album)
                } else if let playlist = playlist {
                    SubsonicPlaylistDetailView(playlist: playlist)
                } else if let artist = artist {
                    SubsonicArtistDetailView(artist: artist)
                } else {
                    ErrorView(message: "无效的Subsonic内容类型")
                }
                
            case .audioStation:
                // 使用Audio Station详情视图
                if let album = album {
                    AudioStationMusicDetailView(album: album)
                } else if let playlist = playlist {
                    AudioStationPlaylistDetailView(playlist: playlist)
                } else if let artist = artist {
                    AudioStationArtistDetailView(artist: artist)
                } else {
                    ErrorView(message: "无效的Audio Station内容类型")
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: musicService.currentDataSource)
    }
}

// MARK: - 错误视图

struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("加载错误")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("错误")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 预览

struct UniversalMusicDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Subsonic专辑预览
            NavigationView {
                UniversalMusicDetailView(album: UniversalAlbum(
                    id: "test-album",
                    title: "测试专辑",
                    artistName: "测试艺术家",
                    year: 2024,
                    genre: "流行",
                    songCount: 10,
                    duration: 2400,
                    artworkURL: nil,
                    songs: [],
                    source: .subsonic,
                    originalData: "mock"
                ))
                .environmentObject({
                    let service = MusicService.shared
                    service.currentDataSource = .subsonic
                    return service
                }())
            }
            .previewDisplayName("Subsonic 专辑")
            
            // Audio Station专辑预览
            NavigationView {
                UniversalMusicDetailView(album: UniversalAlbum(
                    id: "test-album-as",
                    title: "Audio Station专辑",
                    artistName: "测试艺术家",
                    year: 2024,
                    genre: "流行",
                    songCount: 12,
                    duration: 2880,
                    artworkURL: nil,
                    songs: [],
                    source: .audioStation,
                    originalData: "mock"
                ))
                .environmentObject({
                    let service = MusicService.shared
                    service.currentDataSource = .audioStation
                    return service
                }())
            }
            .previewDisplayName("Audio Station 专辑")
            
            // Subsonic播放列表预览
            NavigationView {
                UniversalMusicDetailView(playlist: UniversalPlaylist(
                    id: "test-playlist",
                    name: "测试播放列表",
                    curatorName: "测试用户",
                    songCount: 15,
                    duration: 3600,
                    artworkURL: nil,
                    songs: [],
                    source: .subsonic,
                    originalData: "mock"
                ))
                .environmentObject({
                    let service = MusicService.shared
                    service.currentDataSource = .subsonic
                    return service
                }())
            }
            .previewDisplayName("Subsonic 播放列表")
            
            // 错误状态预览
            NavigationView {
                ErrorView(message: "这是一个错误示例")
            }
            .previewDisplayName("错误状态")
        }
    }
}