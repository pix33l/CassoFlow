import Foundation
import Network

// MARK: - Audio Station 数据模型

/// Audio Station 响应基类
struct AudioStationResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: ErrorInfo?
    
    struct ErrorInfo: Codable {
        let code: Int
        let message: String?
    }
}

/// Audio Station 登录响应
struct AudioStationLoginData: Codable {
    let sid: String
    let is_portal_port: Bool?
}

/// Audio Station 信息响应
struct AudioStationInfo: Codable {
    let version: String
    let path: String
}

/// Audio Station 播放列表信息
struct AudioStationPlaylistInfo: Codable {
    let playlists: [AudioStationPlaylist]
}

/// Audio Station 播放列表
struct AudioStationPlaylist: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let additional: AdditionalInfo?
    
    struct AdditionalInfo: Codable {
        let song_tag: SongTag?
        let song_audio: SongAudio?
        
        struct SongTag: Codable {
            let title: String?
            let artist: String?
            let album: String?
            let year: Int?
            let genre: String?
            let track: Int?
            let duration: Int?
        }
        
        struct SongAudio: Codable {
            let bitrate: Int?
            let frequency: Int?
            let filesize: Int?
        }
    }
    
    /// 计算持续时间
    var durationTimeInterval: TimeInterval {
        return TimeInterval(additional?.song_tag?.duration ?? 0)
    }
}

/// Audio Station 艺术家
struct AudioStationArtist: Codable, Identifiable {
    let id: String
    let name: String
    let album_count: Int?
    
    var albumCount: Int { album_count ?? 0 }
}

/// Audio Station 专辑
struct AudioStationAlbum: Codable, Identifiable {
    let id: String
    let name: String
    let title: String?
    let album_artist: String?
    let artist: String?
    let year: Int?
    let additional: AudioStationPlaylist.AdditionalInfo?
    
    var displayName: String { title ?? name }
    var artistName: String { album_artist ?? artist ?? "" }
    
    /// 计算持续时间
    var durationTimeInterval: TimeInterval {
        return TimeInterval(additional?.song_tag?.duration ?? 0)
    }
}

/// Audio Station 歌曲
struct AudioStationSong: Codable, Identifiable {
    let id: String
    let title: String
    let artist: String?
    let album: String?
    let year: Int?
    let track: Int?
    let duration: Int?
    let genre: String?
    let path: String
    let additional: AudioStationPlaylist.AdditionalInfo?
    
    /// 计算持续时间
    var durationTimeInterval: TimeInterval {
        return TimeInterval(duration ?? 0)
    }
    
    var artistName: String { artist ?? "" }
}

/// Audio Station 搜索结果
struct AudioStationSearchResult: Codable {
    let songs: [AudioStationSong]
    let albums: [AudioStationAlbum]
    let artists: [AudioStationArtist]
}

/// Audio Station 远程播放器信息
struct AudioStationRemotePlayer: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let status: String
}

// MARK: - Audio Station API 客户端

class AudioStationAPIClient: ObservableObject {
    static let shared = AudioStationAPIClient()
    
    @Published var isConnected: Bool = false
    
    private var baseURL: String = ""
    private var username: String = ""
    private var password: String = ""
    private var sessionID: String = ""
    
    private let session = URLSession.shared
    
    // API 路径
    private let apiInfo = "/webapi/AudioStation/info.cgi"
    private let apiAuth = "/webapi/auth.cgi"
    private let apiSong = "/webapi/AudioStation/song.cgi"
    private let apiAlbum = "/webapi/AudioStation/album.cgi"
    private let apiArtist = "/webapi/AudioStation/artist.cgi"
    private let apiPlaylist = "/webapi/AudioStation/playlist.cgi"
    private let apiRemotePlayer = "/webapi/AudioStation/remote_player.cgi"
    private let apiCoverArt = "/webapi/AudioStation/cover.cgi"
    private let apiStream = "/webapi/AudioStation/stream.cgi"
    
    init() {
        loadConfiguration()
    }
    
    // MARK: - 配置管理
    
    func configure(baseURL: String, username: String, password: String) {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 确保 baseURL 以 http:// 或 https:// 开头
        if !self.baseURL.hasPrefix("http://") && !self.baseURL.hasPrefix("https://") {
            self.baseURL = "https://" + self.baseURL
        }
        
        // 移除末尾的斜杠
        if self.baseURL.hasSuffix("/") {
            self.baseURL = String(self.baseURL.dropLast())
        }
        
        saveConfiguration()
    }
    
