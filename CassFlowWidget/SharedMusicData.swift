import Foundation
import SwiftUI
import MusicKit

/// 共享音乐数据结构，用于widget和主应用之间的数据传递
struct SharedMusicData: Codable, CustomStringConvertible {
    var title: String
    var artist: String
    var isPlaying: Bool
    var currentDuration: TimeInterval
    var totalDuration: TimeInterval
    var artworkURL: String? // 专辑封面URL
    
    static let `default` = SharedMusicData(
        title: "未播放歌曲",
        artist: "点此选择音乐",
        isPlaying: false,
        currentDuration: 0,
        totalDuration: 0,
        artworkURL: nil
    )
    
    var description: String {
        return "标题: '\(title)', 艺术家: '\(artist)', 播放中: \(isPlaying), 当前时长: \(currentDuration), 总时长: \(totalDuration)"
    }
}

/// App Group配置
struct AppGroupConfig {
    static let groupIdentifier = "group.me.pix3l.CassoFlow"
    static let musicDataKey = "SharedMusicData"
}

/// 音乐控制操作类型
enum MusicControlAction: String, Codable {
    case playPause
    case nextTrack
    case previousTrack
}

/// 用户默认值扩展，用于共享数据存储
extension UserDefaults {
    static var shared: UserDefaults? {
        UserDefaults(suiteName: AppGroupConfig.groupIdentifier)
    }
    
    /// 保存共享音乐数据
    static func saveMusicData(_ data: SharedMusicData) {
        guard let shared = UserDefaults.shared else { return }
        
        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(data)
            shared.set(encodedData, forKey: AppGroupConfig.musicDataKey)
        } catch {
            print("保存共享音乐数据失败: \(error)")
        }
    }
    
    /// 获取共享音乐数据
    static func getMusicData() -> SharedMusicData {
        guard let shared = UserDefaults.shared,
              let data = shared.data(forKey: AppGroupConfig.musicDataKey) else {
            return SharedMusicData.default
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(SharedMusicData.self, from: data)
        } catch {
            print("获取共享音乐数据失败: \(error)")
            return SharedMusicData.default
        }
    }
    
    /// 保存音乐控制操作
    static func saveMusicControlAction(_ action: MusicControlAction) {
        guard let shared = UserDefaults.shared else { return }
        shared.set(action.rawValue, forKey: "MusicControlAction")
    }
    
    /// 获取并清除音乐控制操作
    static func getAndClearMusicControlAction() -> MusicControlAction? {
        guard let shared = UserDefaults.shared else { return nil }
        
        if let actionString = shared.string(forKey: "MusicControlAction") {
            shared.removeObject(forKey: "MusicControlAction")
            return MusicControlAction(rawValue: actionString)
        }
        return nil
    }
}