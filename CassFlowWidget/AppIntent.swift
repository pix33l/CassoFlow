import AppIntents
import Foundation

/// Widget配置意图
struct CassFlowWidgetConfiguration: AppIntent, WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "CassFlow Widget配置"
    static var description = IntentDescription("配置CassFlow音乐播放器widget")
    
    // 可以添加配置参数，比如显示样式等
    @Parameter(title: "显示控制按钮", default: true)
    var showControls: Bool
    
    init() {}
    
    init(showControls: Bool) {
        self.showControls = showControls
    }
}

/// 音乐控制意图
struct PlayPauseMusicIntent: AppIntent {
    static var title: LocalizedStringResource = "播放/暂停音乐"
    static var description = IntentDescription("控制音乐播放或暂停")
    
    func perform() async throws -> some IntentResult {
        // 保存控制操作到共享存储
        UserDefaults.saveMusicControlAction(.playPause)
        
        // 发送通知给主应用（如果应用在前台）
        NotificationCenter.default.post(name: NSNotification.Name("WidgetMusicControl"), object: nil)
        
        // 立即唤醒主应用执行操作
        await wakeUpMainApp(action: "playPause")
        
        // 立即刷新Widget显示
        WidgetUpdateManager.shared.reloadAllWidgets()
        
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "下一首"
    static var description = IntentDescription("播放下一首歌曲")
    
    func perform() async throws -> some IntentResult {
        UserDefaults.saveMusicControlAction(.nextTrack)
        NotificationCenter.default.post(name: NSNotification.Name("WidgetMusicControl"), object: nil)
        
        // 立即唤醒主应用执行操作
        await wakeUpMainApp(action: "nextTrack")
        
        // 立即刷新Widget显示
        WidgetUpdateManager.shared.reloadAllWidgets()
        
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "上一首"
    static var description = IntentDescription("播放上一首歌曲")
    
    func perform() async throws -> some IntentResult {
        UserDefaults.saveMusicControlAction(.previousTrack)
        NotificationCenter.default.post(name: NSNotification.Name("WidgetMusicControl"), object: nil)
        
        // 立即唤醒主应用执行操作
        await wakeUpMainApp(action: "previousTrack")
        
        // 立即刷新Widget显示
        WidgetUpdateManager.shared.reloadAllWidgets()
        
        return .result()
    }
}

// MARK: - 唤醒主应用的工具方法
extension AppIntent {
    /// 唤醒主应用执行操作
    func wakeUpMainApp(action: String) async {
        let urlString = "cassoflow://widget-control?action=\(action)"
        
        // 保存操作到共享存储，主应用可以通过监听URL scheme或检查共享存储来执行操作
        UserDefaults.saveMusicControlAction(MusicControlAction(rawValue: action) ?? .playPause)
        
        print("已发送操作请求到主应用: \(action)")
        
        // 在widget中使用OpenURLIntent来打开URL
        if let url = URL(string: urlString) {
            // 使用OpenURLIntent来唤醒主应用
            do {
                let openURLIntent = OpenURLIntent()
                openURLIntent.url = url
                try await openURLIntent.perform()
            } catch {
                print("无法唤醒主应用，错误: \(error.localizedDescription)")
                // 即使无法唤醒，操作也已经保存到共享存储，主应用会在下次启动时处理
            }
        }
        
        // 对于Widget环境，主要依靠共享存储和通知机制与主应用通信
        // 主应用需要处理 cassoflow:// URL scheme 并读取共享存储中的操作
    }
}
