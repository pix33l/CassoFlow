import SwiftUI
import Foundation

/// 音乐库缓存管理器 - 统一管理音乐库数据的缓存和预加载
@MainActor
class MusicLibraryCacheManager: ObservableObject {
    static let shared = MusicLibraryCacheManager()
    
    // MARK: - 库数据缓存
    private var libraryCache: [String: CachedLibraryData] = [:]
    private let maxLibraryCacheSize = 5 // 最多缓存5个不同的库
    private let libraryCacheValidityDuration: TimeInterval = 30 * 60 // 30分钟有效期
    
    // MARK: - 持久化存储配置
    private let persistentStorageKey = "MusicLibraryPersistentCache"
    private let persistentCacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24小时有效期
    
    // MARK: - 预加载配置
    private let preloadAlbumCount = 10 // 预加载专辑数量
    private let preloadPlaylistCount = 20 // 预加载播放列表数量
    private let preloadArtistCount = 15 // 预加载艺术家数量
    
    // MARK: - 依赖的管理器
    private let imageCache = ImageCacheManager.shared
    private let detailCache = MusicDetailCacheManager.shared
    
    private init() {
        // 初始化时从持久化存储加载数据
        loadFromPersistentStorage()
    }
    
    // MARK: - 库数据缓存
    
    /// 缓存库数据
    func cacheLibraryData(
        albums: [UniversalAlbum],
        playlists: [UniversalPlaylist],
        artists: [UniversalArtist],
        for source: String
    ) {
        let cacheKey = "library_\(source)"
        
        // 如果缓存已满，移除最旧的项目
        if libraryCache.count >= maxLibraryCacheSize {
            let oldestKey = libraryCache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let key = oldestKey {
                libraryCache.removeValue(forKey: key)
            }
        }
        
        libraryCache[cacheKey] = CachedLibraryData(
            albums: albums,
            playlists: playlists,
            artists: artists,
            timestamp: Date()
        )
        
        // 同时保存到持久化存储
        saveToPersistentStorage()
        
        print("📚 音乐库数据已缓存: \(source) - 专辑:\(albums.count), 播放列表:\(playlists.count), 艺术家:\(artists.count)")
    }
    
    /// 获取缓存的库数据
    func getCachedLibraryData(for source: String) -> (albums: [UniversalAlbum], playlists: [UniversalPlaylist], artists: [UniversalArtist])? {
        let cacheKey = "library_\(source)"
        guard let cached = libraryCache[cacheKey] else { return nil }
        
        // 检查缓存是否过期
        if Date().timeIntervalSince(cached.timestamp) > libraryCacheValidityDuration {
            libraryCache.removeValue(forKey: cacheKey)
            return nil
        }
        
        return (cached.albums, cached.playlists, cached.artists)
    }
    
    /// 从持久化存储加载数据
    private func loadFromPersistentStorage() {
        guard let data = UserDefaults.standard.data(forKey: persistentStorageKey) else {
            print("📚 没有找到持久化的库数据")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let persistentData = try decoder.decode([String: PersistentLibraryData].self, from: data)
            
            for (key, data) in persistentData {
                // 检查持久化数据是否过期
                if Date().timeIntervalSince(data.timestamp) <= persistentCacheValidityDuration {
                    libraryCache[key] = CachedLibraryData(
                        albums: data.albums.map { $0.toUniversalAlbum() },
                        playlists: data.playlists.map { $0.toUniversalPlaylist() },
                        artists: data.artists.map { $0.toUniversalArtist() },
                        timestamp: data.timestamp
                    )
                }
            }
            
            print("📚 从持久化存储加载了 \(libraryCache.count) 个库的数据")
        } catch {
            print("❌ 从持久化存储加载数据失败: \(error)")
        }
    }
    
    /// 保存数据到持久化存储
    private func saveToPersistentStorage() {
        var persistentData: [String: PersistentLibraryData] = [:]
        
        for (key, data) in libraryCache {
            persistentData[key] = PersistentLibraryData(
                albums: data.albums.map { PersistentAlbum(from: $0) },
                playlists: data.playlists.map { PersistentPlaylist(from: $0) },
                artists: data.artists.map { PersistentArtist(from: $0) },
                timestamp: data.timestamp
            )
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(persistentData)
            UserDefaults.standard.set(data, forKey: persistentStorageKey)
            print("📚 库数据已保存到持久化存储")
        } catch {
            print("❌ 保存数据到持久化存储失败: \(error)")
        }
    }
    
    /// 检查库缓存是否需要刷新
    func shouldRefreshLibraryCache(for source: String) -> Bool {
        let cacheKey = "library_\(source)"
        guard let cached = libraryCache[cacheKey] else { return true }
        
        let staleThreshold: TimeInterval = 10 * 60 // 10分钟后开始后台刷新
        return Date().timeIntervalSince(cached.timestamp) > staleThreshold
    }
    
