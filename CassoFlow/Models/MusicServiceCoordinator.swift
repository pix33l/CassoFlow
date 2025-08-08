import Foundation
import MusicKit
import Combine

/// 音乐服务协调器 - 统一管理不同的音乐数据源
class MusicServiceCoordinator: ObservableObject {
    
    // MARK: - 数据源管理
    
    @Published var currentDataSource: MusicDataSourceType = .musicKit {
        didSet {
            UserDefaults.standard.set(currentDataSource.rawValue, forKey: Self.dataSourceKey)
            Task {
                await switchDataSource()
            }
        }
    }
    
    // MARK: - 服务实例
    
    private let musicKitDataSource = MusicKitDataSource()
    private let subsonicDataSource: SubsonicDataSource
    private let audioStationDataSource: AudioStationDataSource
    
    // MARK: - 向后兼容的服务引用（用于配置和播放控制）
    
    private let subsonicService = SubsonicMusicService.shared
    private let audioStationService = AudioStationMusicService.shared
    
    // MARK: - 存储键
    
    private static let dataSourceKey = "SelectedDataSource"
    
    // MARK: - 初始化
    
    init() {
        // 初始化数据源
        subsonicDataSource = SubsonicDataSource(apiClient: SubsonicAPIClient.shared)
        audioStationDataSource = AudioStationDataSource(apiClient: AudioStationAPIClient.shared)
        
        loadDataSourcePreference()
        
        Task {
            await initializeDataSources()
        }
    }
    
    // MARK: - 数据源管理
    
    private func loadDataSourcePreference() {
        let savedDataSource = UserDefaults.standard.string(forKey: Self.dataSourceKey)
        if let sourceString = savedDataSource,
           let source = MusicDataSourceType(rawValue: sourceString) {
            currentDataSource = source
        } else {
            currentDataSource = .musicKit // 默认使用Apple Music
        }
    }
    
    private func initializeDataSources() async {
        // 初始化所有数据源
        async let musicKitInit: Void = initializeMusicKit()
        async let subsonicInit: Void = initializeSubsonic()
        async let audioStationInit: Void = initializeAudioStation()
        
        // 并行初始化所有数据源
        let _ = await (musicKitInit, subsonicInit, audioStationInit)
    }
    
    private func initializeMusicKit() async {
        do {
            try await musicKitDataSource.initialize()
        } catch {
            print("MusicKit数据源初始化失败: \(error)")
        }
    }
    
    private func initializeSubsonic() async {
        // 初始化新的数据源
        do {
            try await subsonicDataSource.initialize()
        } catch {
            print("Subsonic数据源初始化失败: \(error)")
        }
        
        // 为了向后兼容，也初始化旧服务（仅用于播放控制）
        do {
            try await subsonicService.initialize()
        } catch {
            print("Subsonic播放服务初始化失败: \(error)")
        }
    }
    
    private func initializeAudioStation() async {
        // 初始化新的数据源
        do {
            try await audioStationDataSource.initialize()
        } catch {
            print("Audio Station数据源初始化失败: \(error)")
        }
        
//        // 为了向后兼容，也初始化旧服务（仅用于播放控制）
//        do {
//            try await audioStationService.initialize()
//        } catch {
//            print("Audio Station播放服务初始化失败: \(error)")
//        }
    }
    
    private func switchDataSource() async {
        // 检查新数据源可用性
        let isAvailable = await checkCurrentDataSourceAvailability()
        if !isAvailable {
            print("所选数据源不可用，切换回Apple Music")
            await MainActor.run {
                currentDataSource = .musicKit
            }
        }
    }
    
    private func checkCurrentDataSourceAvailability() async -> Bool {
        return await activeDataSource.checkAvailability()
    }
    
    // MARK: - 当前数据源获取
    
    /// 获取当前活动的数据源
    private var activeDataSource: any MusicDataSource {
        switch currentDataSource {
        case .musicKit:
            return musicKitDataSource
        case .subsonic:
            return subsonicDataSource
        case .audioStation:
            return audioStationDataSource
        }
    }
    
    // MARK: - 统一数据获取方法（新架构）
    
    /// 获取最近专辑
    func getRecentAlbums() async throws -> [UniversalAlbum] {
        return try await activeDataSource.getRecentAlbums()
    }
    
    /// 获取播放列表
    func getRecentPlaylists() async throws -> [UniversalPlaylist] {
        return try await activeDataSource.getRecentPlaylists()
    }
    
    /// 获取艺术家
    func getArtists() async throws -> [UniversalArtist] {
        return try await activeDataSource.getArtists()
    }
    
    /// 获取艺术家详情
    func getArtist(id: String) async throws -> UniversalArtist {
        return try await activeDataSource.getArtist(id: id)
    }
    
    /// 获取专辑详情
    func getAlbum(id: String) async throws -> UniversalAlbum {
        return try await activeDataSource.getAlbum(id: id)
    }
    
    /// 获取播放列表详情
    func getPlaylist(id: String) async throws -> UniversalPlaylist {
        return try await activeDataSource.getPlaylist(id: id)
    }
    
    /// 搜索音乐
    func search(query: String) async throws -> (artists: [UniversalArtist], albums: [UniversalAlbum], songs: [UniversalSong]) {
        return try await activeDataSource.search(query: query)
    }
    
