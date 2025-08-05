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
    private let subsonicService = SubsonicMusicService.shared
    
    // MARK: - 存储键
    
    private static let dataSourceKey = "SelectedDataSource"
    
    // MARK: - 初始化
    
    init() {
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
        // 初始化MusicKit
        do {
            try await musicKitDataSource.initialize()
        } catch {
            print("MusicKit初始化失败: \(error)")
        }
        
        // 初始化Subsonic
        do {
            try await subsonicService.initialize()
        } catch {
            print("Subsonic初始化失败: \(error)")
        }
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
        switch currentDataSource {
        case .musicKit:
            return await musicKitDataSource.checkAvailability()
        case .subsonic:
            return await subsonicService.checkAvailability()
        }
    }
    
    // MARK: - 数据获取方法
    
    /// 获取最近专辑
    func getRecentAlbums() async throws -> [UniversalAlbum] {
        switch currentDataSource {
        case .musicKit:
            return try await musicKitDataSource.getRecentAlbums()
        case .subsonic:
            return try await subsonicService.getRecentAlbums()
        }
    }
    
    /// 获取播放列表
    func getRecentPlaylists() async throws -> [UniversalPlaylist] {
        switch currentDataSource {
        case .musicKit:
            return try await musicKitDataSource.getRecentPlaylists()
        case .subsonic:
            return try await subsonicService.getPlaylists()
        }
    }
    
    /// 获取艺术家
    func getArtists() async throws -> [UniversalArtist] {
        switch currentDataSource {
        case .musicKit:
            return try await musicKitDataSource.getArtists()
        case .subsonic:
            return try await subsonicService.getArtists()
        }
    }
    
    /// 获取艺术家详情
    func getArtist(id: String) async throws -> UniversalArtist {
        switch currentDataSource {
        case .musicKit:
            return try await musicKitDataSource.getArtist(id: id)
        case .subsonic:
            return try await subsonicService.getArtist(id: id)
        }
    }
    
    /// 获取专辑详情
    func getAlbum(id: String) async throws -> UniversalAlbum {
        switch currentDataSource {
        case .musicKit:
            return try await musicKitDataSource.getAlbum(id: id)
        case .subsonic:
            return try await subsonicService.getAlbum(id: id)
        }
    }
    
    /// 获取播放列表详情
    func getPlaylist(id: String) async throws -> UniversalPlaylist {
        switch currentDataSource {
        case .musicKit:
            return try await musicKitDataSource.getPlaylist(id: id)
        case .subsonic:
            return try await subsonicService.getPlaylist(id: id)
        }
    }
    
    /// 搜索音乐
    func search(query: String) async throws -> (artists: [UniversalArtist], albums: [UniversalAlbum], songs: [UniversalSong]) {
        switch currentDataSource {
        case .musicKit:
            return try await musicKitDataSource.search(query: query)
        case .subsonic:
            return try await subsonicService.search(query: query)
        }
    }
    
    // MARK: - 服务访问方法
    
    /// 获取Subsonic服务（用于配置等）
    func getSubsonicService() -> SubsonicMusicService {
        return subsonicService
    }
    
    /// 获取MusicKit数据源
    func getMusicKitDataSource() -> MusicKitDataSource {
        return musicKitDataSource
    }
    
    /// 检查当前数据源是否可用
    func isCurrentDataSourceAvailable() async -> Bool {
        return await checkCurrentDataSourceAvailability()
    }
    
    /// 获取数据源状态
    func getDataSourceStatus() -> (musicKit: Bool, subsonic: Bool) {
        return (musicKitDataSource.isAvailable, subsonicService.isAvailable)
    }
}
