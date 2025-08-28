import Foundation
import MusicKit

// MARK: - 通用音乐数据模型

/// 通用艺术家模型
struct UniversalArtist: Identifiable {
    let id: String
    let name: String
    let albumCount: Int
    let albums: [UniversalAlbum]
    
    // 原始数据源
    let source: MusicDataSourceType
    let originalData: Any // MusicKit.Artist 或 SubsonicArtist
}

/// 通用专辑模型
struct UniversalAlbum: Identifiable {
    let id: String
    let title: String
    let artistName: String
    let year: Int?
    let genre: String?
    let songCount: Int
    let duration: TimeInterval
    let artworkURL: URL?
    let songs: [UniversalSong]
    
    // 原始数据源
    let source: MusicDataSourceType
    let originalData: Any // MusicKit.Album 或 SubsonicAlbum
}

/// 通用歌曲模型
struct UniversalSong: Identifiable {
    let id: String
    let title: String
    let artistName: String
    let albumName: String?
    let duration: TimeInterval
    let trackNumber: Int?
    let artworkURL: URL?
    let streamURL: URL?
    
    // 原始数据源
    let source: MusicDataSourceType
    let originalData: Any // MusicKit.Song 或 SubsonicSong
}

/// 通用播放列表模型
struct UniversalPlaylist: Identifiable {
    let id: String
    let name: String
    let curatorName: String?
    let songCount: Int
    let duration: TimeInterval
    let artworkURL: URL?
    let songs: [UniversalSong]
    
    // 原始数据源
    let source: MusicDataSourceType
    let originalData: Any // MusicKit.Playlist 或 SubsonicPlaylist
}

// MARK: - 数据源类型枚举

enum MusicDataSourceType: String, CaseIterable {
    case musicKit = "Apple Music"
    case subsonic = "Subsonic"
    case audioStation = "Audio Station"
    case local = "Local"
    
    var displayName: String {
        rawValue
    }
}

// MARK: - 音乐数据源协议

protocol MusicDataSource: ObservableObject {
    var isAvailable: Bool { get }
    var sourceType: MusicDataSourceType { get }
    
    // 认证和初始化
    func initialize() async throws
    func checkAvailability() async -> Bool
    
    // 获取音乐库数据
    func getRecentAlbums() async throws -> [UniversalAlbum]
    func getRecentPlaylists() async throws -> [UniversalPlaylist]
    func getArtists() async throws -> [UniversalArtist]
    
    // 获取详细信息
    func getArtist(id: String) async throws -> UniversalArtist
    func getAlbum(id: String) async throws -> UniversalAlbum
    func getPlaylist(id: String) async throws -> UniversalPlaylist
    
    // 搜索功能
    func search(query: String) async throws -> (artists: [UniversalArtist], albums: [UniversalAlbum], songs: [UniversalSong])
    
    // 播放相关
    func getStreamURL(for song: UniversalSong) async throws -> URL?
    func reportPlayback(song: UniversalSong) async throws
}

// MARK: - MusicKit数据源实现

class MusicKitDataSource: MusicDataSource {
    @Published var isAvailable: Bool = false
    
    let sourceType: MusicDataSourceType = .musicKit
    
