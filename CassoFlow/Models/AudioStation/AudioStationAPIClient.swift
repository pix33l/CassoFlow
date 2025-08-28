import Foundation
import Network
import UIKit

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
    let name: String
    let type: String?
    let additional: AdditionalInfo?
    
    // 🔧 生成ID：由于可能没有id字段，我们基于name生成ID
    var id: String {
        return name.isEmpty ? "unknown_playlist" : name
    }
    
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

/// Audio Station 专辑
struct AudioStationAlbum: Codable, Identifiable {
    let name: String
    let album_artist: String?
    let artist: String?
    let display_artist: String?
    let year: Int?
    let additional: AudioStationPlaylist.AdditionalInfo?
    
    // 🔧 生成ID：由于API没有返回id字段，我们基于name和artist生成一个唯一ID
    var id: String {
        let artistName = album_artist ?? display_artist ?? artist ?? "未知艺术家"
        return "\(artistName)_\(name)".replacingOccurrences(of: " ", with: "_")
    }
    
    var displayName: String { name }
    var artistName: String { 
        album_artist ?? display_artist ?? artist ?? "未知艺术家" 
    }
    
    /// 计算持续时间
    var durationTimeInterval: TimeInterval {
        return TimeInterval(additional?.song_tag?.duration ?? 0)
    }
}

/// Audio Station 艺术家
struct AudioStationArtist: Codable, Identifiable {
    let name: String
    let albumCount: Int // 🔧 修改：改为可设置的属性
    
    // 🔧 生成ID：由于API没有返回id字段，我们使用name作为ID
    var id: String {
        return name.isEmpty ? "unknown_artist" : name
    }
    
    // 🔧 新增：初始化方法，支持设置专辑数量
    init(name: String, albumCount: Int = 0) {
        self.name = name
        self.albumCount = albumCount
    }
    
    // 🔧 保持Codable兼容性的初始化方法
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        albumCount = 0 // 默认值，将在后续计算中更新
    }
    
    enum CodingKeys: String, CodingKey {
        case name
    }
    
}

/// Audio Station 歌曲
struct AudioStationSong: Codable, Identifiable {
    let id: String // 🔧 Audio Station 返回真实的ID字段
    let title: String
    let path: String?
    let type: String?
    let additional: SongAdditional?
    
    // 🔧 新的additional结构，匹配实际API响应
    struct SongAdditional: Codable {
        let song_tag: SongTag?
        let song_audio: SongAudio?
        
        struct SongTag: Codable {
            let album: String?
            let album_artist: String?
            let artist: String?
            let comment: String?
            let composer: String?
            let disc: Int?
            let genre: String?
            let track: Int?
            let year: Int?
        }
        
        struct SongAudio: Codable {
            let bitrate: Int?
            let channel: Int?
            let codec: String?
            let container: String?
            let duration: Int?
            let filesize: Int?
            let frequency: Int?
        }
    }
    
    // 🔧 计算属性从additional中获取信息
    var artist: String? {
        return additional?.song_tag?.artist ?? additional?.song_tag?.album_artist
    }
    
    var album: String? {
        return additional?.song_tag?.album
    }
    
    var year: Int? {
        return additional?.song_tag?.year
    }
    
    var track: Int? {
        return additional?.song_tag?.track
    }
    
    var duration: Int? {
        return additional?.song_audio?.duration
    }
    
    var genre: String? {
        return additional?.song_tag?.genre
    }
    
    /// 计算持续时间
    var durationTimeInterval: TimeInterval {
        return TimeInterval(duration ?? 0)
    }
    
