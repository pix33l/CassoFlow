import SwiftUI
import Foundation

/// 音乐详情缓存管理器
@MainActor
class MusicDetailCacheManager: ObservableObject {
    static let shared = MusicDetailCacheManager()
    
    // 内存缓存容器
    private var albumCache: [String: CachedAlbumDetail] = [:]
    private var playlistCache: [String: CachedPlaylistDetail] = [:]  
    private var artistCache: [String: CachedArtistDetail] = [:]
    
    // 缓存配置
    private let maxCacheSize = 100 // 增加缓存数量
    private let cacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24小时缓存有效期
    
    // 持久化缓存键
    private let albumCacheKey = "MusicDetailAlbumCache"
    private let playlistCacheKey = "MusicDetailPlaylistCache"
    private let artistCacheKey = "MusicDetailArtistCache"
    
    private init() {
        loadPersistentCaches()
    }
    
    // MARK: - 持久化管理
    
    /// 加载持久化缓存
    private func loadPersistentCaches() {
        // 加载专辑缓存
        if let data = UserDefaults.standard.data(forKey: albumCacheKey) {
            do {
                let persistentAlbums = try JSONDecoder().decode([String: PersistentAlbumDetail].self, from: data)
                for (id, persistent) in persistentAlbums {
                    if !persistent.isExpired {
                        albumCache[id] = CachedAlbumDetail(
                            album: persistent.toUniversalAlbum(),
                            timestamp: persistent.timestamp
                        )
                    }
                }
                print("📦 加载了 \(albumCache.count) 个专辑缓存")
            } catch {
                print("❌ 专辑缓存加载失败: \(error)")
            }
        }
        
        // 加载播放列表缓存
        if let data = UserDefaults.standard.data(forKey: playlistCacheKey) {
            do {
                let persistentPlaylists = try JSONDecoder().decode([String: PersistentPlaylistDetail].self, from: data)
                for (id, persistent) in persistentPlaylists {
                    if !persistent.isExpired {
                        playlistCache[id] = CachedPlaylistDetail(
                            playlist: persistent.toUniversalPlaylist(),
                            timestamp: persistent.timestamp
                        )
                    }
                }
                print("📦 加载了 \(playlistCache.count) 个播放列表缓存")
            } catch {
                print("❌ 播放列表缓存加载失败: \(error)")
            }
        }
        
        // 加载艺术家缓存
        if let data = UserDefaults.standard.data(forKey: artistCacheKey) {
            do {
                let persistentArtists = try JSONDecoder().decode([String: PersistentArtistDetail].self, from: data)
                for (id, persistent) in persistentArtists {
                    if !persistent.isExpired {
                        artistCache[id] = CachedArtistDetail(
                            artist: persistent.toUniversalArtist(),
                            timestamp: persistent.timestamp
                        )
                    }
                }
                print("📦 加载了 \(artistCache.count) 个艺术家缓存")
            } catch {
                print("❌ 艺术家缓存加载失败: \(error)")
            }
        }
    }
    
    /// 保存持久化缓存
    private func savePersistentCaches() {
        // 保存专辑缓存
        let persistentAlbums = albumCache.mapValues { cached in
            PersistentAlbumDetail(from: cached.album, timestamp: cached.timestamp)
        }
        if let encoded = try? JSONEncoder().encode(persistentAlbums) {
            UserDefaults.standard.set(encoded, forKey: albumCacheKey)
        }
        
        // 保存播放列表缓存
        let persistentPlaylists = playlistCache.mapValues { cached in
            PersistentPlaylistDetail(from: cached.playlist, timestamp: cached.timestamp)
        }
        if let encoded = try? JSONEncoder().encode(persistentPlaylists) {
            UserDefaults.standard.set(encoded, forKey: playlistCacheKey)
        }
        
        // 保存艺术家缓存
        let persistentArtists = artistCache.mapValues { cached in
            PersistentArtistDetail(from: cached.artist, timestamp: cached.timestamp)
        }
        if let encoded = try? JSONEncoder().encode(persistentArtists) {
            UserDefaults.standard.set(encoded, forKey: artistCacheKey)
        }
        
        print("💾 持久化缓存已保存")
    }
    
    // MARK: - 专辑缓存
    
