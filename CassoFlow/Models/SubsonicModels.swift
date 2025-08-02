import Foundation

// MARK: - 基础响应结构

struct SubsonicResponse<T: Codable>: Codable {
    let subsonicResponse: SubsonicResponseContent<T>
    
    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

struct SubsonicResponseContent<T: Codable>: Codable {
    let status: String
    let version: String
    let type: String?
    let serverVersion: String?
    let openSubsonic: Bool?
    let error: SubsonicAPIError?
    
    // 动态内容
    let artists: ArtistsIndex?
    let artist: SubsonicArtist?
    let album: SubsonicAlbum?
    let playlists: PlaylistsWrapper?
    let playlist: SubsonicPlaylist?
    let searchResult3: SubsonicSearchResult?
    
    enum CodingKeys: String, CodingKey {
        case status, version, type, serverVersion, openSubsonic, error
        case artists, artist, album, playlists, playlist
        case searchResult3 = "searchResult3"
    }
}

struct SubsonicAPIError: Codable {
    let code: Int
    let message: String
}

// MARK: - 艺术家相关

struct ArtistsIndex: Codable {
    let index: [ArtistIndex]
}

struct ArtistIndex: Codable {
    let name: String
    let artist: [SubsonicArtist]
}

struct SubsonicArtist: Codable, Identifiable {
    let id: String
    let name: String
    let albumCount: Int?
    let starred: String?
    let artistImageUrl: String?
    let albums: [SubsonicAlbum]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, albumCount, starred
        case artistImageUrl = "artistImageUrl"
        case albums = "album"
    }
}

// MARK: - 专辑相关

struct SubsonicAlbum: Codable, Identifiable {
    let id: String
    let name: String
    let artist: String?
    let artistId: String?
    let coverArt: String?
    let songCount: Int?
    let duration: Int?
    let playCount: Int?
    let created: String?
    let starred: String?
    let year: Int?
    let genre: String?
    let songs: [SubsonicSong]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, artist, artistId, coverArt, songCount, duration
        case playCount, created, starred, year, genre
        case songs = "song"
    }
}

// MARK: - 歌曲相关

struct SubsonicSong: Codable, Identifiable {
    let id: String
    let parent: String?
    let isDir: Bool?
    let title: String
    let album: String?
    let artist: String?
    let track: Int?
    let year: Int?
    let genre: String?
    let coverArt: String?
    let size: Int?
    let contentType: String?
    let suffix: String?
    let duration: Int?
    let bitRate: Int?
    let path: String?
    let playCount: Int?
    let discNumber: Int?
    let created: String?
    let albumId: String?
    let artistId: String?
    let type: String?
    let starred: String?
    
    enum CodingKeys: String, CodingKey {
        case id, parent, isDir, title, album, artist, track, year, genre
        case coverArt, size, contentType, suffix, duration, bitRate, path
        case playCount, discNumber, created, albumId, artistId, type, starred
    }
}

// MARK: - 播放列表相关

struct PlaylistsWrapper: Codable {
    let playlist: [SubsonicPlaylist]
}

struct SubsonicPlaylist: Codable, Identifiable {
    let id: String
    let name: String
    let comment: String?
    let owner: String?
    let `public`: Bool?
    let songCount: Int?
    let duration: Int?
    let created: String?
    let changed: String?
    let coverArt: String?
    let songs: [SubsonicSong]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, comment, owner, songCount, duration, created, changed, coverArt
        case `public` = "public"
        case songs = "entry"
    }
}

// MARK: - 搜索结果

struct SubsonicSearchResult: Codable {
    let artist: [SubsonicArtist]
    let album: [SubsonicAlbum]
    let song: [SubsonicSong]
}

// MARK: - 内容包装器（用于JSON解码）

struct ArtistsContent: Codable {
    let artists: ArtistsIndex?
}

struct ArtistContent: Codable {
    let artist: SubsonicArtist?
}

struct AlbumContent: Codable {
    let album: SubsonicAlbum?
}

struct PlaylistsContent: Codable {
    let playlists: PlaylistsWrapper?
}

struct PlaylistContent: Codable {
    let playlist: SubsonicPlaylist?
}

struct SearchResultContent: Codable {
    let searchResult3: SubsonicSearchResult?
}

// MARK: - 扩展方法

extension SubsonicSong {
    /// 将时长从秒转换为TimeInterval
    var durationTimeInterval: TimeInterval {
        TimeInterval(duration ?? 0)
    }
    
    /// 格式化时长显示
    var formattedDuration: String {
        let duration = self.duration ?? 0
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension SubsonicAlbum {
    /// 将时长从秒转换为TimeInterval
    var durationTimeInterval: TimeInterval {
        TimeInterval(duration ?? 0)
    }
}

extension SubsonicPlaylist {
    /// 将时长从秒转换为TimeInterval
    var durationTimeInterval: TimeInterval {
        TimeInterval(duration ?? 0)
    }
}