    var artistName: String { 
        artist ?? "未知艺术家" 
    }
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
            "method": "list", // 🔧 修改：使用method而不是action
            "limit": "10000",
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: apiArtist, parameters: parameters, method: .POST)
        
        // 🔧 增强错误调试：打印完整的响应数据
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 艺术家列表API响应: \(responseString)")
        }
        
        // 解析响应中的artists数组
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("📊 解析的JSON对象: \(json)")
            
            guard let success = json["success"] as? Bool, success else {
                // 🔧 处理API错误响应
                if let errorInfo = json["error"] as? [String: Any],
                   let code = errorInfo["code"] as? Int,
                   let message = errorInfo["message"] as? String {
                    throw AudioStationError.apiError("获取艺术家列表失败 - 代码: \(code), 消息: \(message)")
                } else {
                    throw AudioStationError.apiError("获取艺术家列表失败 - API返回失败状态")
                }
            }
            
            guard let dataObject = json["data"] as? [String: Any] else {
                throw AudioStationError.apiError("解析艺术家列表失败 - 缺少data字段")
            }
            
            print("📊 数据对象: \(dataObject)")
            
            // 🔧 检查artists字段是否存在
            guard let artistsData = dataObject["artists"] else {
                // 如果没有artists字段，可能是空列表，返回空数组
                print("⚠️ 响应中没有找到artists字段，返回空列表")
                return []
            }
            
            do {
                let artistsJSON = try JSONSerialization.data(withJSONObject: artistsData)
                if let artistsString = String(data: artistsJSON, encoding: .utf8) {
                    print("📊 艺术家数据JSON: \(artistsString)")
                }
                
                var artists = try JSONDecoder().decode([AudioStationArtist].self, from: artistsJSON)
                print("✅ 成功解析 \(artists.count) 个艺术家")
                
                // 🔧 获取专辑列表以计算每个艺术家的专辑数量
                do {
                    let albums = try await getAlbums()
                    print("📊 获取到 \(albums.count) 个专辑，开始计算艺术家专辑数量")
                    
                    // 为每个艺术家计算专辑数量
                    for i in 0..<artists.count {
                        let artistName = artists[i].name
                        let albumCount = albums.filter { album in
                            album.artistName.lowercased() == artistName.lowercased() ||
                            album.artistName.localizedCaseInsensitiveContains(artistName) ||
                            artistName.localizedCaseInsensitiveContains(album.artistName)
                        }.count
                        
                        // 创建一个新的艺术家实例，包含正确的专辑数量
                        artists[i] = AudioStationArtist(name: artistName, albumCount: albumCount)
                        print("🎵 艺术家 '\(artistName)' 有 \(albumCount) 张专辑")
                    }
                } catch {
                    print("⚠️ 获取专辑列表失败，使用默认专辑数量: \(error)")
                    // 如果获取专辑失败，保持原有的0值
                }
                
                return artists
            } catch {
                print("❌ 艺术家数据解码失败: \(error)")
                throw AudioStationError.apiError("解析艺术家数据失败: \(error.localizedDescription)")
            }
        } else {
            throw AudioStationError.apiError("解析艺术家列表失败 - 无效的JSON响应")
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
            "method": "list", // 🔧 修改：使用method而不是action
            "limit": "10000",
            "additional": "song_tag,song_audio", // 🔧 添加：获取额外信息
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: apiAlbum, parameters: parameters, method: .POST)
        
        // 🔧 增强错误调试：打印完整的响应数据
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 专辑列表API响应: \(responseString)")
        }
        
        // 解析响应中的albums数组
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("📊 解析的JSON对象: \(json)")
            
            guard let success = json["success"] as? Bool, success else {
                // 🔧 处理API错误响应
                if let errorInfo = json["error"] as? [String: Any],
                   let code = errorInfo["code"] as? Int,
                   let message = errorInfo["message"] as? String {
                    throw AudioStationError.apiError("获取专辑列表失败 - 代码: \(code), 消息: \(message)")
                } else {
                    throw AudioStationError.apiError("获取专辑列表失败 - API返回失败状态")
                }
            }
            
            guard let dataObject = json["data"] as? [String: Any] else {
                throw AudioStationError.apiError("解析专辑列表失败 - 缺少data字段")
            }
            
            print("📊 数据对象: \(dataObject)")
            
            // 🔧 检查albums字段是否存在
            guard let albumsData = dataObject["albums"] else {
                // 如果没有albums字段，可能是空列表，返回空数组
                print("⚠️ 响应中没有找到albums字段，返回空列表")
                return []
            }
            
            do {
                let albumsJSON = try JSONSerialization.data(withJSONObject: albumsData)
                if let albumsString = String(data: albumsJSON, encoding: .utf8) {
                    print("📊 专辑数据JSON: \(albumsString)")
                }
                
                let albums = try JSONDecoder().decode([AudioStationAlbum].self, from: albumsJSON)
                print("✅ 成功解析 \(albums.count) 个专辑")
                return albums
            } catch {
                print("❌ 专辑数据解码失败: \(error)")
                throw AudioStationError.apiError("解析专辑数据失败: \(error.localizedDescription)")
            }
        } else {
            throw AudioStationError.apiError("解析专辑列表失败 - 无效的JSON响应")
        }
    }
    
    func getAlbum(id: String) async throws -> AudioStationAlbum {
        guard !sessionID.isEmpty else {
            throw AudioStationError.authenticationFailed("未登录")
        }
        
        // 🔧 修复：对于我们生成的ID，我们需要根据专辑名称来查询
        // 因为Audio Station可能不支持直接通过我们生成的ID获取专辑
        // 我们需要从专辑列表中找到匹配的专辑
        let albums = try await getAlbums()
        guard let album = albums.first(where: { $0.id == id }) else {
            throw AudioStationError.apiError("未找到指定专辑")
        }
        
        return album
    }
    
    func getAlbumSongs(albumId: String) async throws -> [AudioStationSong] {
        guard !sessionID.isEmpty else {
            throw AudioStationError.authenticationFailed("未登录")
        }
        
        // 🔧 修复：我们需要使用专辑名称而不是生成的ID来获取歌曲
        let albums = try await getAlbums()
        guard let album = albums.first(where: { $0.id == albumId }) else {
            throw AudioStationError.apiError("未找到指定专辑")
        }
        
        print("🎵 正在获取专辑歌曲: \(album.name) (艺术家: \(album.artistName))")
        
        // 🔧 直接从所有歌曲中过滤，因为这个方法最可靠
        print("🔄 从全部歌曲中过滤专辑歌曲...")
        
        do {
            let allSongs = try await getSongs(limit: 50000)
            print("📊 获取到所有歌曲数量: \(allSongs.count)")
            
            // 打印前几首歌曲的信息用于调试
            for (index, song) in allSongs.prefix(3).enumerated() {
                print("🎵 歌曲\(index + 1): \(song.title) - \(song.artistName) - 专辑: \(song.album ?? "无")")
            }
            
            // 过滤属于该专辑的歌曲
            let filteredSongs = allSongs.filter { song in
                // 方法1: 精确匹配专辑名称
                if let songAlbum = song.album, songAlbum.lowercased() == album.name.lowercased() {
                    return true
                }
                
                // 方法2: 模糊匹配专辑名称和艺术家
                if let songAlbum = song.album, 
                   songAlbum.contains(album.name) || album.name.contains(songAlbum),
                   let songArtist = song.artist,
                   (songArtist.lowercased() == album.artistName.lowercased() || 
                    songArtist.contains(album.artistName) || 
                    album.artistName.contains(songArtist)) {
                    return true
                }
                
                return false
            }
            
            print("📊 过滤后的歌曲数量: \(filteredSongs.count)")
            
            // 打印过滤结果用于调试
            for (index, song) in filteredSongs.prefix(5).enumerated() {
                print("✅ 匹配歌曲\(index + 1): \(song.title) - \(song.artistName) - 专辑: \(song.album ?? "无")")
            }
            
            if !filteredSongs.isEmpty {
                print("✅ 通过过滤获取到 \(filteredSongs.count) 首歌曲")
                return filteredSongs.sorted { ($0.track ?? 0) < ($1.track ?? 0) }
            } else {
                print("⚠️ 过滤后没有找到匹配的歌曲")
                print("🔍 目标专辑: '\(album.name)', 艺术家: '\(album.artistName)'")
                
                // 显示一些可能相关的歌曲用于调试
                let potentialMatches = allSongs.filter { song in
                    if let songAlbum = song.album {
                        return songAlbum.localizedCaseInsensitiveContains(album.name) ||
                               album.name.localizedCaseInsensitiveContains(songAlbum)
                    }
                    return false
                }
                
                if !potentialMatches.isEmpty {
                    print("🔍 可能相关的歌曲:")
                    for (index, song) in potentialMatches.prefix(3).enumerated() {
                        print("   \(index + 1). \(song.title) - \(song.artistName) - 专辑: \(song.album ?? "无")")
                    }
                }
                
                return []
            }
        } catch {
            print("❌ 从全部歌曲中过滤失败: \(error)")
            throw error
        }
    }
    
    func getArtistSongs(artistId: String) async throws -> [AudioStationSong] {
        guard !sessionID.isEmpty else {
            throw AudioStationError.authenticationFailed("未登录")
        }
        
        // 🔧 修复：我们需要使用艺术家名称而不是生成的ID来获取歌曲
        let artists = try await getArtists()
        guard let artist = artists.first(where: { $0.id == artistId }) else {
            throw AudioStationError.apiError("未找到指定艺术家")
        }
        
        print("🎵 正在获取艺术家歌曲: \(artist.name)")
        
        // 🔧 尝试多种API参数组合
        let parameterSets = [
            // 方法1：使用艺术家名称过滤
            [
                "api": "SYNO.AudioStation.Song",
                "version": "2",
                "method": "list",
                "artist": artist.name,
                "additional": "song_tag,song_audio",
                "limit": "10000",
                "_sid": sessionID
            ],
            // 方法2：使用搜索API
            [
                "api": "SYNO.AudioStation.Song",
                "version": "2",
                "method": "search",
                "title": "",
                "artist": artist.name,
                "additional": "song_tag,song_audio",
                "limit": "10000",
                "_sid": sessionID
            ],
            // 方法3：使用浏览API
            [
                "api": "SYNO.AudioStation.Song",
                "version": "2",
                "method": "list",
                "library": "all", 
                "artist": artist.name,
                "additional": "song_tag,song_audio",
                "sort_by": "album",
                "sort_direction": "ASC",
                "_sid": sessionID
            ]
        ]
        
        // 依次尝试每种参数组合
        for (index, parameters) in parameterSets.enumerated() {
            do {
                print("🔍 尝试方法 \(index + 1): \(parameters)")
                
                let data = try await makeRequest(to: apiSong, parameters: parameters, method: .POST)
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 艺术家歌曲API响应 (方法\(index + 1)): \(responseString)")
                }
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool,
                   success {
                    
                    // 尝试解析歌曲数据
                    var songsData: Any?
                    
                    if let dataObject = json["data"] as? [String: Any] {
                        // 标准响应格式
                        songsData = dataObject["songs"]
                    } else if let directSongs = json["songs"] {
                        // 直接歌曲数组
                        songsData = directSongs
                    }
                    
                    if let songs = songsData {
                        do {
                            let songsJSON = try JSONSerialization.data(withJSONObject: songs)
                            let decodedSongs = try JSONDecoder().decode([AudioStationSong].self, from: songsJSON)
                            
                            if !decodedSongs.isEmpty {
                                print("✅ 成功获取到 \(decodedSongs.count) 首歌曲 (使用方法\(index + 1))")
                                return decodedSongs
                            } else {
                                print("⚠️ 方法\(index + 1) 返回了空的歌曲列表")
                                continue
                            }
                        } catch {
                            print("❌ 方法\(index + 1) 歌曲数据解码失败: \(error)")
                            continue
                        }
                    } else {
                        print("⚠️ 方法\(index + 1) 响应中没有找到歌曲数据")
                        continue
                    }
                } else {
                    // 处理API错误
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorInfo = json["error"] as? [String: Any],
                       let code = errorInfo["code"] as? Int,
                       let message = errorInfo["message"] as? String {
                        print("❌ 方法\(index + 1) API错误: 代码\(code), 消息: \(message)")
                    } else {
                        print("❌ 方法\(index + 1) 未知错误")
                    }
                    continue // 尝试下一种方法
                }
            } catch {
                print("❌ 方法\(index + 1) 请求失败: \(error)")
                continue // 尝试下一种方法
            }
        }
        
        // 🔧 如果所有方法都失败，尝试从所有歌曲中过滤
        print("🔄 所有直接方法失败，尝试从全部歌曲中过滤艺术家歌曲...")
        
        do {
            let allSongs = try await getSongs(limit: 50000)
            let filteredSongs = allSongs.filter { song in
                song.artist?.lowercased() == artist.name.lowercased() ||
                song.artist?.contains(artist.name) == true
            }
            
            if !filteredSongs.isEmpty {
                print("✅ 通过过滤获取到 \(filteredSongs.count) 首歌曲")
                return filteredSongs
            }
        } catch {
            print("❌ 从全部歌曲中过滤失败: \(error)")
        }
        
        // 🔧 如果所有方法都失败，返回空数组
        print("⚠️ 艺术家 '\(artist.name)' 没有找到歌曲")
        return []
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
            "library": "all", // 🔧 添加：确保获取所有库中的歌曲
            "limit": String(limit),
            "additional": "song_tag,song_audio",
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: apiSong, parameters: parameters, method: .POST)
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 所有歌曲API响应: \(responseString.prefix(500))...") // 只打印前500字符避免日志过长
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool,
           success {
            
            var songsData: Any?
            
            // 尝试不同的数据结构
            if let dataObject = json["data"] as? [String: Any] {
                songsData = dataObject["songs"]
            } else if let directSongs = json["songs"] {
                songsData = directSongs
            }
            
            if let songs = songsData {
                do {
                    let songsJSON = try JSONSerialization.data(withJSONObject: songs)
                    let decodedSongs = try JSONDecoder().decode([AudioStationSong].self, from: songsJSON)
                    print("✅ 成功获取 \(decodedSongs.count) 首歌曲")
                    return decodedSongs
                } catch {
                    print("❌ 歌曲数据解码失败: \(error)")
                    throw AudioStationError.apiError("解析歌曲数据失败: \(error.localizedDescription)")
                }
            } else {
                print("⚠️ 响应中没有找到歌曲数据")
                return [] // 返回空数组而不是报错
            }
        } else {
            // 处理API错误
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorInfo = json["error"] as? [String: Any],
               let code = errorInfo["code"] as? Int,
               let message = errorInfo["message"] as? String {
                throw AudioStationError.apiError("获取歌曲列表失败 - 代码: \(code), 消息: \(message)")
            } else {
                throw AudioStationError.apiError("获取歌曲列表失败")
            }
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
            "method": "search", // 🔧 添加：搜索API需要method参数
            "keyword": query,
            "additional": "song_tag,song_audio",
            "_sid": sessionID
        ]
        
        let data = try await makeRequest(to: "/webapi/AudioStation/search.cgi", parameters: parameters, method: .POST)
        
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
        
        // 对ID进行URL编码以防止特殊字符问题
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        
        // 添加格式参数以支持FLAC等高质量格式
        let urlString = baseURL + apiStream + "?api=SYNO.AudioStation.Stream&version=2&method=stream&id=\(encodedId)&format=mp3&bitrate=320&_sid=\(sessionID)"
        
        print("🎵 生成流URL: \(urlString)")
        return URL(string: urlString)
    }
    
    /// 基于专辑名称和艺术家获取封面URL（唯一有效的方法）
    func getCoverArtURL(albumName: String, artistName: String, size: Int = 300) -> URL? {
        guard !sessionID.isEmpty else { 
            print("❌ 专辑封面URL生成失败：sessionID为空")
            return nil 
        }
        
        // 对专辑名称和艺术家名称进行URL编码
        let encodedAlbumName = albumName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? albumName
        let encodedArtistName = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? artistName
        
        // 使用已验证的工作URL格式
        let urlString = baseURL + apiCoverArt + "?api=SYNO.AudioStation.Cover&output_default=true&is_hr=true&version=3&library=shared&method=getcover&view=default&album_name=\(encodedAlbumName)&album_artist_name=\(encodedArtistName)&_sid=\(sessionID)"
        
        print("🎨 生成专辑封面URL: \(urlString)")
        
        if let url = URL(string: urlString) {
            print("✅ 专辑封面URL创建成功: \(url)")
            return url
        } else {
            print("❌ 专辑封面URL创建失败: \(urlString)")
            return nil
        }
    }
    
    /// 为AudioStation歌曲获取封面URL
    func getCoverArtURL(for song: AudioStationSong, size: Int = 300) -> URL? {
        guard let albumName = song.album, !albumName.isEmpty,
              let artistName = song.artist, !artistName.isEmpty else {
            print("❌ 歌曲缺少必要的专辑或艺术家信息: \(song.title)")
            return nil
        }
        
        print("🎨 为歌曲获取封面: \(song.title) - 专辑: \(albumName) - 艺术家: \(artistName)")
        return getCoverArtURL(albumName: albumName, artistName: artistName, size: size)
    }
    
    /// 为AudioStation专辑获取封面URL
    func getCoverArtURL(for album: AudioStationAlbum, size: Int = 300) -> URL? {
        print("🎨 为专辑获取封面: \(album.displayName) - 艺术家: \(album.artistName)")
        return getCoverArtURL(albumName: album.displayName, artistName: album.artistName, size: size)
    }
    
    // 获取转码流URL（用于FLAC等格式的兼容性）
    func getTranscodedStreamURL(id: String, format: String = "mp3", bitrate: Int = 320) -> URL? {
        guard !sessionID.isEmpty else { return nil }
        
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        let urlString = baseURL + apiStream + "?api=SYNO.AudioStation.Stream&version=2&method=transcode&id=\(encodedId)&format=\(format)&bitrate=\(bitrate)&_sid=\(sessionID)"
        
        print("🔄 生成转码流URL: \(urlString)")
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
    
    // 测试专辑封面URL是否有效
    func testCoverURL(albumName: String, artistName: String) async -> Bool {
        guard let coverURL = getCoverArtURL(albumName: albumName, artistName: artistName) else {
            print("❌ 无法生成专辑封面URL for: \(albumName) - \(artistName)")
            return false
        }
        
        do {
            print("🎨 测试专辑封面URL: \(coverURL)")
            let (data, response) = try await URLSession.shared.data(from: coverURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🎨 专辑封面URL响应状态: \(httpResponse.statusCode)")
                print("🎨 专辑封面数据大小: \(data.count) bytes")
                print("🎨 Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "未知")")
                
                if httpResponse.statusCode == 200 && data.count > 100 {
                    if UIImage(data: data) != nil {
                        print("✅ 专辑封面URL有效且包含有效图片数据")
                        return true
                    } else {
                        print("❌ 专辑封面URL返回的数据不是有效图片")
                        return false
                    }
                } else {
                    print("❌ 专辑封面URL无效：状态\(httpResponse.statusCode)，数据大小\(data.count)")
                    return false
                }
            }
        } catch {
            print("❌ 测试专辑封面URL失败: \(error)")
        }
        
        return false
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
