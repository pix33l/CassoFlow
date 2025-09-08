import MusicKit
import Foundation

/// 音乐容器协议，用于统一专辑和播放列表的接口
protocol MusicContainer {
    var id: MusicItemID { get }
    var title: String { get }
    var artistName: String { get }
    var artwork: Artwork? { get }
    var releaseDate: Date? { get }
    var genreNames: [String] { get }
    
    /// 获取包含歌曲的详细信息
    func withTracks() async throws -> [Track]
}

/// 专辑容器包装
struct AlbumContainer: MusicContainer {
    let album: Album
    
    var id: MusicItemID { album.id }
    var title: String { album.title }
    var artistName: String { album.artistName }
    var artwork: Artwork? { album.artwork }
    var releaseDate: Date? { album.releaseDate }
    var genreNames: [String] { album.genreNames }
    
    func withTracks() async throws -> [Track] {
        let detailedAlbum = try await album.with([.tracks])
        guard let tracks = detailedAlbum.tracks else { return [] }
        return Array(tracks)
    }
}

/// 播放列表容器包装
struct PlaylistContainer: MusicContainer {
    let playlist: Playlist
    
    var id: MusicItemID { playlist.id }
    var title: String { playlist.name }
    var artistName: String { playlist.curatorName ?? "Apple Music" }
    var artwork: Artwork? { playlist.artwork }
    var releaseDate: Date? { playlist.lastModifiedDate }
    var genreNames: [String] { [] } // 播放列表通常没有流派信息
    
    func withTracks() async throws -> [Track] {
        let detailedPlaylist = try await playlist.with([.tracks])
        guard let tracks = detailedPlaylist.tracks else { return [] }
        return Array(tracks)
    }
}

/// 容器类型枚举
enum MusicContainerType {
    case album(Album)
    case playlist(Playlist)
    
    var container: MusicContainer {
        switch self {
        case .album(let album):
            return AlbumContainer(album: album)
        case .playlist(let playlist):
            return PlaylistContainer(playlist: playlist)
        }
    }
}