    private func saveConfiguration() {
        UserDefaults.standard.set(baseURL, forKey: "AudioStation_BaseURL")
        UserDefaults.standard.set(username, forKey: "AudioStation_Username")
        UserDefaults.standard.set(password, forKey: "AudioStation_Password")
    }
    
    private func loadConfiguration() {
        baseURL = UserDefaults.standard.string(forKey: "AudioStation_BaseURL") ?? ""
        username = UserDefaults.standard.string(forKey: "AudioStation_Username") ?? ""
        password = UserDefaults.standard.string(forKey: "AudioStation_Password") ?? ""
    }
    
    func getConfiguration() -> (baseURL: String, username: String, password: String) {
        return (baseURL, username, password)
    }
    
    // MARK: - 网络请求基础方法
    
    private func makeRequest(to path: String, parameters: [String: String], method: HTTPMethod = .GET) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw AudioStationError.invalidURL
        }
        
        var request: URLRequest
        
        switch method {
        case .GET:
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            
            guard let requestURL = components?.url else {
                throw AudioStationError.invalidURL
            }
            
            request = URLRequest(url: requestURL)
            request.httpMethod = "GET"
            
        case .POST:
            request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let bodyString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
        }
        
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudioStationError.networkError
        }
        
        if httpResponse.statusCode != 200 {
            throw AudioStationError.httpError(httpResponse.statusCode)
        }
        
        return data
    }
    
    private enum HTTPMethod {
        case GET
        case POST
    }

    // MARK: - 认证方法
    
    func login() async throws -> Bool {
        guard !baseURL.isEmpty else {
            throw AudioStationError.invalidURL
        }

        let params = [
            "api": "SYNO.API.Auth",
            "method": "Login", // 注意首字母大写
            "version": "6",
            "account": username,
            "passwd": password
        ]

        var components = URLComponents(string: baseURL + "/webapi/auth.cgi")!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else {
            throw AudioStationError.invalidURL
        }

        print("🔑 Audio Station 登录请求: \(url)")
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AudioStationError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 登录响应: \(responseString)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let dataDict = json["data"] as? [String: Any], 
              let sid = dataDict["sid"] as? String else {
            
            // 如果登录失败，尝试解析错误信息
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let code = error["code"] as? Int,
               let message = error["message"] as? String {
                throw AudioStationError.authenticationFailed("\(message) (错误代码: \(code))")
            }
            throw AudioStationError.invalidResponse
        }

        sessionID = sid
        await MainActor.run {
            isConnected = true
        }
        print("✅ 登录成功, sessionID: \(sid)")
        return true
    }
    
    func logout() async throws {
        guard !sessionID.isEmpty else {
            await MainActor.run {
                isConnected = false
            }
            return
        }
        
        let params = [
            "api": "SYNO.API.Auth",
            "method": "Logout", // 注意首字母大写
            "version": "6",
            "_sid": sessionID
        ]

        var components = URLComponents(string: baseURL + "/webapi/auth.cgi")!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else {
            throw AudioStationError.invalidURL
        }

        do {
            print("🔓 Audio Station 注销请求: \(url)")
            let request = URLRequest(url: url)
            let (data, _) = try await session.data(for: request)
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 注销响应: \(responseString)")
            }
            print("✅ 注销成功")
        } catch {
            print("❌ 注销失败: \(error)")
            // 即使注销失败也要清除本地状态
        }
        
        sessionID = ""
        await MainActor.run {
            isConnected = false
        }
    }
    
    // MARK: - 信息获取
    
    func getInfo() async throws -> AudioStationInfo {
        guard !sessionID.isEmpty else {
            throw AudioStationError.authenticationFailed("未登录")
        }
        
        let parameters = [
            "api": "SYNO.AudioStation.Info",
            "version": "1",
            "method": "getinfo",
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: apiInfo, parameters: parameters)
        let response = try JSONDecoder().decode(AudioStationResponse<AudioStationInfo>.self, from: data)
        
        if response.success, let info = response.data {
            return info
        } else {
            throw AudioStationError.apiError(response.error?.message ?? "获取信息失败")
        }
    }
    
    // MARK: - 播放列表管理
    
    func getPlaylists() async throws -> [AudioStationPlaylist] {
        guard !sessionID.isEmpty else {
            throw AudioStationError.authenticationFailed("未登录")
        }
        
        let parameters = [
            "api": "SYNO.AudioStation.Playlist",
            "version": "1",
            "method": "list", // 修改为 method 而不是 action
            "library": "all",
            "limit": "100000",
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: apiPlaylist, parameters: parameters, method: .POST) // 使用POST请求
        let response = try JSONDecoder().decode(AudioStationResponse<AudioStationPlaylistInfo>.self, from: data)
        
        if response.success, let playlistInfo = response.data {
            return playlistInfo.playlists
        } else {
            throw AudioStationError.apiError(response.error?.message ?? "获取播放列表失败")
        }
    }
    
    // MARK: - 艺术家管理
    
    func getArtists() async throws -> [AudioStationArtist] {
        guard !sessionID.isEmpty else {
            throw AudioStationError.authenticationFailed("未登录")
        }
        
        let parameters = [
            "api": "SYNO.AudioStation.Artist",
            "version": "2",
            "action": "list", // 艺术家API使用action参数
            "limit": "10000",
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: apiArtist, parameters: parameters, method: .POST) // 使用POST请求
        
        // 解析响应中的artists数组
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool,
           success,
           let dataObject = json["data"] as? [String: Any],
           let artistsData = dataObject["artists"] {
            let artistsJSON = try JSONSerialization.data(withJSONObject: artistsData)
            let artists = try JSONDecoder().decode([AudioStationArtist].self, from: artistsJSON)
            return artists
        } else {
            throw AudioStationError.apiError("解析艺术家列表失败")
        }
    }
    
    // MARK: - 专辑管理
    
    func getAlbums() async throws -> [AudioStationAlbum] {
        guard !sessionID.isEmpty else {
            throw AudioStationError.authenticationFailed("未登录")
        }
        
        let parameters = [
            "api": "SYNO.AudioStation.Album",
            "version": "2",
            "action": "list", // 专辑API使用action参数
            "limit": "10000",
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: apiAlbum, parameters: parameters, method: .POST) // 使用POST请求
        
        // 解析响应中的albums数组
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool,
           success,
           let dataObject = json["data"] as? [String: Any],
           let albumsData = dataObject["albums"] {
            let albumsJSON = try JSONSerialization.data(withJSONObject: albumsData)
            let albums = try JSONDecoder().decode([AudioStationAlbum].self, from: albumsJSON)
            return albums
        } else {
            throw AudioStationError.apiError("解析专辑列表失败")
        }
    }
    
    func getAlbum(id: String) async throws -> AudioStationAlbum {
        guard !sessionID.isEmpty else {
            throw AudioStationError.authenticationFailed("未登录")
        }
        
        let parameters = [
            "api": "SYNO.AudioStation.Album",
            "version": "2",
            "action": "getinfo", // 使用action而不是method
            "id": id,
            "additional": "song_tag,song_audio",
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: apiAlbum, parameters: parameters, method: .POST) // 使用POST请求
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool,
           success,
           let dataObject = json["data"] as? [String: Any],
           let albumData = dataObject["album"] {
            let albumJSON = try JSONSerialization.data(withJSONObject: albumData)
            let album = try JSONDecoder().decode(AudioStationAlbum.self, from: albumJSON)
            return album
        } else {
            throw AudioStationError.apiError("获取专辑详情失败")
        }
    }
    
    func getAlbumSongs(albumId: String) async throws -> [AudioStationSong] {
        guard !sessionID.isEmpty else {
            throw AudioStationError.authenticationFailed("未登录")
        }
        
        let parameters = [
            "api": "SYNO.AudioStation.Song",
            "version": "2",
            "method": "list",
            "album": albumId,
            "limit": "1000",
            "additional": "song_tag,song_audio",
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: apiSong, parameters: parameters, method: .POST) // 使用POST请求
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool,
           success,
           let dataObject = json["data"] as? [String: Any],
           let songsData = dataObject["songs"] {
            let songsJSON = try JSONSerialization.data(withJSONObject: songsData)
            let songs = try JSONDecoder().decode([AudioStationSong].self, from: songsJSON)
            return songs.sorted { ($0.track ?? 0) < ($1.track ?? 0) } // 按曲目编号排序
        } else {
            throw AudioStationError.apiError("获取专辑歌曲失败")
        }
    }
    
    func getArtistSongs(artistId: String) async throws -> [AudioStationSong] {
        guard !sessionID.isEmpty else {
            throw AudioStationError.authenticationFailed("未登录")
        }
        
        let parameters = [
            "api": "SYNO.AudioStation.Song",
            "version": "2",
            "method": "list",
            "artist": artistId,
            "limit": "1000",
            "additional": "song_tag,song_audio",
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: apiSong, parameters: parameters, method: .POST) // 使用POST请求
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool,
           success,
           let dataObject = json["data"] as? [String: Any],
           let songsData = dataObject["songs"] {
            let songsJSON = try JSONSerialization.data(withJSONObject: songsData)
            let songs = try JSONDecoder().decode([AudioStationSong].self, from: songsJSON)
            return songs
        } else {
            throw AudioStationError.apiError("获取艺术家歌曲失败")
        }
    }
    
    // MARK: - 歌曲管理
    
    func getSongs(limit: Int = 1000) async throws -> [AudioStationSong] {
        guard !sessionID.isEmpty else {
            throw AudioStationError.authenticationFailed("未登录")
        }
        
        let parameters = [
            "api": "SYNO.AudioStation.Song",
            "version": "2",
            "method": "list",
            "limit": String(limit),
            "additional": "song_tag,song_audio",
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: apiSong, parameters: parameters, method: .POST) // 使用POST请求
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool,
           success,
           let dataObject = json["data"] as? [String: Any],
           let songsData = dataObject["songs"] {
            let songsJSON = try JSONSerialization.data(withJSONObject: songsData)
            let songs = try JSONDecoder().decode([AudioStationSong].self, from: songsJSON)
            return songs
        } else {
            throw AudioStationError.apiError("获取歌曲列表失败")
        }
    }
    
    // MARK: - 搜索功能
    
    func search(query: String) async throws -> AudioStationSearchResult {
        guard !sessionID.isEmpty else {
            throw AudioStationError.authenticationFailed("未登录")
        }
        
        let parameters = [
            "api": "SYNO.AudioStation.Search",
            "version": "1",
            "keyword": query, // 直接使用keyword参数，无需method
            "additional": "song_tag,song_audio",
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: "/webapi/AudioStation/search.cgi", parameters: parameters, method: .POST) // 使用POST请求
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool,
           success,
           let dataObject = json["data"] as? [String: Any] {
            
            var songs: [AudioStationSong] = []
            var albums: [AudioStationAlbum] = []
            var artists: [AudioStationArtist] = []
            
            // 解析歌曲
            if let songsData = dataObject["songs"] {
                let songsJSON = try JSONSerialization.data(withJSONObject: songsData)
                songs = try JSONDecoder().decode([AudioStationSong].self, from: songsJSON)
            }
            
            // 解析专辑
            if let albumsData = dataObject["albums"] {
                let albumsJSON = try JSONSerialization.data(withJSONObject: albumsData)
                albums = try JSONDecoder().decode([AudioStationAlbum].self, from: albumsJSON)
            }
            
            // 解析艺术家
            if let artistsData = dataObject["artists"] {
                let artistsJSON = try JSONSerialization.data(withJSONObject: artistsData)
                artists = try JSONDecoder().decode([AudioStationArtist].self, from: artistsJSON)
            }
            
            return AudioStationSearchResult(songs: songs, albums: albums, artists: artists)
        } else {
            throw AudioStationError.apiError("搜索失败")
        }
    }
    
    // MARK: - 媒体流和封面
    
    func getStreamURL(id: String) -> URL? {
        guard !sessionID.isEmpty else { return nil }
        let urlString = baseURL + apiStream + "?api=SYNO.AudioStation.Stream&version=2&method=stream&id=\(id)&_sid=\(sessionID)"
        return URL(string: urlString)
    }
    
    func getCoverArtURL(id: String, size: Int = 300) -> URL? {
        guard !sessionID.isEmpty else { return nil }
        let urlString = baseURL + apiCoverArt + "?api=SYNO.AudioStation.Cover&version=1&action=getcover&id=\(id)&size=\(size)&_sid=\(sessionID)"
        return URL(string: urlString)
    }
    
    // MARK: - 连接测试
    
    func ping() async throws -> Bool {
        do {
            // 直接登录测试，不需要额外的API调用
            let loginSuccess = try await login()
            return loginSuccess
        } catch {
            await MainActor.run {
                isConnected = false
            }
            throw error
        }
    }
    
    // MARK: - 会话管理
    
    func getCurrentSessionID() -> String {
        return sessionID
    }
    
    func isSessionValid() -> Bool {
        return !sessionID.isEmpty && isConnected
    }
}

// MARK: - 错误处理

enum AudioStationError: LocalizedError {
    case invalidURL
    case networkError
    case httpError(Int)
    case authenticationFailed(String)
    case apiError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的服务器地址"
        case .networkError:
            return "网络连接错误"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        case .authenticationFailed(let message):
            return "认证失败: \(message)"
        case .apiError(let message):
            return "API错误: \(message)"
        case .invalidResponse:
            return "无效的服务器响应"
        }
    }
}