    /// 获取缓存的专辑详情
    func getCachedAlbum(id: String) -> UniversalAlbum? {
        guard let cached = albumCache[id] else { return nil }
        
        // 检查缓存是否过期
        if Date().timeIntervalSince(cached.timestamp) > cacheValidityDuration {
            albumCache.removeValue(forKey: id)
            return nil
        }
        
        return cached.album
    }
    
    /// 缓存专辑详情
    func cacheAlbum(_ album: UniversalAlbum, id: String) {
        // 如果缓存已满，移除最旧的项目
        if albumCache.count >= maxCacheSize {
            let oldestKey = albumCache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let key = oldestKey {
                albumCache.removeValue(forKey: key)
            }
        }
        
        albumCache[id] = CachedAlbumDetail(album: album, timestamp: Date())
        print("💾 专辑已缓存: \(id) - \(album.title)")
        
        // 立即保存到持久化存储
        savePersistentCaches()
    }
    
    /// 更新专辑缓存时间戳
    func updateAlbumCacheTimestamp(id: String) {
        guard let cached = albumCache[id] else { return }
        albumCache[id] = CachedAlbumDetail(album: cached.album, timestamp: Date())
        savePersistentCaches()
    }
    
    /// 检查专辑缓存是否需要刷新
    func shouldRefreshAlbumCache(id: String) -> Bool {
        guard let cached = albumCache[id] else { return true }
        let staleThreshold: TimeInterval = 2 * 60 * 60 // 2小时后开始后台刷新
        return Date().timeIntervalSince(cached.timestamp) > staleThreshold
    }
    
    /// 清除指定专辑的缓存
    func clearAlbumCache(id: String) {
        albumCache.removeValue(forKey: id)
        savePersistentCaches()
    }
    
    // MARK: - 播放列表缓存
    
    /// 获取缓存的播放列表详情
    func getCachedPlaylist(id: String) -> UniversalPlaylist? {
        guard let cached = playlistCache[id] else { return nil }
        
        // 检查缓存是否过期
        if Date().timeIntervalSince(cached.timestamp) > cacheValidityDuration {
            playlistCache.removeValue(forKey: id)
            return nil
        }
        
        return cached.playlist
    }
    
    /// 缓存播放列表详情
    func cachePlaylist(_ playlist: UniversalPlaylist, id: String) {
        // 如果缓存已满，移除最旧的项目
        if playlistCache.count >= maxCacheSize {
            let oldestKey = playlistCache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let key = oldestKey {
                playlistCache.removeValue(forKey: key)
            }
        }
        
        playlistCache[id] = CachedPlaylistDetail(playlist: playlist, timestamp: Date())
        print("💾 播放列表已缓存: \(id) - \(playlist.name)")
        
        // 立即保存到持久化存储
        savePersistentCaches()
    }
    
    /// 更新播放列表缓存时间戳
    func updatePlaylistCacheTimestamp(id: String) {
        guard let cached = playlistCache[id] else { return }
        playlistCache[id] = CachedPlaylistDetail(playlist: cached.playlist, timestamp: Date())
        savePersistentCaches()
    }
    
    /// 检查播放列表缓存是否需要刷新
    func shouldRefreshPlaylistCache(id: String) -> Bool {
        guard let cached = playlistCache[id] else { return true }
        let staleThreshold: TimeInterval = 2 * 60 * 60 // 2小时后开始后台刷新
        return Date().timeIntervalSince(cached.timestamp) > staleThreshold
    }
    
    /// 清除指定播放列表的缓存
    func clearPlaylistCache(id: String) {
        playlistCache.removeValue(forKey: id)
        savePersistentCaches()
    }
    
    // MARK: - 艺术家缓存
    
    /// 获取缓存的艺术家详情
    func getCachedArtist(id: String) -> UniversalArtist? {
        guard let cached = artistCache[id] else { return nil }
        
        // 检查缓存是否过期
        if Date().timeIntervalSince(cached.timestamp) > cacheValidityDuration {
            artistCache.removeValue(forKey: id)
            return nil
        }
        
        return cached.artist
    }
    