    func initialize() async throws {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            isAvailable = status == .authorized
        }
    }
    
    func checkAvailability() async -> Bool {
        let status = MusicAuthorization.currentStatus
        let available = status == .authorized
        await MainActor.run {
            isAvailable = available
        }
        return available
    }
    
    func getRecentAlbums() async throws -> [UniversalAlbum] {
        var request = MusicLibraryRequest<Album>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 50
        
        let response = try await request.response()
        
        return response.items.compactMap { album in
            UniversalAlbum(
                id: album.id.rawValue,
                title: album.title,
                artistName: album.artistName,
                year: album.releaseDate?.year,
                genre: album.genreNames.first,
                songCount: album.trackCount,
                duration: TimeInterval(album.trackCount * 210), // 估算3.5分钟每首
                artworkURL: album.artwork?.url(width: 300, height: 300),
                songs: [],
                source: .musicKit,
                originalData: album
            )
        }
    }
    
    func getRecentPlaylists() async throws -> [UniversalPlaylist] {
        var request = MusicLibraryRequest<Playlist>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 50
        
        let response = try await request.response()
        
        return try await withThrowingTaskGroup(of: UniversalPlaylist?.self) { group in
            for playlist in response.items {
                group.addTask {
                    do {
                        // 获取播放列表的详细信息包括歌曲数量
                        let detailedPlaylist = try await playlist.with([.tracks])
                        let trackCount = detailedPlaylist.tracks?.count ?? 0
                        
                        return UniversalPlaylist(
                            id: playlist.id.rawValue,
                            name: playlist.name,
                            curatorName: playlist.curatorName,
                            songCount: trackCount,
                            duration: TimeInterval(trackCount * 210), // 估算
                            artworkURL: playlist.artwork?.url(width: 300, height: 300),
                            songs: [],
                            source: .musicKit,
                            originalData: playlist
                        )
                    } catch {
                        // 如果获取详细信息失败，使用基本信息
                        return UniversalPlaylist(
                            id: playlist.id.rawValue,
                            name: playlist.name,
                            curatorName: playlist.curatorName,
                            songCount: 0,
                            duration: 0,
                            artworkURL: playlist.artwork?.url(width: 300, height: 300),
                            songs: [],
                            source: .musicKit,
                            originalData: playlist
                        )
                    }
                }
            }
            
            var results: [UniversalPlaylist] = []
            for try await result in group {
                if let playlist = result {
                    results.append(playlist)
                }
            }
            return results
        }
    }
    
    func getArtists() async throws -> [UniversalArtist] {
        // MusicKit没有直接获取所有艺术家的API，返回空数组
        return []
    }
    
    func getArtist(id: String) async throws -> UniversalArtist {
        // 这个需要通过专辑来推断艺术家信息
        throw MusicDataSourceError.notImplemented
    }
    
    func getAlbum(id: String) async throws -> UniversalAlbum {
        let albumID = MusicItemID(id)
        
        var request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: albumID)
        request.properties = [.tracks]
        
        let response = try await request.response()
        guard let album = response.items.first else {
            throw MusicDataSourceError.notFound
        }
        
        let detailedAlbum = try await album.with([.tracks])
        let songs = detailedAlbum.tracks?.compactMap { track in
            UniversalSong(
                id: track.id.rawValue,
                title: track.title,
                artistName: track.artistName,
                albumName: track.albumTitle,
                duration: track.duration ?? 0,
                trackNumber: track.trackNumber,
                artworkURL: track.artwork?.url(width: 300, height: 300),
                streamURL: nil, // MusicKit使用自己的播放机制
                source: .musicKit,
                originalData: track
            )
        } ?? []
        
        return UniversalAlbum(
            id: album.id.rawValue,
            title: album.title,
            artistName: album.artistName,
            year: album.releaseDate?.year,
            genre: album.genreNames.first,
            songCount: songs.count,
            duration: songs.reduce(0) { $0 + $1.duration },
            artworkURL: album.artwork?.url(width: 300, height: 300),
            songs: songs,
            source: .musicKit,
            originalData: album
        )
    }
    
    func getPlaylist(id: String) async throws -> UniversalPlaylist {
        let playlistID = MusicItemID(id)
        
        var request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: playlistID)
        request.properties = [.tracks]
        
        let response = try await request.response()
        guard let playlist = response.items.first else {
            throw MusicDataSourceError.notFound
        }
        
        let detailedPlaylist = try await playlist.with([.tracks])
        let songs = detailedPlaylist.tracks?.compactMap { track in
            UniversalSong(
                id: track.id.rawValue,
                title: track.title,
                artistName: track.artistName,
                albumName: track.albumTitle,
                duration: track.duration ?? 0,
                trackNumber: track.trackNumber,
                artworkURL: track.artwork?.url(width: 300, height: 300),
                streamURL: nil,
                source: .musicKit,
                originalData: track
            )
        } ?? []
        
        return UniversalPlaylist(
            id: playlist.id.rawValue,
            name: playlist.name,
            curatorName: playlist.curatorName,
            songCount: songs.count,
            duration: songs.reduce(0) { $0 + $1.duration },
            artworkURL: playlist.artwork?.url(width: 300, height: 300),
            songs: songs,
            source: .musicKit,
            originalData: playlist
        )
    }
    
    func search(query: String) async throws -> (artists: [UniversalArtist], albums: [UniversalAlbum], songs: [UniversalSong]) {
        var request = MusicCatalogSearchRequest(term: query, types: [Album.self, Song.self])
        request.limit = 20
        
        let response = try await request.response()
        
        let albums = response.albums.compactMap { album in
            UniversalAlbum(
                id: album.id.rawValue,
                title: album.title,
                artistName: album.artistName,
                year: album.releaseDate?.year,
                genre: album.genreNames.first,
                songCount: album.trackCount,
                duration: TimeInterval(album.trackCount * 210),
                artworkURL: album.artwork?.url(width: 300, height: 300),
                songs: [],
                source: .musicKit,
                originalData: album
            )
        }
        
        let songs = response.songs.compactMap { song in
            UniversalSong(
                id: song.id.rawValue,
                title: song.title,
                artistName: song.artistName,
                albumName: song.albumTitle,
                duration: song.duration ?? 0,
                trackNumber: song.trackNumber,
                artworkURL: song.artwork?.url(width: 300, height: 300),
                streamURL: nil,
                source: .musicKit,
                originalData: song
            )
        }
        
        return (artists: [], albums: albums, songs: songs)
    }
    
    func getStreamURL(for song: UniversalSong) async throws -> URL? {
        // MusicKit不需要URL，使用自己的播放机制
        return nil
    }
    
    func reportPlayback(song: UniversalSong) async throws {
        // MusicKit自动处理播放统计
    }
}