    /// 清除指定源的库缓存
    func clearLibraryCache(for source: String) {
        let cacheKey = "library_\(source)"
        libraryCache.removeValue(forKey: cacheKey)
        saveToPersistentStorage() // 更新持久化存储
        print("🗑️ 已清除 \(source) 的库缓存")
    }
    
    /// 清除所有库缓存
    func clearAllLibraryCache() {
        libraryCache.removeAll()
        UserDefaults.standard.removeObject(forKey: persistentStorageKey) // 清除持久化存储
        print("🗑️ 已清除所有库缓存")
    }
    
    // MARK: - 智能预加载
    
    /// 预加载库数据的封面和详情
    func preloadLibraryData(
        albums: [UniversalAlbum],
        playlists: [UniversalPlaylist],
        artists: [UniversalArtist],
        audioStationService: AudioStationMusicService? = nil,
        subsonicService: SubsonicMusicService? = nil
    ) {
        print("🚀 开始预加载音乐库数据...")
        
        // 并行预加载不同类型的数据
        Task {
            async let albumTask: () = preloadAlbumData(albums, audioStationService: audioStationService, subsonicService: subsonicService)
            async let playlistTask: () = preloadPlaylistData(playlists)
            async let artistTask: () = preloadArtistData(artists, audioStationService: audioStationService, subsonicService: subsonicService)
            
            let (_, _, _) = await (albumTask, playlistTask, artistTask)
            
            print("✅ 音乐库数据预加载完成")
        }
    }
    
    /// 预加载专辑数据
    private func preloadAlbumData(
        _ albums: [UniversalAlbum],
        audioStationService: AudioStationMusicService?,
        subsonicService: SubsonicMusicService?
    ) async {
        // 预加载前N个专辑的封面
        for album in albums.prefix(preloadAlbumCount) {
            if let artworkURL = album.artworkURL {
                imageCache.preloadImage(from: artworkURL)
            }
            
            // 如果有AudioStation服务，预加载专辑详情
            if let service = audioStationService {
                Task {
                    do {
                        let detailedAlbum = try await service.getAlbum(id: album.id)
                        // 缓存专辑详情
                        detailCache.cacheAlbum(detailedAlbum, id: album.id)
                        
                        // 预加载专辑内歌曲的封面
                        for song in detailedAlbum.songs.prefix(5) {
                            if let artworkURL = song.artworkURL {
                                imageCache.preloadImage(from: artworkURL)
                            }
                        }
                    } catch {
                        print("❌ 预加载专辑详情失败: \(album.title) - \(error)")
                    }
                }
            }
            
            // 如果有Subsonic服务，预加载专辑详情
            if let service = subsonicService {
                Task {
                    do {
                        let detailedAlbum = try await service.getAlbum(id: album.id)
                        // 缓存专辑详情
                        detailCache.cacheAlbum(detailedAlbum, id: album.id)
                        
                        // 预加载专辑内歌曲的封面
                        for song in detailedAlbum.songs.prefix(5) {
                            if let artworkURL = song.artworkURL {
                                imageCache.preloadImage(from: artworkURL)
                            }
                        }
                    } catch {
                        print("❌ 预加载专辑详情失败: \(album.title) - \(error)")
                    }
                }
            }
        }
    }
    
    /// 预加载播放列表数据
    private func preloadPlaylistData(_ playlists: [UniversalPlaylist]) async {
        // 预加载前N个播放列表的封面
        for playlist in playlists.prefix(preloadPlaylistCount) {
            if let artworkURL = playlist.artworkURL {
                imageCache.preloadImage(from: artworkURL)
            }
        }
    }
    
