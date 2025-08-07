import SwiftUI
import Foundation

/// 音乐详情缓存管理器
@MainActor
class MusicDetailCacheManager: ObservableObject {
    static let shared = MusicDetailCacheManager()
    
    // 缓存容器
    private var albumCache: [String: CachedAlbumDetail] = [:]
    private var playlistCache: [String: CachedPlaylistDetail] = [:]  
    private var artistCache: [String: CachedArtistDetail] = [:]
    
    // 缓存配置
    private let maxCacheSize = 50 // 每种类型最大缓存数量
    
    private init() {}
    
    // MARK: - 专辑缓存
    
    /// 获取缓存的专辑详情
    func getCachedAlbum(id: String) -> UniversalAlbum? {
        return albumCache[id]?.album
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
    }
    
    /// 清除指定专辑的缓存
    func clearAlbumCache(id: String) {
        albumCache.removeValue(forKey: id)
    }
    
    // MARK: - 播放列表缓存
    
    /// 获取缓存的播放列表详情
    func getCachedPlaylist(id: String) -> UniversalPlaylist? {
        return playlistCache[id]?.playlist
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
    }
    
    /// 清除指定播放列表的缓存
    func clearPlaylistCache(id: String) {
        playlistCache.removeValue(forKey: id)
    }
    
    // MARK: - 艺术家缓存
    
    /// 获取缓存的艺术家详情
    func getCachedArtist(id: String) -> UniversalArtist? {
        return artistCache[id]?.artist
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
    }
    
    /// 清除指定艺术家的缓存
    func clearArtistCache(id: String) {
        artistCache.removeValue(forKey: id)
    }
    
    // MARK: - 缓存管理
    
    /// 清理所有缓存
    func clearAllCache() {
        albumCache.removeAll()
        playlistCache.removeAll()
        artistCache.removeAll()
    }
    
    /// 获取缓存统计信息
    func getCacheStats() -> (albums: Int, playlists: Int, artists: Int) {
        return (albumCache.count, playlistCache.count, artistCache.count)
    }
}

// MARK: - 缓存数据结构

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