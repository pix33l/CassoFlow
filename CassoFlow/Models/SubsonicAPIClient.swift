import Foundation
import CryptoKit

/// Subsonic API 客户端
class SubsonicAPIClient: ObservableObject {
    // MARK: - 配置属性
    @Published var serverURL: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isConnected: Bool = false
    
    private let apiVersion = "1.16.1"
    private let clientName = "CassoFlow"
    
    // MARK: - 存储键
    private static let serverURLKey = "SubsonicServerURL"
    private static let usernameKey = "SubsonicUsername"
    private static let passwordKey = "SubsonicPassword"
    
    init() {
        loadConfiguration()
    }
    
    // MARK: - 配置管理
    
    /// 保存配置到UserDefaults
    func saveConfiguration() {
        UserDefaults.standard.set(serverURL, forKey: Self.serverURLKey)
        UserDefaults.standard.set(username, forKey: Self.usernameKey)
        UserDefaults.standard.set(password, forKey: Self.passwordKey)
    }
    
    /// 从UserDefaults加载配置
    private func loadConfiguration() {
        serverURL = UserDefaults.standard.string(forKey: Self.serverURLKey) ?? ""
        username = UserDefaults.standard.string(forKey: Self.usernameKey) ?? ""
        password = UserDefaults.standard.string(forKey: Self.passwordKey) ?? ""
    }
    
    // MARK: - 认证
    
    /// 生成认证参数
    private func generateAuthParams() -> [String: String] {
        let salt = generateSalt()
        let token = generateToken(password: password, salt: salt)
        
        return [
            "u": username,
            "t": token,
            "s": salt,
            "v": apiVersion,
            "c": clientName,
            "f": "json"
        ]
    }
    