// MARK: - Subsonic数据源实现

class SubsonicDataSource: MusicDataSource {
    @Published var isAvailable: Bool = false
    
    let sourceType: MusicDataSourceType = .subsonic
    private let apiClient: SubsonicAPIClient
    
    init(apiClient: SubsonicAPIClient) {
        self.apiClient = apiClient
    }
    
    func initialize() async throws {
        let connected = try await apiClient.ping()
        await MainActor.run {
            isAvailable = connected
        }
    }
    
    func checkAvailability() async -> Bool {
        do {
            let connected = try await apiClient.ping()
            await MainActor.run {
                isAvailable = connected
            }
            return connected
        } catch {
            await MainActor.run {
                isAvailable = false
            }
            return false
        }
    }
    
    func getRecentAlbums() async throws -> [UniversalAlbum] {
        // Subsonic没有直接的"最近添加专辑"接口，可以通过getAlbumList获取
        // 这里简化实现，实际应该调用getAlbumList with type="newest"
        return []
    }
    
    func getRecentPlaylists() async throws -> [UniversalPlaylist] {
        let playlists = try await apiClient.getPlaylists()
        
        return playlists.compactMap { playlist in
            UniversalPlaylist(
                id: playlist.id,
                name: playlist.name,
                curatorName: playlist.owner,
                songCount: playlist.songCount ?? 0,
                duration: playlist.durationTimeInterval,
                artworkURL: playlist.coverArt != nil ? apiClient.getCoverArtURL(id: playlist.coverArt!) : nil,
                songs: [],
                source: .subsonic,
                originalData: playlist
            )
        }
    }
    
    func getArtists() async throws -> [UniversalArtist] {
        let artists = try await apiClient.getArtists()
        
        return artists.compactMap { artist in
            UniversalArtist(
                id: artist.id,
                name: artist.name,
                albumCount: artist.albumCount ?? 0,
                albums: [],
                source: .subsonic,
                originalData: artist
            )
        }
    }
    
    func getArtist(id: String) async throws -> UniversalArtist {
        let artist = try await apiClient.getArtist(id: id)
        
        let albums = artist.albums?.compactMap { album in
            UniversalAlbum(
                id: album.id,
                title: album.name,
                artistName: album.artist ?? artist.name,
                year: album.year,
                genre: album.genre,
                songCount: album.songCount ?? 0,
                duration: album.durationTimeInterval,
                artworkURL: album.coverArt != nil ? apiClient.getCoverArtURL(id: album.coverArt!) : nil,
                songs: [],
                source: .subsonic,
                originalData: album
            )
        } ?? []
        
        return UniversalArtist(
            id: artist.id,
            name: artist.name,
            albumCount: artist.albumCount ?? 0,
            albums: albums,
            source: .subsonic,
            originalData: artist
        )
    }
    