    /// 缓存艺术家详情
    func cacheArtist(_ artist: UniversalArtist, id: String) {
        // 如果缓存已满，移除最旧的项目
        if artistCache.count >= maxCacheSize {
            let oldestKey = artistCache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let key = oldestKey {
                artistCache.removeValue(forKey: key)
            }
        }
        
        artistCache[id] = CachedArtistDetail(artist: artist, timestamp: Date())
        print("💾 艺术家已缓存: \(id) - \(artist.name)")
        
        // 立即保存到持久化存储
        savePersistentCaches()
    }
    
    /// 更新艺术家缓存时间戳
    func updateArtistCacheTimestamp(id: String) {
        guard let cached = artistCache[id] else { return }
        artistCache[id] = CachedArtistDetail(artist: cached.artist, timestamp: Date())
        savePersistentCaches()
    }
    
    /// 检查艺术家缓存是否需要刷新
    func shouldRefreshArtistCache(id: String) -> Bool {
        guard let cached = artistCache[id] else { return true }
        let staleThreshold: TimeInterval = 2 * 60 * 60 // 2小时后开始后台刷新
        return Date().timeIntervalSince(cached.timestamp) > staleThreshold
    }
    
    /// 清除指定艺术家的缓存
    func clearArtistCache(id: String) {
        artistCache.removeValue(forKey: id)
        savePersistentCaches()
    }
    
    // MARK: - 缓存管理
    
    /// 清理所有缓存
    func clearAllCache() {
        albumCache.removeAll()
        playlistCache.removeAll()
        artistCache.removeAll()
        
        UserDefaults.standard.removeObject(forKey: albumCacheKey)
        UserDefaults.standard.removeObject(forKey: playlistCacheKey)
        UserDefaults.standard.removeObject(forKey: artistCacheKey)
        
        print("🗑️ 所有音乐详情缓存已清理")
    }
    
    /// 清理过期缓存
    func clearExpiredCache() {
        let now = Date()
        
        // 清理过期专辑缓存
        albumCache = albumCache.filter { _, cached in
            now.timeIntervalSince(cached.timestamp) <= cacheValidityDuration
        }
        
        // 清理过期播放列表缓存
        playlistCache = playlistCache.filter { _, cached in
            now.timeIntervalSince(cached.timestamp) <= cacheValidityDuration
        }
        
        // 清理过期艺术家缓存
        artistCache = artistCache.filter { _, cached in
            now.timeIntervalSince(cached.timestamp) <= cacheValidityDuration
        }
        
        savePersistentCaches()
        print("🧹 过期缓存已清理")
    }
    
    /// 获取缓存统计信息
    func getCacheStats() -> (albums: Int, playlists: Int, artists: Int) {
        return (albumCache.count, playlistCache.count, artistCache.count)
    }
}

// MARK: - 持久化缓存数据结构

private struct PersistentAlbumDetail: Codable {
    let id: String
    let title: String
    let artistName: String
    let year: Int?
    let genre: String?
    let songCount: Int
    let duration: TimeInterval
    let artworkURL: URL?
    let songs: [PersistentSong]
    let source: String
    let timestamp: Date
    
    var isExpired: Bool {
        let cacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24小时
        return Date().timeIntervalSince(timestamp) > cacheValidityDuration
    }
    
    init(from album: UniversalAlbum, timestamp: Date) {
        self.id = album.id
        self.title = album.title
        self.artistName = album.artistName
        self.year = album.year
        self.genre = album.genre
        self.songCount = album.songCount
        self.duration = album.duration
        self.artworkURL = album.artworkURL
        self.songs = album.songs.map { PersistentSong(from: $0) }
        self.source = album.source.rawValue
        self.timestamp = timestamp
    }
    
    func toUniversalAlbum() -> UniversalAlbum {
        UniversalAlbum(
            id: id,
            title: title,
            artistName: artistName,
            year: year,
            genre: genre,
            songCount: songCount,
            duration: duration,
            artworkURL: artworkURL,
            songs: songs.map { $0.toUniversalSong() },
            source: MusicDataSourceType(rawValue: source) ?? .subsonic,
            originalData: ()
        )
    }
}

private struct PersistentPlaylistDetail: Codable {
    let id: String
    let name: String
    let curatorName: String?
    let songCount: Int
    let duration: TimeInterval
    let artworkURL: URL?
    let songs: [PersistentSong]
    let source: String
    let timestamp: Date
    
    var isExpired: Bool {
        let cacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24小时
        return Date().timeIntervalSince(timestamp) > cacheValidityDuration
    }
    