    /// 预加载艺术家数据
    private func preloadArtistData(
        _ artists: [UniversalArtist],
        audioStationService: AudioStationMusicService?,
        subsonicService: SubsonicMusicService?
    ) async {
        // 预加载前N个艺术家的专辑封面
        for artist in artists.prefix(preloadArtistCount) {
            // 如果有AudioStation服务，预加载艺术家详情
            if let service = audioStationService {
                Task {
                    do {
                        let detailedArtist = try await service.getArtist(id: artist.id)
                        // 缓存艺术家详情
                        detailCache.cacheArtist(detailedArtist, id: artist.id)
                        
                        // 预加载艺术家专辑的封面
                        for album in detailedArtist.albums.prefix(3) {
                            if let artworkURL = album.artworkURL {
                                imageCache.preloadImage(from: artworkURL)
                            }
                        }
                    } catch {
                        print("❌ 预加载艺术家详情失败: \(artist.name) - \(error)")
                    }
                }
            }
            
            // 如果有Subsonic服务，预加载艺术家详情
            if let service = subsonicService {
                Task {
                    do {
                        let detailedArtist = try await service.getArtist(id: artist.id)
                        // 缓存艺术家详情
                        detailCache.cacheArtist(detailedArtist, id: artist.id)
                        
                        // 预加载艺术家专辑的封面
                        for album in detailedArtist.albums.prefix(3) {
                            if let artworkURL = album.artworkURL {
                                imageCache.preloadImage(from: artworkURL)
                            }
                        }
                    } catch {
                        print("❌ 预加载艺术家详情失败: \(artist.name) - \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - 后台刷新
    
    /// 后台刷新库数据（不阻塞UI）
    func backgroundRefreshLibraryData(
        for source: String,
        loadFunction: @escaping () async throws -> (albums: [UniversalAlbum], playlists: [UniversalPlaylist], artists: [UniversalArtist])
    ) {
        guard shouldRefreshLibraryCache(for: source) else {
            print("📚 库数据仍然新鲜，无需后台刷新")
            return
        }
        
        print("🔄 开始后台刷新库数据: \(source)")
        
        Task {
            do {
                let (albums, playlists, artists) = try await loadFunction()
                
                await MainActor.run {
                    cacheLibraryData(
                        albums: albums,
                        playlists: playlists,
                        artists: artists,
                        for: source
                    )
                    
                    // 触发预加载
                    preloadLibraryData(
                        albums: albums,
                        playlists: playlists,
                        artists: artists
                    )
                }
                
                print("✅ 后台刷新完成: \(source)")
            } catch {
                print("❌ 后台刷新失败: \(source) - \(error)")
            }
        }
    }
    
    // MARK: - 缓存统计
    
    /// 获取缓存统计信息
    func getCacheStats() -> (
        libraryCacheCount: Int,
        imageCache: (memoryCount: Int, diskSizeMB: Double),
        detailCache: (albums: Int, playlists: Int, artists: Int)
    ) {
        let libraryCacheCount = libraryCache.count
        let imageCacheStats = imageCache.getCacheStats()
        let detailCacheStats = detailCache.getCacheStats()
        
        return (
            libraryCacheCount: libraryCacheCount,
            imageCache: imageCacheStats,
            detailCache: detailCacheStats
        )
    }
    
    /// 清理所有缓存
    func clearAllCache() {
        clearAllLibraryCache()
        imageCache.clearCache()
        detailCache.clearAllCache()
        print("🗑️ 所有缓存已清理")
    }
}

// MARK: - 缓存数据结构

private struct CachedLibraryData {
    let albums: [UniversalAlbum]
    let playlists: [UniversalPlaylist]
    let artists: [UniversalArtist]
    let timestamp: Date
}

// MARK: - 持久化存储数据结构

/// 用于持久化存储的简化专辑数据
private struct PersistentAlbum: Codable {
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
            songs: [], // 持久化存储中不保存歌曲详情
            source: MusicDataSourceType(rawValue: source) ?? .local,
            originalData: () // 使用空元组作为占位符
        )
    }
}

/// 用于持久化存储的简化播放列表数据
private struct PersistentPlaylist: Codable {
    let id: String
    let name: String
    let curatorName: String?
    let songCount: Int
    let duration: TimeInterval
    let artworkURL: URL?
    let source: String
    
    init(from playlist: UniversalPlaylist) {
        self.id = playlist.id
        self.name = playlist.name
        self.curatorName = playlist.curatorName
        self.songCount = playlist.songCount
        self.duration = playlist.duration
        self.artworkURL = playlist.artworkURL
        self.source = playlist.source.rawValue
    }
    
    func toUniversalPlaylist() -> UniversalPlaylist {
        UniversalPlaylist(
            id: id,
            name: name,
            curatorName: curatorName,
            songCount: songCount,
            duration: duration,
            artworkURL: artworkURL,
            songs: [], // 持久化存储中不保存歌曲详情
            source: MusicDataSourceType(rawValue: source) ?? .local,
            originalData: () // 使用空元组作为占位符
        )
    }
}

/// 用于持久化存储的简化艺术家数据
private struct PersistentArtist: Codable {
    let id: String
    let name: String
    let albumCount: Int
    let source: String
    
    init(from artist: UniversalArtist) {
        self.id = artist.id
        self.name = artist.name
        self.albumCount = artist.albumCount
        self.source = artist.source.rawValue
    }
    
    func toUniversalArtist() -> UniversalArtist {
        UniversalArtist(
            id: id,
            name: name,
            albumCount: albumCount,
            albums: [], // 持久化存储中不保存专辑详情
            source: MusicDataSourceType(rawValue: source) ?? .local,
            originalData: () // 使用空元组作为占位符
        )
    }
}

/// 用于持久化存储的库数据结构
private struct PersistentLibraryData: Codable {
    let albums: [PersistentAlbum]
    let playlists: [PersistentPlaylist]
    let artists: [PersistentArtist]
    let timestamp: Date
}