    func getAlbum(id: String) async throws -> UniversalAlbum {
        let album = try await apiClient.getAlbum(id: id)
        
        let songs = album.songs?.compactMap { song in
            UniversalSong(
                id: song.id,
                title: song.title,
                artistName: song.artist ?? "",
                albumName: song.album,
                duration: song.durationTimeInterval,
                trackNumber: song.track,
                artworkURL: song.coverArt != nil ? apiClient.getCoverArtURL(id: song.coverArt!) : nil,
                streamURL: apiClient.getStreamURL(id: song.id),
                source: .subsonic,
                originalData: song
            )
        } ?? []
        
        return UniversalAlbum(
            id: album.id,
            title: album.name,
            artistName: album.artist ?? "",
            year: album.year,
            genre: album.genre,
            songCount: songs.count,
            duration: songs.reduce(0) { $0 + $1.duration },
            artworkURL: album.coverArt != nil ? apiClient.getCoverArtURL(id: album.coverArt!) : nil,
            songs: songs,
            source: .subsonic,
            originalData: album
        )
    }
    
    func getPlaylist(id: String) async throws -> UniversalPlaylist {
        let playlist = try await apiClient.getPlaylist(id: id)
        
        let songs = playlist.songs?.compactMap { song in
            UniversalSong(
                id: song.id,
                title: song.title,
                artistName: song.artist ?? "",
                albumName: song.album,
                duration: song.durationTimeInterval,
                trackNumber: song.track,
                artworkURL: song.coverArt != nil ? apiClient.getCoverArtURL(id: song.coverArt!) : nil,
                streamURL: apiClient.getStreamURL(id: song.id),
                source: .subsonic,
                originalData: song
            )
        } ?? []
        
        return UniversalPlaylist(
            id: playlist.id,
            name: playlist.name,
            curatorName: playlist.owner,
            songCount: songs.count,
            duration: songs.reduce(0) { $0 + $1.duration },
            artworkURL: playlist.coverArt != nil ? apiClient.getCoverArtURL(id: playlist.coverArt!) : nil,
            songs: songs,
            source: .subsonic,
            originalData: playlist
        )
    }
    
    func search(query: String) async throws -> (artists: [UniversalArtist], albums: [UniversalAlbum], songs: [UniversalSong]) {
        let searchResult = try await apiClient.search3(query: query)
        
        let artists = searchResult.artist.compactMap { artist in
            UniversalArtist(
                id: artist.id,
                name: artist.name,
                albumCount: artist.albumCount ?? 0,
                albums: [],
                source: .subsonic,
                originalData: artist
            )
        }
        
        let albums = searchResult.album.compactMap { album in
            UniversalAlbum(
                id: album.id,
                title: album.name,
                artistName: album.artist ?? "",
                year: album.year,
                genre: album.genre,
                songCount: album.songCount ?? 0,
                duration: album.durationTimeInterval,
                artworkURL: album.coverArt != nil ? apiClient.getCoverArtURL(id: album.coverArt!) : nil,
                songs: [],
                source: .subsonic,
                originalData: album
            )
        }
        
        let songs = searchResult.song.compactMap { song in
            UniversalSong(
                id: song.id,
                title: song.title,
                artistName: song.artist ?? "",
                albumName: song.album,
                duration: song.durationTimeInterval,
                trackNumber: song.track,
                artworkURL: song.coverArt != nil ? apiClient.getCoverArtURL(id: song.coverArt!) : nil,
                streamURL: apiClient.getStreamURL(id: song.id),
                source: .subsonic,
                originalData: song
            )
        }
        
        return (artists: artists, albums: albums, songs: songs)
    }
    
    func getStreamURL(for song: UniversalSong) async throws -> URL? {
        return song.streamURL
    }
    
    func reportPlayback(song: UniversalSong) async throws {
        try await apiClient.scrobble(id: song.id)
    }
}

// MARK: - Audio Station数据源实现

class AudioStationDataSource: MusicDataSource {
    @Published var isAvailable: Bool = false
    
    let sourceType: MusicDataSourceType = .audioStation
    private let apiClient: AudioStationAPIClient
    
    init(apiClient: AudioStationAPIClient) {
        self.apiClient = apiClient
    }
    
    func initialize() async throws {
        let connected = try await apiClient.ping()
        await MainActor.run {
            isAvailable = connected
        }
    }
    
    func checkAvailability() async -> Bool {
        do {
            let connected = try await apiClient.ping()
            await MainActor.run {
                isAvailable = connected
            }
            return connected
        } catch {
            await MainActor.run {
                isAvailable = false
            }
            return false
        }
    }
    