    init(from playlist: UniversalPlaylist, timestamp: Date) {
        self.id = playlist.id
        self.name = playlist.name
        self.curatorName = playlist.curatorName
        self.songCount = playlist.songCount
        self.duration = playlist.duration
        self.artworkURL = playlist.artworkURL
        self.songs = playlist.songs.map { PersistentSong(from: $0) }
        self.source = playlist.source.rawValue
        self.timestamp = timestamp
    }
    
    func toUniversalPlaylist() -> UniversalPlaylist {
        UniversalPlaylist(
            id: id,
            name: name,
            curatorName: curatorName,
            songCount: songCount,
            duration: duration,
            artworkURL: artworkURL,
            songs: songs.map { $0.toUniversalSong() },
            source: MusicDataSourceType(rawValue: source) ?? .subsonic,
            originalData: ()
        )
    }
}

private struct PersistentArtistDetail: Codable {
    let id: String
    let name: String
    let albumCount: Int
    let albums: [PersistentAlbumBrief] // 只保存简要信息
    let source: String
    let timestamp: Date
    
    var isExpired: Bool {
        let cacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24小时
        return Date().timeIntervalSince(timestamp) > cacheValidityDuration
    }
    
    init(from artist: UniversalArtist, timestamp: Date) {
        self.id = artist.id
        self.name = artist.name
        self.albumCount = artist.albumCount
        self.albums = artist.albums.map { PersistentAlbumBrief(from: $0) }
        self.source = artist.source.rawValue
        self.timestamp = timestamp
    }
    
    func toUniversalArtist() -> UniversalArtist {
        UniversalArtist(
            id: id,
            name: name,
            albumCount: albumCount,
            albums: albums.map { $0.toUniversalAlbum() },
            source: MusicDataSourceType(rawValue: source) ?? .subsonic,
            originalData: ()
        )
    }
}

private struct PersistentSong: Codable {
    let id: String
    let title: String
    let artistName: String
    let albumName: String?
    let duration: TimeInterval
    let trackNumber: Int?
    let artworkURL: URL?
    let streamURL: URL?
    let source: String
    
    init(from song: UniversalSong) {
        self.id = song.id
        self.title = song.title
        self.artistName = song.artistName
        self.albumName = song.albumName
        self.duration = song.duration
        self.trackNumber = song.trackNumber
        self.artworkURL = song.artworkURL
        self.streamURL = song.streamURL
        self.source = song.source.rawValue
    }
    
    func toUniversalSong() -> UniversalSong {
        UniversalSong(
            id: id,
            title: title,
            artistName: artistName,
            albumName: albumName,
            duration: duration,
            trackNumber: trackNumber,
            artworkURL: artworkURL,
            streamURL: streamURL,
            source: MusicDataSourceType(rawValue: source) ?? .subsonic,
            originalData: ()
        )
    }
}

private struct PersistentAlbumBrief: Codable {
    let id: String
    let title: String
    let artistName: String
    let year: Int?
    let genre: String?
    let songCount: Int
    let duration: TimeInterval
    let artworkURL: URL?
    let source: String
    
    init(from album: UniversalAlbum) {
        self.id = album.id
        self.title = album.title
        self.artistName = album.artistName
        self.year = album.year
        self.genre = album.genre
        self.songCount = album.songCount
        self.duration = album.duration
        self.artworkURL = album.artworkURL
        self.source = album.source.rawValue
    }
    
    func toUniversalAlbum() -> UniversalAlbum {
        UniversalAlbum(
            id: id,
            title: title,
            artistName: artistName,
            year: year,
            genre: genre,
            songCount: songCount,
            duration: duration,
            artworkURL: artworkURL,
            songs: [], // 艺术家页面的专辑不需要完整歌曲列表
            source: MusicDataSourceType(rawValue: source) ?? .subsonic,
            originalData: ()
        )
    }
}

// MARK: - 内存缓存数据结构

private struct CachedAlbumDetail {
    let album: UniversalAlbum
    let timestamp: Date
}

private struct CachedPlaylistDetail {
    let playlist: UniversalPlaylist
    let timestamp: Date
}

private struct CachedArtistDetail {
    let artist: UniversalArtist
    let timestamp: Date
}