    /// 生成随机盐值
    private func generateSalt() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<8).map { _ in letters.randomElement()! })
    }
    
    /// 生成认证令牌
    private func generateToken(password: String, salt: String) -> String {
        let input = password + salt
        let inputData = Data(input.utf8)
        let hashed = Insecure.MD5.hash(data: inputData)
        return hashed.map { String(format: "%02hhx", $0) }.joined()
    }
    
    // MARK: - 网络请求
    
    /// 执行API请求
    private func makeRequest(endpoint: String, additionalParams: [String: String] = [:]) async throws -> Data {
        guard !serverURL.isEmpty, !username.isEmpty, !password.isEmpty else {
            throw SubsonicError.configurationMissing
        }
        
        var components = URLComponents(string: "\(serverURL)/rest/\(endpoint)")
        var params = generateAuthParams()
        
        // 添加额外参数
        additionalParams.forEach { params[$0] = $1 }
        
        components?.queryItems = params.map { URLQueryItem(name: $0, value: $1) }
        
        guard let url = components?.url else {
            throw SubsonicError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubsonicError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SubsonicError.httpError(httpResponse.statusCode)
        }
        
        return data
    }
    
    // MARK: - API 方法
    
    /// 测试连接
    func ping() async throws -> Bool {
        do {
            let data = try await makeRequest(endpoint: "ping")
            let response = try JSONDecoder().decode(SubsonicResponse<EmptyContent>.self, from: data)
            
            if response.subsonicResponse.status == "ok" {
                await MainActor.run {
                    isConnected = true
                }
                return true
            } else {
                throw SubsonicError.serverError(response.subsonicResponse.error?.message ?? "Unknown error")
            }
        } catch {
            await MainActor.run {
                isConnected = false
            }
            throw error
        }
    }
    
    /// 获取艺术家列表
    func getArtists(musicFolderId: String? = nil) async throws -> [SubsonicArtist] {
        var params: [String: String] = [:]
        if let folderId = musicFolderId {
            params["musicFolderId"] = folderId
        }
        
        let data = try await makeRequest(endpoint: "getArtists", additionalParams: params)
        let response = try JSONDecoder().decode(SubsonicResponse<ArtistsContent>.self, from: data)
        
        guard response.subsonicResponse.status == "ok" else {
            throw SubsonicError.serverError(response.subsonicResponse.error?.message ?? "Unknown error")
        }
        
        return response.subsonicResponse.artists?.index.flatMap { $0.artist } ?? []
    }
    
    /// 获取艺术家的专辑
    func getArtist(id: String) async throws -> SubsonicArtist {
        let data = try await makeRequest(endpoint: "getArtist", additionalParams: ["id": id])
        let response = try JSONDecoder().decode(SubsonicResponse<ArtistContent>.self, from: data)
        
        guard response.subsonicResponse.status == "ok" else {
            throw SubsonicError.serverError(response.subsonicResponse.error?.message ?? "Unknown error")
        }
        
        guard let artist = response.subsonicResponse.artist else {
            throw SubsonicError.dataNotFound
        }
        
        return artist
    }
    
    /// 获取专辑详情
    func getAlbum(id: String) async throws -> SubsonicAlbum {
        let data = try await makeRequest(endpoint: "getAlbum", additionalParams: ["id": id])
        let response = try JSONDecoder().decode(SubsonicResponse<AlbumContent>.self, from: data)
        
        guard response.subsonicResponse.status == "ok" else {
            throw SubsonicError.serverError(response.subsonicResponse.error?.message ?? "Unknown error")
        }
        
        guard let album = response.subsonicResponse.album else {
            throw SubsonicError.dataNotFound
        }
        
        return album
    }
    
    /// 获取专辑列表 (getAlbumList2)
    func getAlbumList2(type: String, size: Int, offset: Int = 0) async throws -> [SubsonicAlbum] {
        let params = [
            "type": type,
            "size": String(size),
            "offset": String(offset)
        ]
        
        let data = try await makeRequest(endpoint: "getAlbumList2", additionalParams: params)
        let response = try JSONDecoder().decode(SubsonicResponse<AlbumList2Content>.self, from: data)
        
        guard response.subsonicResponse.status == "ok" else {
            throw SubsonicError.serverError(response.subsonicResponse.error?.message ?? "Unknown error")
        }
        
        return response.subsonicResponse.albumList2?.album ?? []
    }
    
    /// 获取播放列表
    func getPlaylists() async throws -> [SubsonicPlaylist] {
        let data = try await makeRequest(endpoint: "getPlaylists")
        let response = try JSONDecoder().decode(SubsonicResponse<PlaylistsContent>.self, from: data)
        
        guard response.subsonicResponse.status == "ok" else {
            throw SubsonicError.serverError(response.subsonicResponse.error?.message ?? "Unknown error")
        }
        
        return response.subsonicResponse.playlists?.playlist ?? []
    }
    
    /// 获取播放列表详情
    func getPlaylist(id: String) async throws -> SubsonicPlaylist {
        let data = try await makeRequest(endpoint: "getPlaylist", additionalParams: ["id": id])
        let response = try JSONDecoder().decode(SubsonicResponse<PlaylistContent>.self, from: data)
        
        guard response.subsonicResponse.status == "ok" else {
            throw SubsonicError.serverError(response.subsonicResponse.error?.message ?? "Unknown error")
        }
        
        guard let playlist = response.subsonicResponse.playlist else {
            throw SubsonicError.dataNotFound
        }
        
        return playlist
    }
    
    /// 搜索
    func search3(query: String, artistCount: Int = 10, albumCount: Int = 10, songCount: Int = 10) async throws -> SubsonicSearchResult {
        let params = [
            "query": query,
            "artistCount": String(artistCount),
            "albumCount": String(albumCount),
            "songCount": String(songCount)
        ]
        
        let data = try await makeRequest(endpoint: "search3", additionalParams: params)
        let response = try JSONDecoder().decode(SubsonicResponse<SearchResultContent>.self, from: data)
        
        guard response.subsonicResponse.status == "ok" else {
            throw SubsonicError.serverError(response.subsonicResponse.error?.message ?? "Unknown error")
        }
        
        return response.subsonicResponse.searchResult3 ?? SubsonicSearchResult(artist: [], album: [], song: [])
    }
    
    /// 获取流媒体URL
    func getStreamURL(id: String, maxBitRate: Int? = nil, format: String? = nil) -> URL? {
        guard !serverURL.isEmpty else { return nil }
        
        var params = generateAuthParams()
        params["id"] = id
        
        if let bitRate = maxBitRate {
            params["maxBitRate"] = String(bitRate)
        }
        
        if let fmt = format {
            params["format"] = fmt
        }
        
        var components = URLComponents(string: "\(serverURL)/rest/stream")
        components?.queryItems = params.map { URLQueryItem(name: $0, value: $1) }
        
        return components?.url
    }
    
    /// 获取封面艺术URL
    func getCoverArtURL(id: String, size: Int? = nil) -> URL? {
        guard !serverURL.isEmpty else { return nil }
        
        var params = generateAuthParams()
        params["id"] = id
        
        if let coverSize = size {
            params["size"] = String(coverSize)
        }
        
        var components = URLComponents(string: "\(serverURL)/rest/getCoverArt")
        components?.queryItems = params.map { URLQueryItem(name: $0, value: $1) }
        
        return components?.url
    }
    
    /// 记录播放（scrobble）
    func scrobble(id: String, time: Date = Date(), submission: Bool = true) async throws {
        let params = [
            "id": id,
            "time": String(Int(time.timeIntervalSince1970 * 1000)),
            "submission": String(submission)
        ]
        
        let data = try await makeRequest(endpoint: "scrobble", additionalParams: params)
        let response = try JSONDecoder().decode(SubsonicResponse<EmptyContent>.self, from: data)
        
        guard response.subsonicResponse.status == "ok" else {
            throw SubsonicError.serverError(response.subsonicResponse.error?.message ?? "Unknown error")
        }
    }
}

// MARK: - 错误类型

enum SubsonicError: LocalizedError {
    case configurationMissing
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case dataNotFound
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "Subsonic服务器配置不完整"
        case .invalidURL:
            return "无效的服务器URL"
        case .invalidResponse:
            return "无效的服务器响应"
        case .httpError(let code):
            return "HTTP错误：\(code)"
        case .serverError(let message):
            return "服务器错误：\(message)"
        case .dataNotFound:
            return "未找到请求的数据"
        case .authenticationFailed:
            return "认证失败，请检查用户名和密码"
        }
    }
}

// MARK: - 空内容类型（用于ping等不返回数据的接口）

struct EmptyContent: Codable {}