    /// 获取歌曲流媒体URL
    func getStreamURL(for song: UniversalSong) async throws -> URL? {
        return try await activeDataSource.getStreamURL(for: song)
    }
    
    /// 报告播放记录
    func reportPlayback(song: UniversalSong) async throws {
        try await activeDataSource.reportPlayback(song: song)
    }
    
    // MARK: - 向后兼容的播放服务访问方法
    
    /// 获取Subsonic播放服务（用于播放控制和配置）
    func getSubsonicPlaybackService() -> SubsonicMusicService {
        return subsonicService
    }
    
    /// 获取Audio Station播放服务（用于播放控制和配置）
    func getAudioStationPlaybackService() -> AudioStationMusicService {
        return audioStationService
    }
    
    // MARK: - 数据源实例访问方法
    
    /// 获取MusicKit数据源
    func getMusicKitDataSource() -> MusicKitDataSource {
        return musicKitDataSource
    }
    
    /// 获取Subsonic数据源
    func getSubsonicDataSource() -> SubsonicDataSource {
        return subsonicDataSource
    }
    
    /// 获取Audio Station数据源
    func getAudioStationDataSource() -> AudioStationDataSource {
        return audioStationDataSource
    }
    
    /// 获取当前活动的数据源实例
    func getCurrentDataSource() -> any MusicDataSource {
        return activeDataSource
    }
    
    // MARK: - 状态查询方法
    
    /// 检查当前数据源是否可用
    func isCurrentDataSourceAvailable() async -> Bool {
        return await activeDataSource.checkAvailability()
    }
    
    /// 获取所有数据源的可用性状态
    func getDataSourceStatus() async -> (musicKit: Bool, subsonic: Bool, audioStation: Bool) {
        async let musicKitStatus = musicKitDataSource.checkAvailability()
        async let subsonicStatus = subsonicDataSource.checkAvailability()
        async let audioStationStatus = audioStationDataSource.checkAvailability()
        
        return await (musicKitStatus, subsonicStatus, audioStationStatus)
    }
    
    /// 获取当前数据源信息
    func getCurrentDataSourceInfo() -> (type: MusicDataSourceType, isAvailable: Bool) {
        return (currentDataSource, activeDataSource.isAvailable)
    }
    
    // MARK: - 向后兼容的方法（标记为已废弃，建议使用新方法）
    
//    @available(*, deprecated, message: "请使用 getRecentAlbums() 方法")
//    func getRecentAlbumsUnified() async throws -> [UniversalAlbum] {
//        return try await getRecentAlbums()
//    }
//    
//    @available(*, deprecated, message: "请使用 getRecentPlaylists() 方法")
//    func getRecentPlaylistsUnified() async throws -> [UniversalPlaylist] {
//        return try await getRecentPlaylists()
//    }
//    
//    @available(*, deprecated, message: "请使用 getArtists() 方法")
//    func getArtistsUnified() async throws -> [UniversalArtist] {
//        return try await getArtists()
//    }
//    
//    @available(*, deprecated, message: "请使用 getArtist(id:) 方法")
//    func getArtistUnified(id: String) async throws -> UniversalArtist {
//        return try await getArtist(id: id)
//    }
//    
//    @available(*, deprecated, message: "请使用 getAlbum(id:) 方法")
//    func getAlbumUnified(id: String) async throws -> UniversalAlbum {
//        return try await getAlbum(id: id)
//    }
//    
//    @available(*, deprecated, message: "请使用 getPlaylist(id:) 方法")
//    func getPlaylistUnified(id: String) async throws -> UniversalPlaylist {
//        return try await getPlaylist(id: id)
//    }
//    
//    @available(*, deprecated, message: "请使用 search(query:) 方法")
//    func searchUnified(query: String) async throws -> (artists: [UniversalArtist], albums: [UniversalAlbum], songs: [UniversalSong]) {
//        return try await search(query: query)
//    }
//    
//    @available(*, deprecated, message: "请使用 getSubsonicPlaybackService() 方法")
//    func getSubsonicService() -> SubsonicMusicService {
//        return subsonicService
//    }
//    
//    @available(*, deprecated, message: "请使用 getAudioStationPlaybackService() 方法")
//    func getAudioStationService() -> AudioStationMusicService {
//        return audioStationService
//    }
}

// MARK: - 扩展：批量操作支持

extension MusicServiceCoordinator {
    
    /// 批量获取专辑详情
    func getAlbums(ids: [String]) async throws -> [UniversalAlbum] {
        return try await withThrowingTaskGroup(of: UniversalAlbum?.self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    do {
                        return try await self?.getAlbum(id: id)
                    } catch {
                        print("获取专辑 \(id) 失败: \(error)")
                        return nil
                    }
                }
            }
            
            var albums: [UniversalAlbum] = []
            for try await album in group {
                if let album = album {
                    albums.append(album)
                }
            }
            return albums
        }
    }
    
    /// 批量获取艺术家详情
    func getArtists(ids: [String]) async throws -> [UniversalArtist] {
        return try await withThrowingTaskGroup(of: UniversalArtist?.self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    do {
                        return try await self?.getArtist(id: id)
                    } catch {
                        print("获取艺术家 \(id) 失败: \(error)")
                        return nil
                    }
                }
            }
            
            var artists: [UniversalArtist] = []
            for try await artist in group {
                if let artist = artist {
                    artists.append(artist)
                }
            }
            return artists
        }
    }
}