    func getRecentAlbums() async throws -> [UniversalAlbum] {
        let albums = try await apiClient.getAlbums()
        
        // 取前50个专辑作为"最新专辑"
        return Array(albums.prefix(50)).compactMap { album in
            UniversalAlbum(
                id: album.id,
                title: album.displayName,
                artistName: album.artistName,
                year: album.year,
                genre: nil,
                songCount: 0, // Audio Station API 不直接提供歌曲数量
                duration: album.durationTimeInterval,
                artworkURL: apiClient.getCoverArtURL(for: album),
                songs: [],
                source: .audioStation,
                originalData: album
            )
        }
    }
    
    func getRecentPlaylists() async throws -> [UniversalPlaylist] {
        let playlists = try await apiClient.getPlaylists()
        
        return playlists.compactMap { playlist in
            UniversalPlaylist(
                id: playlist.id,
                name: playlist.name,
                curatorName: nil,
                songCount: 0, // Audio Station API 不直接提供歌曲数量
                duration: playlist.durationTimeInterval,
                artworkURL: nil, // 播放列表没有封面信息
                songs: [],
                source: .audioStation,
                originalData: playlist
            )
        }
    }
    
    func getArtists() async throws -> [UniversalArtist] {
        let artists = try await apiClient.getArtists()
        
        return artists.compactMap { artist in
            UniversalArtist(
                id: artist.id,
                name: artist.name,
                albumCount: artist.albumCount,
                albums: [],
                source: .audioStation,
                originalData: artist
            )
        }
    }
    
    func getArtist(id: String) async throws -> UniversalArtist {
        // Audio Station API 需要通过专辑列表来获取艺术家详情
        let albums = try await apiClient.getAlbums()
        let artistAlbums = albums.filter { $0.artistName.contains(id) || $0.id == id }
        
        let universalAlbums = artistAlbums.compactMap { album in
            UniversalAlbum(
                id: album.id,
                title: album.displayName,
                artistName: album.artistName,
                year: album.year,
                genre: nil,
                songCount: 0,
                duration: album.durationTimeInterval,
                artworkURL: apiClient.getCoverArtURL(for: album),
                songs: [],
                source: .audioStation,
                originalData: album
            )
        }
        
        guard let firstAlbum = artistAlbums.first else {
            throw MusicDataSourceError.notFound
        }
        
        return UniversalArtist(
            id: id,
            name: firstAlbum.artistName,
            albumCount: artistAlbums.count,
            albums: universalAlbums,
            source: .audioStation,
            originalData: firstAlbum
        )
    }
    
    func getAlbum(id: String) async throws -> UniversalAlbum {
        let album = try await apiClient.getAlbum(id: id)
        
        // 获取专辑中的歌曲
        let allSongs = try await apiClient.getSongs()
        let albumSongs = allSongs.filter { $0.album == album.displayName || $0.album?.contains(album.displayName) == true }
        
        let songs = albumSongs.compactMap { song in
            UniversalSong(
                id: song.id,
                title: song.title,
                artistName: song.artistName,
                albumName: song.album,
                duration: song.durationTimeInterval,
                trackNumber: song.track,
                artworkURL: apiClient.getCoverArtURL(for: song),
                streamURL: apiClient.getStreamURL(id: song.id),
                source: .audioStation,
                originalData: song
            )
        }
        
        return UniversalAlbum(
            id: album.id,
            title: album.displayName,
            artistName: album.artistName,
            year: album.year,
            genre: nil,
            songCount: songs.count,
            duration: songs.reduce(0) { $0 + $1.duration },
            artworkURL: apiClient.getCoverArtURL(for: album),
            songs: songs,
            source: .audioStation,
            originalData: album
        )
    }

    func getPlaylist(id: String) async throws -> UniversalPlaylist {
        // 🔧 修复：使用AudioStationMusicService中的完整实现
        let audioStationService = AudioStationMusicService.shared
        return try await audioStationService.getPlaylist(id: id)
    }
    
    func search(query: String) async throws -> (artists: [UniversalArtist], albums: [UniversalAlbum], songs: [UniversalSong]) {
        let searchResult = try await apiClient.search(query: query)
        
        let artists = searchResult.artists.compactMap { artist in
            UniversalArtist(
                id: artist.id,
                name: artist.name,
                albumCount: artist.albumCount,
                albums: [],
                source: .audioStation,
                originalData: artist
            )
        }
        
        let albums = searchResult.albums.compactMap { album in
            UniversalAlbum(
                id: album.id,
                title: album.displayName,
                artistName: album.artistName,
                year: album.year,
                genre: nil,
                songCount: 0,
                duration: album.durationTimeInterval,
                artworkURL: apiClient.getCoverArtURL(for: album),
                songs: [],
                source: .audioStation,
                originalData: album
            )
        }
        
        let songs = searchResult.songs.compactMap { song in
            UniversalSong(
                id: song.id,
                title: song.title,
                artistName: song.artistName,
                albumName: song.album,
                duration: song.durationTimeInterval,
                trackNumber: song.track,
                artworkURL: apiClient.getCoverArtURL(for: song),
                streamURL: apiClient.getStreamURL(id: song.id),
                source: .audioStation,
                originalData: song
            )
        }
        
        return (artists: artists, albums: albums, songs: songs)
    }
    
    func getStreamURL(for song: UniversalSong) async throws -> URL? {
        return song.streamURL
    }
    
    func reportPlayback(song: UniversalSong) async throws {
        // Audio Station 可能没有播放统计功能，或者需要特殊API
        // 这里暂时留空
    }
}

/// 本地音乐数据源
class LocalDataSource: MusicDataSource {
    // MARK: - 属性
    @Published var isAvailable: Bool = true
    let sourceType: MusicDataSourceType = .local
    private let localMusicService = LocalMusicService.shared
    
    // MARK: - 生命周期
    
    func initialize() async throws {
        try await localMusicService.initialize()
        await MainActor.run {
            isAvailable = localMusicService.isAvailable
        }
    }
    
    func checkAvailability() async -> Bool {
        // 本地音乐服务始终可用
        _ = await localMusicService.checkAvailability()
        await MainActor.run {
            isAvailable = true // 始终设为true以确保本地音乐数据源可用
        }
        return true // 始终返回true以确保本地音乐数据源可用
    }
    
    // MARK: - 数据获取
    
    func getRecentAlbums() async throws -> [UniversalAlbum] {
        return try await localMusicService.getRecentAlbums()
    }
    
    func getRecentPlaylists() async throws -> [UniversalPlaylist] {
        // 本地音乐不支持播放列表
        return []
    }
    
    func getArtists() async throws -> [UniversalArtist] {
        return try await localMusicService.getArtists()
    }
    
    func getArtist(id: String) async throws -> UniversalArtist {
        return try await localMusicService.getArtist(id: id)
    }
    
    func getAlbum(id: String) async throws -> UniversalAlbum {
        return try await localMusicService.getAlbum(id: id)
    }
    
    func getPlaylist(id: String) async throws -> UniversalPlaylist {
        // 本地音乐不支持播放列表
        throw MusicDataSourceError.notSupported
    }
    
    func search(query: String) async throws -> (artists: [UniversalArtist], albums: [UniversalAlbum], songs: [UniversalSong]) {
        // 本地音乐搜索实现
        let allArtists = try await getArtists()
        let allAlbums = try await getRecentAlbums()
        
        let matchedArtists = allArtists.filter { artist in
            artist.name.localizedCaseInsensitiveContains(query)
        }
        
        let matchedAlbums = allAlbums.filter { album in
            album.title.localizedCaseInsensitiveContains(query) ||
            album.artistName.localizedCaseInsensitiveContains(query)
        }
        
        // 收集匹配专辑中的歌曲
        var matchedSongs: [UniversalSong] = []
        for album in matchedAlbums {
            let detailedAlbum = try await getAlbum(id: album.id)
            matchedSongs.append(contentsOf: detailedAlbum.songs.filter { song in
                song.title.localizedCaseInsensitiveContains(query) ||
                song.artistName.localizedCaseInsensitiveContains(query)
            })
        }
        
        return (artists: matchedArtists, albums: matchedAlbums, songs: matchedSongs)
    }
    
    func getStreamURL(for song: UniversalSong) async throws -> URL? {
        return song.streamURL
    }
    
    func reportPlayback(song: UniversalSong) async throws {
        // 本地音乐不需要报告播放记录
    }
}

// MARK: - 数据源错误

enum MusicDataSourceError: LocalizedError {
    case notImplemented
    case invalidID
    case notFound
    case unauthorized
    case notSupported
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "功能尚未实现"
        case .invalidID:
            return "无效的ID"
        case .notFound:
            return "未找到请求的资源"
        case .unauthorized:
            return "未授权访问"
        case .notSupported:
            return "不支持的功能"
        }
    }
}

// MARK: - 日期扩展

extension Date {
    var year: Int {
        Calendar.current.component(.year, from: self)
    }
}